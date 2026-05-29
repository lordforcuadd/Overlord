param(
    [string]$ToggleName,
    [string]$IsEnabledStr
)

$ErrorActionPreference = "Continue"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "ERROR: Se requieren permisos de administrador."
    exit 1
}

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

$NormalizedInput = $IsEnabledStr.ToLower().Replace("$", "").Trim()
$Value = if ($NormalizedInput -eq "true") { 1 } else { 0 }
$ToggleName = $ToggleName.Trim().Replace("'", "").Replace('"', "")

function Set-RegistryValue($subPath, $name, $type, $val) {
    foreach ($base in $Targets) {
        $fullPath = Join-Path $base $subPath
        if (!(Test-Path $fullPath)) { New-Item -Path $fullPath -Force | Out-Null }
        Set-ItemProperty -Path $fullPath -Name $name -Type $type -Value $val -Force | Out-Null
    }
}

function Remove-RegistryKey($subPath) {
    foreach ($base in $Targets) {
        $fullPath = Join-Path $base $subPath
        if (Test-Path $fullPath) { Remove-Item -Path $fullPath -Recurse -Force | Out-Null }
    }
}

$RequiresExplorerRestart = $false
$buildVer = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

switch ($ToggleName) {
    "darkMode" {
        $themeVal = if ($Value -eq 1) { 0 } else { 1 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" "DWord" $themeVal
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" "DWord" $themeVal
        $RequiresExplorerRestart = $true
    }
    "showExtensions" {
        $extVal = if ($Value -eq 1) { 0 } else { 1 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" "DWord" $extVal
        $RequiresExplorerRestart = $true
    }
    "classicMenu" {
        if ($buildVer -lt 26000) {
            if ($Value -eq 1) {
                Set-RegistryValue "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}\InprocServer32" "" "String" ""
            } else {
                Remove-RegistryKey "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}"
            }
            $RequiresExplorerRestart = $true
        }
        else {
            if ($Value -eq 1) {
                $epConfig = "$env:APPDATA\ExplorerPatcher\ep_setup.ini"
                if (Test-Path $epConfig) {
                    $content = Get-Content $epConfig -Raw
                    $content = $content -replace 'ControlInterface=.*', 'ControlInterface=1'
                    Set-Content $epConfig -Value $content -Force
                    $RequiresExplorerRestart = $true
                }
            } else {
                $epConfig = "$env:APPDATA\ExplorerPatcher\ep_setup.ini"
                if (Test-Path $epConfig) {
                    $content = Get-Content $epConfig -Raw
                    $content = $content -replace 'ControlInterface=.*', 'ControlInterface=0'
                    Set-Content $epConfig -Value $content -Force
                    $RequiresExplorerRestart = $true
                }
            }
        }
    }
    "disableBing" {
        Set-RegistryValue "Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" "DWord" $Value
    }
    "disableLockScreen" {
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "NoLockScreen" -Type DWord -Value $Value -Force | Out-Null
    }
    "disableStickyKeys" {
        $stickyVal = if ($Value -eq 1) { "506" } else { "510" }
        Set-RegistryValue "Control Panel\Accessibility\StickyKeys" "Flags" "String" $stickyVal
    }
    "cleanAltTab" {
        $altTabVal = if ($Value -eq 1) { 3 } else { 0 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" "DWord" $altTabVal
    }
    "taskbarLeft" {
        $taskbarVal = if ($Value -eq 1) { 0 } else { 1 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" "DWord" $taskbarVal
    }
    "showHiddenFiles" {
        $hiddenVal = if ($Value -eq 1) { 1 } else { 2 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" "DWord" $hiddenVal
        $RequiresExplorerRestart = $true
    }
    "launchToThisPC" {
        $launchVal = if ($Value -eq 1) { 1 } else { 2 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" "DWord" $launchVal
    }
    "disableExplorerAds" {
        $adsVal = if ($Value -eq 1) { 0 } else { 1 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" "DWord" $adsVal
    }
    "disableScoobe" {
        $scoobeVal = if ($Value -eq 1) { 0 } else { 1 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" "DWord" $scoobeVal
    }
    "disableFilterKeys" {
        $filterVal = if ($Value -eq 1) { "122" } else { "126" }
        Set-RegistryValue "Control Panel\Accessibility\Keyboard Response" "Flags" "String" $filterVal
    }
    "disableCopilot" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" "DWord" $(if ($Value -eq 1) {0} else {1})
        Set-RegistryValue "Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" "DWord" $Value
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "TurnOffWindowsCopilot" -Type DWord -Value $Value -Force | Out-Null
        $RequiresExplorerRestart = $true
    }
    "disableRecall" {
        Set-RegistryValue "Software\Policies\Microsoft\Windows\WindowsAI" "TurnOffUserCameraCapture" "DWord" $Value
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "TurnOffUserCameraCapture" -Type DWord -Value $Value -Force | Out-Null
    }
    "detailedBSoD" {
        $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
        Set-ItemProperty -Path $Path -Name "DisplayParameters" -Type DWord -Value $Value -Force | Out-Null
    }
    "disableOneDrive" {
        if ($Value -eq 1) {
            Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
            $Paths = @(
                "$env:LOCALAPPDATA\Microsoft\OneDrive\Update\OneDriveSetup.exe",
                "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe",
                "C:\Windows\SysWOW64\OneDriveSetup.exe",
                "C:\Windows\System32\OneDriveSetup.exe"
            )
            foreach ($Setup in $Paths) {
                if (Test-Path $Setup) {
                    Start-Process -FilePath $Setup -ArgumentList "/uninstall" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                    break
                }
            }
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
            $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name "DisableFileSyncNGSC" -Type DWord -Value 1 -Force | Out-Null
        } else {
            Start-Process "ms-windows-store://pdp/?productid=9wzdncrfj1p3"
        }
    }
    "disableWidgets" {
        $widgetsVal = if ($Value -eq 1) { 0 } else { 1 }
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" "DWord" $widgetsVal
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Dsh"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "AllowNewsAndInterests" -Type DWord -Value $widgetsVal -Force | Out-Null
        $RequiresExplorerRestart = $true
    } 
    "zeroStartupDelay" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" "DWord" 0
    }
    "enableGameMode" {
        Set-RegistryValue "Software\Microsoft\GameBar" "AllowAutoGameMode" "DWord" $Value
    }
    "barebonesVisual" {
        $visualVal = if ($Value -eq 1) { "0" } else { "1" }
        Set-RegistryValue "Control Panel\Desktop\WindowMetrics" "MinAnimate" "String" $visualVal
    }
    default {
        Write-Error "ERROR: Toggle desconocido: $ToggleName"
        exit 1
    }
}

if ($RequiresExplorerRestart) {
    Stop-Process -Name explorer -Force
} else {
    if (-not ([System.Management.Automation.PSTypeName]'Win32.User32').Type) {
        Add-Type -MemberDefinition @'
[DllImport("user32.dll", EntryPoint = "SendMessageTimeoutA")]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.IntPtr lpdwResult);
'@ -Name "User32" -Namespace "Win32"
    }
    $result = [IntPtr]::Zero
    [Win32.User32]::SendMessageTimeout([IntPtr]0xffff, 0x001a, [IntPtr]::Zero, "Environment", 2, 5000, [ref] $result)
}

Write-Output "OK: $ToggleName establecido a $($Value -eq 1)"
exit 0
