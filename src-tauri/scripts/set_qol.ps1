param(
    [Parameter(Position=0, Mandatory=$false)][string]$ToggleName = "",
    [Parameter(Position=1, Mandatory=$false)][string]$IsEnabledStr = ""
)
$ErrorActionPreference = "SilentlyContinue"

$LogFile = "$env:TEMP\overlord_qol_debug.txt"
$SemaphoreFile = "$env:TEMP\overlord_explorer_restart.lock"

$ToggleName = $ToggleName.Replace("-ToggleName", "").Trim()
$IsEnabledStr = $IsEnabledStr.Replace("-IsEnabledStr", "").Replace('$', '').Trim().ToLower()
$IsEnabled = if ($IsEnabledStr -eq "true" -or $IsEnabledStr -eq "1") { $true } else { $false }

Add-Content -Path $LogFile -Value "======================================"
Add-Content -Path $LogFile -Value "[$(Get-Date)] GLOBAL EXECUTION -> $ToggleName | Enabled: $IsEnabled"

function Set-Reg {
    param([string]$Key, [string]$Value, [string]$Data, [string]$Type="REG_DWORD")
    reg.exe add "$Key" /v "$Value" /t $Type /d "$Data" /f | Out-Null
    Add-Content -Path $LogFile -Value "  [REG] $Key -> $Value = $Data ($Type)"
}

switch ($ToggleName) {
    "darkMode" {
        $val = if ($IsEnabled) { "0" } else { "1" }
        Set-Reg "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" $val
        Set-Reg "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" $val
    }
    "showExtensions" {
        $val = if ($IsEnabled) { "0" } else { "1" }
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" $val
    }
    "classicMenu" {
        $Key = "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if ($IsEnabled) {
            reg.exe add "$Key" /ve /f | Out-Null
        } else {
            reg.exe delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f | Out-Null
        }
    }
    "disableBing" {
        $val = if ($IsEnabled) { "1" } else { "0" }
        Set-Reg "HKCU\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" $val
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" (if ($IsEnabled) { "0" } else { "1" })
    }
    "disableLockScreen" {
        $val = if ($IsEnabled) { "1" } else { "0" }
        Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" $val
    }
    "disableStickyKeys" {
        $val = if ($IsEnabled) { "506" } else { "510" }
        Set-Reg "HKCU\Control Panel\Accessibility\StickyKeys" "Flags" $val "REG_SZ"
    }
    "showHiddenFiles" {
        $val = if ($IsEnabled) { "1" } else { "2" }
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" $val
    }
    "launchToThisPC" {
        $val = if ($IsEnabled) { "1" } else { "2" }
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" $val
    }
    "taskbarLeft" {
        # 🚀 WINUTIL METHOD: 0 = Izquierda, 1 = Centro
        $val = if ($IsEnabled) { "0" } else { "1" }
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" $val
    }
    "cleanAltTab" {
        $val = if ($IsEnabled) { "3" } else { "0" }
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" $val
    }
    "disableExplorerAds" {
        $val = if ($IsEnabled) { "0" } else { "1" }
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" $val
    }
    "disableScoobe" {
        $val = if ($IsEnabled) { "0" } else { "1" }
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" $val
    }
    "disableFilterKeys" {
        $val = if ($IsEnabled) { "122" } else { "126" }
        Set-Reg "HKCU\Control Panel\Accessibility\Keyboard Response" "Flags" $val "REG_SZ"
    }
    "disableCopilot" {
        $val = if ($IsEnabled) { "1" } else { "0" }
        Set-Reg "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" $val
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" (if ($IsEnabled) { "0" } else { "1" })
    }
    "disableRecall" {
        $val = if ($IsEnabled) { "1" } else { "0" }
        Set-Reg "HKCU\Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" $val
    }
    "detailedBSoD" {
        $val = if ($IsEnabled) { "1" } else { "0" }
        Set-Reg "HKLM\System\CurrentControlSet\Control\CrashControl" "DisplayParameters" $val
    }
    "disableOneDrive" {
        $val = if ($IsEnabled) { "1" } else { "0" }
        Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" $val
        
        if ($IsEnabled) {
            # Matamos procesos en vivo de forma redundante
            taskkill /F /IM OneDrive.exe | Out-Null
            # Eliminamos el auto-arranque del registro de usuario para que no resucite al reiniciar
            reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f | Out-Null
        } else {
            # Si se desactiva el tweak, restauramos el setup por defecto por si el usuario quiere reinstalarlo
            Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" "0"
        }
    }
    "disableWidgets" {
        $val = if ($IsEnabled) { "0" } else { "1" }
        Set-Reg "HKLM\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" $val
        Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" $val
    }
    "zeroStartupDelay" {
        $Key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        if ($IsEnabled) {
            Set-Reg $Key "StartupDelayInMSec" "0"
        } else {
            reg.exe delete "$Key" /v "StartupDelayInMSec" /f | Out-Null
        }
    }
    "enableGameMode" {
        $val = if ($IsEnabled) { "1" } else { "0" }
        Set-Reg "HKCU\Software\Microsoft\GameBar" "AutoGameModeEnabled" $val
        Set-Reg "HKCU\System\GameConfigStore" "GameDVR_Enabled" "0"
        Set-Reg "HKCU\System\GameConfigStore" "GameDVR_FSEBehaviorMode" "2"
    }
    "barebonesVisual" {
        if ($IsEnabled) {
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" "0"
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" "2"
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" "0"
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" "0"
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" "0"
            Set-Reg "HKCU\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "REG_SZ"
            Set-Reg "HKCU\Control Panel\Desktop" "UserPreferencesMask" "9012038010000000" "REG_BINARY"
            Set-Reg "HKCU\Software\Microsoft\Windows\DWM" "Composition" "0"
            Set-Reg "HKCU\Software\Microsoft\Windows\DWM" "EnableAeroPeek" "0"
        } else {
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" "1"
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" "1"
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" "1"
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" "1"
            Set-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" "1"
            Set-Reg "HKCU\Control Panel\Desktop\WindowMetrics" "MinAnimate" "1" "REG_SZ"
            Set-Reg "HKCU\Control Panel\Desktop" "UserPreferencesMask" "9E1E078012000000" "REG_BINARY"
            Set-Reg "HKCU\Software\Microsoft\Windows\DWM" "Composition" "1"
            Set-Reg "HKCU\Software\Microsoft\Windows\DWM" "EnableAeroPeek" "1"
        }
    }
}


$NeedsRestart = @("darkMode", "showExtensions", "classicMenu", "showHiddenFiles", "taskbarLeft", "barebonesVisual", "disableWidgets")
if ($ToggleName -in $NeedsRestart) {
    $CurrentTimeTicks = (Get-Date).Ticks
    Set-Content -Path $SemaphoreFile -Value $CurrentTimeTicks

    # Tiempo de acumulación de ráfaga sutil para agrupar llamadas concurrentes de Vue
    Start-Sleep -Milliseconds 550

    $LastTimeTicks = Get-Content -Path $SemaphoreFile
    if ($CurrentTimeTicks -eq $LastTimeTicks) {
        Add-Content -Path $LogFile -Value "  -> [DESPACHADOR TITUS]: Aplicando reseteo seguro de la interfaz de escritorio..."
        
        # 🚀 WINUTIL FIX PARA LA FLECHA OCULTA: Detenemos los sub-servicios del shell antes de matar el Explorer
        Stop-Process -Name "ShellExperienceHost" -Force
        Stop-Process -Name "StartMenuExperienceHost" -Force
        
        # Matamos explorer.exe de manera limpia mediante comandos nativos del Kernel
        taskkill /F /IM explorer.exe | Out-Null
        
        # RETARDO MAESTRO: Damos tiempo a Windows para limpiar los sockets de memoria del Systray
        Start-Sleep -Seconds 1.5
        
        # Volvemos a inicializar el entorno gráfico puro
        Start-Process "explorer.exe"
        Remove-Item -Path $SemaphoreFile -Force
        Add-Content -Path $LogFile -Value "  -> [ÉXITO TOTAL]: Shell reconstruido. Iconos de la bandeja resucitados."
    }
}

exit 0