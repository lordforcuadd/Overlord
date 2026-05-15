$ErrorActionPreference = "SilentlyContinue"
$Status = @{}

# 1. Modo Oscuro
$AppTheme = (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme").AppsUseLightTheme
$Status["darkMode"] = if ($AppTheme -eq 0) { $true } else { $false }

# 2. Extensiones
$HideExt = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt").HideFileExt
$Status["showExtensions"] = if ($HideExt -eq 0) { $true } else { $false }

# 3. Menú Contextual Clásico (Win 11)
$MenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
$Status["classicMenu"] = if (Test-Path $MenuPath) { $true } else { $false }

# 4. Bing Search
$BingDisabled = (Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions").DisableSearchBoxSuggestions
$Status["disableBing"] = if ($BingDisabled -eq 1) { $true } else { $false }

# 5. Lock Screen (Pantalla de bloqueo)
$LockDisabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen").NoLockScreen
$Status["disableLockScreen"] = if ($LockDisabled -eq 1) { $true } else { $false }

# 6. Sticky Keys (Teclas Especiales)
$Sticky = (Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags").Flags
$Status["disableStickyKeys"] = if ($Sticky -eq "506") { $true } else { $false }

# Mostrar Archivos Ocultos
$Hidden = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -ErrorAction SilentlyContinue).Hidden
$Status["showHiddenFiles"] = if ($Hidden -eq 1) { $true } else { $false }

# Iniciar en "Este Equipo"
$LaunchTo = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -ErrorAction SilentlyContinue).LaunchTo
$Status["launchToThisPC"] = if ($LaunchTo -eq 1) { $true } else { $false }

# Barra a la Izquierda (Win 11)
$Taskbar = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -ErrorAction SilentlyContinue).TaskbarAl
$Status["taskbarLeft"] = if ($Taskbar -eq 0) { $true } else { $false }

# Alt+Tab Limpio
$AltTab = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -ErrorAction SilentlyContinue).MultiTaskingAltTabFilter
$Status["cleanAltTab"] = if ($AltTab -eq 3) { $true } else { $false }

# Sin Anuncios en el Explorador
$SyncProv = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -ErrorAction SilentlyContinue).ShowSyncProviderNotifications
$Status["disableExplorerAds"] = if ($SyncProv -eq 0) { $true } else { $false }

# Bloquear pantalla "Terminemos de configurar"
$Scoobe = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -ErrorAction SilentlyContinue).ScoobeSystemSettingEnabled
$Status["disableScoobe"] = if ($Scoobe -eq 0) { $true } else { $false }

# Desactivar Teclas Filtro (122 = Apagado, 126 = Encendido)
$Filter = (Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -ErrorAction SilentlyContinue).Flags
$Status["disableFilterKeys"] = if ($Filter -eq "122") { $true } else { $false }

# 1. Copilot
$Copilot = (Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot
$Status["disableCopilot"] = if ($Copilot -eq 1) { $true } else { $false }

# 2. Windows Recall (IA)
$Recall = (Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -ErrorAction SilentlyContinue).DisableAIDataAnalysis
$Status["disableRecall"] = if ($Recall -eq 1) { $true } else { $false }

# 3. Detailed BSoD (Pantallazo Azul Detallado)
$BSoD = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -ErrorAction SilentlyContinue).DisplayParameters
$Status["detailedBSoD"] = if ($BSoD -eq 1) { $true } else { $false }

# 4. Bloquear OneDrive
$OneDrive = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -ErrorAction SilentlyContinue).DisableFileSyncNGSC
$Status["disableOneDrive"] = if ($OneDrive -eq 1) { $true } else { $false }
# Modo Juego (Game Mode)
$GameMode = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -ErrorAction SilentlyContinue).AutoGameModeEnabled
$Status["enableGameMode"] = if ($GameMode -ne 0) { $true } else { $false }

# 1. Widgets (Noticias e Intereses)
# En Windows, 0 significa bloqueado por política.
$Widgets = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -ErrorAction SilentlyContinue).AllowNewsAndInterests
$Status["disableWidgets"] = if ($null -ne $Widgets -and $Widgets -eq 0) { $true } else { $false }

# 2. Cero Retraso de Arranque (Startup Delay)
# Si la llave existe y es 0, el delay está desactivado.
$StartupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
$Startup = (Get-ItemProperty -Path $StartupPath -Name "StartupDelayInMSec" -ErrorAction SilentlyContinue).StartupDelayInMSec
$Status["zeroStartupDelay"] = if ($null -ne $Startup -and $Startup -eq 0) { $true } else { $false }

$Status | ConvertTo-Json -Compress