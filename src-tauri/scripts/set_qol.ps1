param(
    [string]$ToggleName,
    [string]$IsEnabledStr
)
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

$NormalizedInput = $IsEnabledStr.ToLower().Replace("$", "").Trim()
$Value = if ($NormalizedInput -eq "true") { 1 } else { 0 }

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

switch ($ToggleName) {
    "darkMode" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" "DWord" (if ($Value -eq 1) { 0 } else { 1 })
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" "DWord" (if ($Value -eq 1) { 0 } else { 1 })
    }
    "showExtensions" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" "DWord" (if ($Value -eq 1) { 0 } else { 1 })
        $RequiresExplorerRestart = $true
    }
    "classicMenu" {
        if ($Value -eq 1) {
            Set-RegistryValue "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}\InprocServer32" "" "String" ""
        } else {
            Remove-RegistryKey "Software\Classes\CLSID\{e56a902a-a584-450e-9022-d7902bc4e017}"
        }
        $RequiresExplorerRestart = $true
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
        Set-RegistryValue "Control Panel\Accessibility\StickyKeys" "Flags" "String" (if ($Value -eq 1) { "506" } else { "510" })
    }
    "cleanAltTab" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" "DWord" (if ($Value -eq 1) { 3 } else { 0 })
    }
    "taskbarLeft" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" "DWord" (if ($Value -eq 1) { 0 } else { 1 })
    }
    "showHiddenFiles" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" "DWord" (if ($Value -eq 1) { 1 } else { 2 })
        $RequiresExplorerRestart = $true
    }
    "launchToThisPC" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" "DWord" (if ($Value -eq 1) { 1 } else { 2 })
    }
    "disableExplorerAds" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" "DWord" (if ($Value -eq 1) { 0 } else { 1 })
    }
    "disableScoobe" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" "DWord" (if ($Value -eq 1) { 0 } else { 1 })
    }
    "disableFilterKeys" {
        Set-RegistryValue "Control Panel\Accessibility\Keyboard Response" "Flags" "String" (if ($Value -eq 1) { "122" } else { "126" })
    }
    "disableCopilot" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" "DWord" (if ($Value -eq 1) { 0 } else { 1 })
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
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "DisableFileSyncNGSC" -Type DWord -Value $Value -Force | Out-Null
    }
    "disableWidgets" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" "DWord" (if ($Value -eq 1) { 0 } else { 1 })
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Dsh"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "AllowNewsAndInterests" -Type DWord -Value (if ($Value -eq 1) { 0 } else { 1 }) -Force | Out-Null
        $RequiresExplorerRestart = $true
    }
    "zeroStartupDelay" {
        Set-RegistryValue "Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" "DWord" 0
    }
    "enableGameMode" {
        Set-RegistryValue "Software\Microsoft\GameBar" "AllowAutoGameMode" "DWord" $Value
    }
    "barebonesVisual" {
        Set-RegistryValue "Control Panel\Desktop\WindowMetrics" "MinAnimate" "String" (if ($Value -eq 1) { "0" } else { "1" })
    }
}

if ($RequiresExplorerRestart) {
    Stop-Process -Name explorer -Force
} else {
    $User32 = Add-Type -MemberDefinition '[DllImport("user32.dll", EntryPoint="SendMessageTimeoutA")] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);' -Name "User32" -Namespace "Win32" -PassThru
    $result = [IntPtr]::Zero
    [Win32.User32]::SendMessageTimeout([IntPtr]0xffff, 0x001a, [IntPtr]::Zero, "Environment", 2, 5000, out $result)
}

exit 0