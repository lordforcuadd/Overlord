$ErrorActionPreference = "SilentlyContinue"
$Status = @{}

# 🚀 MOTOR LECTOR SEGURO: Jamás devolverá nulos o errores al frontend
function Get-RegVal {
    param([string]$Path, [string]$Name, [string]$Default="0")
    $val = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($null -eq $val) { return $Default }
    return [string]$val
}

$AppTheme = Get-RegVal "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" "1"
$SysTheme = Get-RegVal "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" "1"
$Status["darkMode"] = if ($AppTheme -eq "0" -and $SysTheme -eq "0") { $true } else { $false }

$HideExt = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" "1"
$Status["showExtensions"] = if ($HideExt -eq "0") { $true } else { $false }

$MenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
$Status["classicMenu"] = if (Test-Path $MenuPath) { $true } else { $false }

$BingDisabled = Get-RegVal "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" "0"
$Status["disableBing"] = if ($BingDisabled -eq "1") { $true } else { $false }

$LockDisabled = Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" "0"
$Status["disableLockScreen"] = if ($LockDisabled -eq "1") { $true } else { $false }

$Sticky = Get-RegVal "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "510"
$Status["disableStickyKeys"] = if ($Sticky -eq "506") { $true } else { $false }

$Hidden = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" "2"
$Status["showHiddenFiles"] = if ($Hidden -eq "1") { $true } else { $false }

$LaunchTo = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" "2"
$Status["launchToThisPC"] = if ($LaunchTo -eq "1") { $true } else { $false }

$Taskbar = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" "1"
$Status["taskbarLeft"] = if ($Taskbar -eq "0") { $true } else { $false }

$AltTab = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" "0"
$Status["cleanAltTab"] = if ($AltTab -eq "3") { $true } else { $false }

$SyncProv = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" "1"
$Status["disableExplorerAds"] = if ($SyncProv -eq "0") { $true } else { $false }

$Scoobe = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" "1"
$Status["disableScoobe"] = if ($Scoobe -eq "0") { $true } else { $false }

$Filter = Get-RegVal "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "126"
$Status["disableFilterKeys"] = if ($Filter -eq "122") { $true } else { $false }

$Copilot = Get-RegVal "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" "0"
$Status["disableCopilot"] = if ($Copilot -eq "1") { $true } else { $false }

$Recall = Get-RegVal "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" "0"
$Status["disableRecall"] = if ($Recall -eq "1") { $true } else { $false }

$BSoD = Get-RegVal "HKLM:\System\CurrentControlSet\Control\CrashControl" "DisplayParameters" "0"
$Status["detailedBSoD"] = if ($BSoD -eq "1") { $true } else { $false }

$OneDrive = Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" "0"
$Status["disableOneDrive"] = if ($OneDrive -eq "1") { $true } else { $false }

$GameMode = Get-RegVal "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" "1"
$Status["enableGameMode"] = if ($GameMode -eq "1" -or $GameMode -eq "True") { $true } else { $false }

$Widgets = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" "1"
$Status["disableWidgets"] = if ($Widgets -eq "0") { $true } else { $false }

$Startup = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" "1"
$Status["zeroStartupDelay"] = if ($Startup -eq "0") { $true } else { $false }

$Fx = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" "1"
$Trans = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" "1"
$TaskAnim = Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" "1"
$Status["barebonesVisual"] = if ($Fx -eq "2" -and $Trans -eq "0" -and $TaskAnim -eq "0") { $true } else { $false }

$Status | ConvertTo-Json -Compress