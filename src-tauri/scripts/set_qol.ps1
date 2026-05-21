param([string]$ToggleName, [string]$IsEnabledStr)
$ErrorActionPreference = "Stop"
$IsEnabled = if ($IsEnabledStr -eq "true") { $true } else { $false }

switch ($ToggleName) {
    "darkMode" {
        $val = if ($IsEnabled) { 0 } else { 1 }
        $ThemePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        Set-ItemProperty -Path $ThemePath -Name "AppsUseLightTheme" -Value $val -Type DWord -Force
        
        Set-ItemProperty -Path $ThemePath -Name "SystemUsesLightTheme" -Value $val -Type DWord -Force
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
    "showExtensions" {
        $val = if ($IsEnabled) { 0 } else { 1 }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value $val -Type DWord -Force
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
    "classicMenu" {
        $MenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if ($IsEnabled) {
            New-Item -Path $MenuPath -Force | Out-Null
            Set-ItemProperty -Path $MenuPath -Name "(Default)" -Value "" -Force
        } else {
            Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force
        }
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
    "disableBing" {
        $val = if ($IsEnabled) { 1 } else { 0 }
        $Path = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "DisableSearchBoxSuggestions" -Value $val -Type DWord -Force
    }
    "disableLockScreen" {
        $val = if ($IsEnabled) { 1 } else { 0 }
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "NoLockScreen" -Value $val -Type DWord -Force
    }
    "disableStickyKeys" {
        $val = if ($IsEnabled) { "506" } else { "510" }
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value $val -Type String -Force
    }
    "showHiddenFiles" {
        $val = if ($IsEnabled) { 1 } else { 2 }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value $val -Type DWord -Force
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
    "launchToThisPC" {
        $val = if ($IsEnabled) { 1 } else { 2 }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value $val -Type DWord -Force
    }
    "taskbarLeft" {
        $val = if ($IsEnabled) { 0 } else { 1 }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value $val -Type DWord -Force
        # AÑADIDO: Forzar reinicio del explorador para que la barra se mueva instantáneamente
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
    "cleanAltTab" {
        $val = if ($IsEnabled) { 3 } else { 0 }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -Value $val -Type DWord -Force
    }
    "disableExplorerAds" {
        $val = if ($IsEnabled) { 0 } else { 1 }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Value $val -Type DWord -Force
    }
    "disableScoobe" {
        $val = if ($IsEnabled) { 0 } else { 1 }
        $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "ScoobeSystemSettingEnabled" -Value $val -Type DWord -Force
    }
    "disableFilterKeys" {
        $val = if ($IsEnabled) { "122" } else { "126" }
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value $val -Type String -Force
    }
    "disableCopilot" {
        $val = if ($IsEnabled) { 1 } else { 0 }
        $Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "TurnOffWindowsCopilot" -Value $val -Type DWord -Force
    }
    "disableRecall" {
        $val = if ($IsEnabled) { 1 } else { 0 }
        $Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "DisableAIDataAnalysis" -Value $val -Type DWord -Force
    }
    "detailedBSoD" {
        $val = if ($IsEnabled) { 1 } else { 0 }
        $Path = "HKLM:\System\CurrentControlSet\Control\CrashControl"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "DisplayParameters" -Value $val -Type DWord -Force
    }
    "disableOneDrive" {
        $val = if ($IsEnabled) { 1 } else { 0 }
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "DisableFileSyncNGSC" -Value $val -Type DWord -Force
        
        
        if ($IsEnabled) {
            Stop-Process -Name "OneDrive" -ErrorAction SilentlyContinue -Force
        }
    }
    "disableWidgets" {
        $val = if ($IsEnabled) { 0 } else { 1 }
        $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "AllowNewsAndInterests" -Value $val -Type DWord -Force
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
    "zeroStartupDelay" {
        $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        if ($IsEnabled) {
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force
        } else {
            Remove-ItemProperty -Path $Path -Name "StartupDelayInMSec" -ErrorAction SilentlyContinue
        }
    }
    "enableGameMode" {
        $val = if ($IsEnabled) { 1 } else { 0 }
        $Path = "HKCU:\Software\Microsoft\GameBar"
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "AutoGameModeEnabled" -Value $val -Type DWord -Force
        
        $FsoPath = "HKCU:\System\GameConfigStore"
        if (!(Test-Path $FsoPath)) { New-Item -Path $FsoPath -Force | Out-Null }
        Set-ItemProperty -Path $FsoPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
    }
    "barebonesVisual" {
        
        $VisualFxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        $ColorPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $AdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $DesktopPath = "HKCU:\Control Panel\Desktop"
        $WindowMetricsPath = "HKCU:\Control Panel\Desktop\WindowMetrics"

        if ($IsEnabled) {
            Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 0 -Force
            Set-ItemProperty -Path $VisualFxPath -Name "VisualFXSetting" -Type DWord -Value 2 -Force
            
            
            Set-ItemProperty -Path $AdvancedPath -Name "TaskbarAnimations" -Type DWord -Value 0 -Force
            Set-ItemProperty -Path $AdvancedPath -Name "ListviewAlphaSelect" -Type DWord -Value 0 -Force
            Set-ItemProperty -Path $AdvancedPath -Name "ListviewShadow" -Type DWord -Value 0 -Force
            if (Test-Path $WindowMetricsPath) { Set-ItemProperty -Path $WindowMetricsPath -Name "MinAnimate" -Type String -Value "0" -Force }
            
            
            Set-ItemProperty -Path $DesktopPath -Name "UserPreferencesMask" -Type Byte[] -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Force
        } else {
            Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 1 -Force
            Set-ItemProperty -Path $VisualFxPath -Name "VisualFXSetting" -Type DWord -Value 1 -Force
            
            # Restaurar animaciones por defecto
            Set-ItemProperty -Path $AdvancedPath -Name "TaskbarAnimations" -Type DWord -Value 1 -Force
            Set-ItemProperty -Path $AdvancedPath -Name "ListviewAlphaSelect" -Type DWord -Value 1 -Force
            Set-ItemProperty -Path $AdvancedPath -Name "ListviewShadow" -Type DWord -Value 1 -Force
            if (Test-Path $WindowMetricsPath) { Set-ItemProperty -Path $WindowMetricsPath -Name "MinAnimate" -Type String -Value "1" -Force }
            
            
            Set-ItemProperty -Path $DesktopPath -Name "UserPreferencesMask" -Type Byte[] -Value ([byte[]](0x9E,0x1E,0x07,0x80,0x12,0x00,0x00,0x00)) -Force
        }
        
        $PInvokeCode = @"
        using System.Runtime.InteropServices;
        public class WinAPI { 
            [DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni); 
        }
"@
        Add-Type -TypeDefinition $PInvokeCode -Language CSharp -ErrorAction SilentlyContinue
        [WinAPI]::SystemParametersInfo(0x104D, 0, 0, 2) | Out-Null
        
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
}
exit 0