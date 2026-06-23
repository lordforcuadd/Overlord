$ErrorActionPreference = "Continue"


$FullUsername = $null
try {
    $FullUsername = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
} catch {}

if ([string]::IsNullOrWhiteSpace($FullUsername)) {
    try {
        $FullUsername = (Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UserName -First 1)
    } catch {}
}

if ([string]::IsNullOrWhiteSpace($FullUsername)) {
    $FullUsername = "$env:USERDOMAIN\$env:USERNAME"
}

$LeafUsername = $FullUsername
if ($FullUsername -match '\\(.+)$') { $LeafUsername = $Matches[1] }

$UserSID = ""
if (-not [string]::IsNullOrWhiteSpace($FullUsername)) {
    try {
        $NtAccount = New-Object System.Security.Principal.NTAccount($FullUsername)
        $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        try {
            $NtAccount = New-Object System.Security.Principal.NTAccount($LeafUsername)
            $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
        } catch {
            try {
                $UserSID = (Get-CimInstance -ClassName Win32_UserAccount -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $LeafUsername }).SID
            } catch {}
        }
    }
}

if ([string]::IsNullOrWhiteSpace($UserSID)) {
    try {
        $Explorer = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Explorer) {
            $Owner = Invoke-CimMethod -InputObject $Explorer -MethodName GetOwner -ErrorAction SilentlyContinue
            $NtAccount = if (-not [string]::IsNullOrWhiteSpace($Owner.Domain)) {
                New-Object System.Security.Principal.NTAccount($Owner.Domain, $Owner.User)
            } else {
                New-Object System.Security.Principal.NTAccount($Owner.User)
            }
            $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
        }
    } catch {}
}

if ([string]::IsNullOrWhiteSpace($UserSID)) {
    try {
        $HKeyUsers = [Microsoft.Win32.Registry]::Users
        foreach ($SubkeyName in $HKeyUsers.GetSubKeyNames()) {
            if ($SubkeyName -match '^S-1-5-21-\d+-\d+-\d+-\d+$') {
                $VolatileKey = "Registry::HKEY_USERS\$SubkeyName\Volatile Environment"
                if (Test-Path $VolatileKey) {
                    $UserSID = $SubkeyName
                    break
                }
            }
        }
    } catch {}
}

$Targets = @()
if (-not [string]::IsNullOrWhiteSpace($UserSID)) { $Targets += "Registry::HKEY_USERS\$UserSID" }
$Targets += "HKCU:"

function Get-RegistryValue($basePath, $subPath, $name, $expectedValue) {
    $paths = @()
    if ($null -eq $basePath) {
        foreach ($base in $Targets) { $paths += Join-Path $base $subPath }
    } else {
        $paths += Join-Path $basePath $subPath
    }
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $item = Get-Item -Path $path -ErrorAction SilentlyContinue
            if ($null -ne $item) {
                if ($name -eq "" -and $expectedValue -eq "") { return $true }
                $val = $item.GetValue($name)
                if ($null -ne $val -and $val.ToString().Trim() -eq $expectedValue.ToString().Trim()) {
                    return $true
                }
            }
        }
    }
    return $false
}

function Test-ClassicMenuEnabled {
    $buildVer = [int](Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuildNumber" -ErrorAction SilentlyContinue)
    if ($buildVer -lt 26000) {
        foreach ($base in $Targets) {
            $path = Join-Path $base "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}\InprocServer32"
            if (Test-Path $path) { return $true }
        }
    }
    if (Test-Path "$env:APPDATA\ExplorerPatcher\ep_setup.ini") {
        $ini = Get-Content "$env:APPDATA\ExplorerPatcher\ep_setup.ini" -Raw -ErrorAction SilentlyContinue
        if ($ini -match 'ControlInterface=1') { return $true }
    }
    if (Get-Process "ExplorerPatcher" -ErrorAction SilentlyContinue) { return $true }
    if (Test-Path "$env:APPDATA\StartAllBack\Config.cfg") { return $true }
    if (Get-Process "StartAllBack" -ErrorAction SilentlyContinue) { return $true }
    return $false
}

$buildVer = [int](Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuildNumber" -ErrorAction SilentlyContinue)

$Qol = @{
    darkMode           = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
    showExtensions     = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
    classicMenu        = Test-ClassicMenuEnabled
    disableBing        = ((Get-RegistryValue $null "Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1) -and (Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0))
    disableLockScreen  = Get-RegistryValue "HKLM:" "SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" 1
    disableStickyKeys  = Get-RegistryValue $null "Control Panel\Accessibility\StickyKeys" "Flags" "506"
    cleanAltTab        = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" 3
    taskbarLeft        = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0
    showHiddenFiles    = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
    launchToThisPC     = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1
    disableExplorerAds = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0
    disableScoobe      = ((Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0) -and (Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-310093Enabled" 0))
    disableFilterKeys  = ((Get-RegistryValue $null "Control Panel\Accessibility\Keyboard Response" "Flags" "122") -or (Get-RegistryValue $null "Control Panel\Accessibility\Keyboard Response" "Flags" "59"))
    disableWidgets     = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0
    zeroStartupDelay   = Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0
    enableGameMode     = ((Get-RegistryValue $null "Software\Microsoft\GameBar" "AllowAutoGameMode" 1) -and (Get-RegistryValue $null "Software\Microsoft\GameBar" "AutoGameModeEnabled" 1))
    barebonesVisual    = ((Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2) -and (Get-RegistryValue $null "Control Panel\Desktop\WindowMetrics" "MinAnimate" "0"))
    disableCopilot     = ((Get-RegistryValue $null "Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1) -or (Get-RegistryValue $null "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0) -or (Get-RegistryValue "HKLM:" "SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1))
    disableRecall      = ((Get-RegistryValue $null "Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1) -and (Get-RegistryValue "HKLM:" "SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1))
    detailedBSoD       = Get-RegistryValue "HKLM:" "SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 1
    disableOneDrive    = Get-RegistryValue "HKLM:" "SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
    windowsBuild       = $buildVer
}

ConvertTo-Json $Qol -Compress