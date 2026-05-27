$ErrorActionPreference = "SilentlyContinue"

$Username = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
if ($Username -match '\\(.+)$') { $Username = $Matches[1] }
if ([string]::IsNullOrWhiteSpace($Username)) { $Username = $env:USERNAME }

$UserSID = (Get-CimInstance -ClassName Win32_UserAccount | Where-Object { $_.Name -eq $Username }).SID
if ([string]::IsNullOrWhiteSpace($UserSID)) {
    $Explorer = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1
    if ($Explorer) {
        $Owner = Invoke-CimMethod -InputObject $Explorer -MethodName GetOwner
        $UserSID = (Get-CimInstance -ClassName Win32_UserAccount | Where-Object { $_.Name -eq $Owner.User }).SID
    }
}

$Targets = @()
if (-not [string]::IsNullOrWhiteSpace($UserSID)) { $Targets += "Registry::HKEY_USERS\$UserSID" }
$Targets += "HKCU:"

function Get-RegistryValue($subPath, $name, $expectedValue) {
    foreach ($base in $Targets) {
        $fullPath = Join-Path $base $subPath
        if (Test-Path $fullPath) {
            $val = (Get-ItemProperty -Path $fullPath -Name $name -ErrorAction SilentlyContinue).$name
            if ($null -ne $val) {
                if ($val.ToString().Trim() -eq $expectedValue.ToString().Trim()) {
                    return $true
                }
            }
        }
    }
    return $false
}

$Qol = @{
    darkMode           = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
    showExtensions     = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
    classicMenu        = Get-RegistryValue "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}\InprocServer32" "" ""
    disableBing        = Get-RegistryValue "Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1
    disableLockScreen  = ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -ErrorAction SilentlyContinue).NoLockScreen -eq 1)
    disableStickyKeys  = Get-RegistryValue "Control Panel\Accessibility\StickyKeys" "Flags" "506"
    cleanAltTab        = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" 3
    taskbarLeft        = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0
    showHiddenFiles    = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
    launchToThisPC     = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1
    disableExplorerAds = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0
    disableScoobe      = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0
    disableFilterKeys  = Get-RegistryValue "Control Panel\Accessibility\Keyboard Response" "Flags" "122"
    disableCopilot     = ((Get-RegistryValue "Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1) -or (Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0) -or ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot -eq 1))
    disableRecall      = ((Get-RegistryValue "Software\Policies\Microsoft\Windows\WindowsAI" "TurnOffUserCameraCapture" 1) -or ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffUserCameraCapture" -ErrorAction SilentlyContinue).TurnOffUserCameraCapture -eq 1))
    detailedBSoD       = ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -ErrorAction SilentlyContinue).DisplayParameters -eq 1)
    disableOneDrive    = ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -ErrorAction SilentlyContinue).DisableFileSyncNGSC -eq 1)
    disableWidgets     = (Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0)
    zeroStartupDelay   = Get-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0
    enableGameMode     = Get-RegistryValue "Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    barebonesVisual    = Get-RegistryValue "Control Panel\Desktop\WindowMetrics" "MinAnimate" "0"
}

ConvertTo-Json $Qol -Compress