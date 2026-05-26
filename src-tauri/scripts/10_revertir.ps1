param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Write-Host "[*] Iniciando purga total de optimizaciones de Overlord y volviendo a Stock..."

$BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"

# 🚀 CIM UPDATE: Consulta nativa segura del plan energético sin overhead
try {
    $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
    $PowerGuid = if ($ActivePlan) { $ActivePlan.InstanceID.Split('\')[1] } else { "381b4222-f694-41f0-9685-ff5bb260df2e" }
} catch {
    $PowerGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
}

# =========================================================================
# 1. REVERTIR PERIFÉRICOS, ACCESIBILIDAD Y PRIORIDAD MULTIMEDIA
# =========================================================================
Write-Host "[*] Restableciendo colas de periféricos y respuesta USB desde copia de seguridad..."

$RestMouQueue = (Get-ItemProperty -Path "$BackupPath\mouclass" -Name "MouseDataQueueSize" -ErrorAction SilentlyContinue).MouseDataQueueSize
$RestKbdQueue = (Get-ItemProperty -Path "$BackupPath\kbdclass" -Name "KeyboardDataQueueSize" -ErrorAction SilentlyContinue).KeyboardDataQueueSize
$RestPrioritySep = (Get-ItemProperty -Path $BackupPath -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue).Win32PrioritySeparation

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value (if ($RestMouQueue) { $RestMouQueue } else { 100 })
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value (if ($RestKbdQueue) { $RestKbdQueue } else { 100 })
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value (if ($RestPrioritySep -ne $null) { $RestPrioritySep } else { 2 })

Write-Host "[*] Re-inyectando configuraciones MSI de fábrica para estabilidad de controladores..."
$MsiBackupKey = "$BackupPath\MSI"
$Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters" -ErrorAction SilentlyContinue
foreach ($Device in $Devices) {
    $DeviceID = ($Device.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
    $MsiPath = "$($Device.PSPath)\Interrupt Management\MessageSignaledInterruptProperties"
    
    $BackupVal = (Get-ItemProperty -Path $MsiBackupKey -Name $DeviceID -ErrorAction SilentlyContinue).$DeviceID
    if ($BackupVal -ne $null) {
        if ($BackupVal -eq 999) {
            if (Test-Path $MsiPath) { Remove-ItemProperty -Path $MsiPath -Name "MSISupported" -ErrorAction SilentlyContinue }
        } else {
            if (!(Test-Path $MsiPath)) { New-Item -Path $MsiPath -Force | Out-Null }
            Set-ItemProperty -Path $MsiPath -Name "MSISupported" -Type DWord -Value $BackupVal -Force
        }
    }
}

# Restaurar curvas y parámetros del ratón nativos
$MousePath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "1"
Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "6"
Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "10"
$CurvesX = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xC0,0xCC,0x0C,0x00,0x00,0x00,0x00,0x00,0x80,0x99,0x19,0x00,0x00,0x00,0x00,0x00,0x40,0x66,0x26,0x00,0x00,0x00,0x00,0x00,0x00,0x33,0x33,0x00,0x00,0x00,0x00,0x00)
$CurvesY = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x70,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xA8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xE0,0x00,0x00,0x00,0x00,0x00)
Set-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -Type Binary -Value $CurvesX
Set-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -Type Binary -Value $CurvesY

Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510"
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "62"
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126"

# 🚀 FIX QUIRÚRGICO: Remueve solo las sub-propiedades inyectadas a CSRSS evitando corromper la clave raíz
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions") {
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" -Recurse -Force
}
bcdedit /deletevalue useplatformtick | Out-Null
bcdedit /deletevalue disabledynamictick | Out-Null
bcdedit /deletevalue useplatformclock | Out-Null

if (-not $IsLaptop) {
    powercfg /SETACVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
    powercfg /SETDCVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
}

# =========================================================================
# 2. REVERTIR LIMPIEZA (DEBLOAT) Y PLANIFICADOR DE TAREAS
# =========================================================================
Write-Host "[*] Re-activando telemetría básica y tareas del sistema..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Type DWord -Value 1

$Tasks = @(
    "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "Microsoft\Windows\Autochk\Proxy"
)
foreach ($Task in $Tasks) { Enable-ScheduledTask -TaskName $Task }

# =========================================================================
# 3. REVERTIR RED COMPLETA DESDE BACKUP GRANULAR INTERFAZ POR INTERFAZ
# =========================================================================
Write-Host "[*] Normalizando la pila de red TCP/IP desde almacenamiento de persistencia..."
$NetworkBackupPath = "$BackupPath\Network"
$Interfaces = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
foreach ($Interface in $Interfaces) {
    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
    $InterfaceBackupKey = "$NetworkBackupPath\$($Interface.SettingID)"
    
    if (Test-Path $InterfaceBackupKey) {
        $BckAck = (Get-ItemProperty -Path $InterfaceBackupKey -Name "TcpAckFrequency" -ErrorAction SilentlyContinue).TcpAckFrequency
        $BckDelay = (Get-ItemProperty -Path $InterfaceBackupKey -Name "TCPNoDelay" -ErrorAction SilentlyContinue).TCPNoDelay
        
        if ($BckAck -eq 999) { Remove-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" } elseif ($BckAck -ne $null) { Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -Type DWord -Value $BckAck }
        if ($BckDelay -eq 999) { Remove-ItemProperty -Path $TcpPath -Name "TCPNoDelay" } elseif ($BckDelay -ne $null) { Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -Type DWord -Value $BckDelay }
    }
}

$OrigQos = (Get-ItemProperty -Path $NetworkBackupPath -Name "NonBestEffortLimit" -ErrorAction SilentlyContinue).NonBestEffortLimit
if ($OrigQos -ne $null) {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Type DWord -Value $OrigQos
} else {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit"
}

Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheTtl"
Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxNegativeCacheTtl"

Enable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
Enable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
Enable-NetAdapterLso -Name "*" -IPv4 -ErrorAction SilentlyContinue
Enable-NetAdapterLso -Name "*" -IPv6 -ErrorAction SilentlyContinue
Enable-NetAdapterChecksumOffload -Name "*" -IpIPv4 -ErrorAction SilentlyContinue

netsh int tcp set global autotuninglevel=normal | Out-Null
netsh int tcp set global ecncapability=disabled | Out-Null

# =========================================================================
# 4. REVERTIR RENDIMIENTO, CPU Y MITIGACIONES DE FABRICA
# =========================================================================
Write-Host "[*] Restableciendo mitigaciones de procesador y archivos de paginación..."
$PerfBackupPath = "$BackupPath\Performance"
$MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

$RestPaging = (Get-ItemProperty -Path $PerfBackupPath -Name "DisablePagingExecutive" -ErrorAction SilentlyContinue).DisablePagingExecutive
$RestCache = (Get-ItemProperty -Path $PerfBackupPath -Name "LargeSystemCache" -ErrorAction SilentlyContinue).LargeSystemCache
$RestSpec = (Get-ItemProperty -Path $PerfBackupPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue).FeatureSettingsOverride
$RestSpecMask = (Get-ItemProperty -Path $PerfBackupPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue).FeatureSettingsOverrideMask

Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value (if ($RestPaging -ne $null) { $RestPaging } else { 0 })
Set-ItemProperty -Path $MemPath -Name "LargeSystemCache" -Type DWord -Value (if ($RestCache -ne $null) { $RestCache } else { 0 })

if ($RestSpec -ne $null) { Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value $RestSpec } else { Remove-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" }
if ($RestSpecMask -ne $null) { Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value $RestSpecMask } else { Remove-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" }

Enable-MMAgent -MemoryCompression
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 1
Set-ItemProperty -Path "HKLM:\Software\Microsoft\FTH" -Name "Enabled" -Type DWord -Value 1

# =========================================================================
# 5. REVERTIR CONFIGURACIÓN DE GPU, ENTORNO VISUAL Y PROTECCIÓN HDCP
# =========================================================================
Write-Host "[*] Re-encendiendo MPO y restaurando aceleración de hardware por GPU (HAGS)..."
$RestHags = (Get-ItemProperty -Path "$BackupPath\GPU" -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
if ($RestHags -ne $null) { Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Type DWord -Value $RestHags }

Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode"
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode"
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior"
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions") {
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" -Recurse -Force
}
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1

# [SANEADO]: Eliminada la duplicación de código en la lectura limpia de HDCP Adapters
$HdcpBackupKey = "$BackupPath\GPU\HDCP"
$DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$Adapters = Get-ChildItem -Path $DisplayClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
foreach ($Adapter in $Adapters) {
    $AdapterID = $Adapter.PSChildName
    $BackupHdcp = (Get-ItemProperty -Path $HdcpBackupKey -Name $AdapterID -ErrorAction SilentlyContinue).$AdapterID
    if ($BackupHdcp -ne $null) {
        if ($BackupHdcp -eq 999) { Remove-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" } else { Set-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" -Type DWord -Value $BackupHdcp -Force }
    }
}

# =========================================================================
# 6. REVERTIR ORGANIZACIÓN DEL PROCESADOR (IRQ SIMÉTRICO)
# =========================================================================
Write-Host "[*] Limpiando asignaciones multimedia y restaurando políticas IRQ..."
$CpuBackupPath = "$BackupPath\CPU"
$SysProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

$RestResp = (Get-ItemProperty -Path $CpuBackupPath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue).SystemResponsiveness
$RestThrot = (Get-ItemProperty -Path $CpuBackupPath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex

Set-ItemProperty -Path $SysProfilePath -Name "SystemResponsiveness" -Type DWord -Value (if ($RestResp -ne $null) { $RestResp } else { 20 })
Set-ItemProperty -Path $SysProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value (if ($RestThrot -ne $null) { $RestThrot } else { 10 })

$TasksPath = "$SysProfilePath\Tasks\Games"
Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8
Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 2
Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "Medium"
Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "Normal"

# 🚀 RESTAURACIÓN IRQ GRANULAR: Devuelve las políticas originales de red del Kernel en vez de borrarlas a ciegas
$NetBackupKey = "$CpuBackupPath\NetworkAffinity"
$NetDevices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters\Interrupt Management\Affinity Policy" -ErrorAction SilentlyContinue
foreach ($Net in $NetDevices) {
    $DeviceID = ($Net.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
    $BckPolicy = (Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Policy" -ErrorAction SilentlyContinue)."${DeviceID}_Policy"
    $BckOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Override" -ErrorAction SilentlyContinue)."${DeviceID}_Override"
    
    if ($BckPolicy -ne $null) {
        if ($BckPolicy -eq 999) {
            Remove-ItemProperty -Path $Net.PSPath -Name "DevicePolicy"
            Remove-ItemProperty -Path $Net.PSPath -Name "AssignmentSetOverride"
        } else {
            Set-ItemProperty -Path $Net.PSPath -Name "DevicePolicy" -Type DWord -Value $BckPolicy
            if ($BckOverride) { Set-ItemProperty -Path $Net.PSPath -Name "AssignmentSetOverride" -Type Binary -Value $BckOverride } else { Remove-ItemProperty -Path $Net.PSPath -Name "AssignmentSetOverride" }
        }
    }
}

# =========================================================================
# 7. REVERTIR ALMACENAMIENTO E INTELIGENCIA NTFS
# =========================================================================
Write-Host "[*] Restableciendo marcas de tiempo y buffers del sistema de archivos..."
$StorageBackupPath = "$BackupPath\Storage"
$NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

$RestLastAccess = (Get-ItemProperty -Path $StorageBackupPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
$RestMemoryUsage = (Get-ItemProperty -Path $StorageBackupPath -Name "NtfsMemoryUsage" -ErrorAction SilentlyContinue).NtfsMemoryUsage

if ($RestLastAccess -ne $null) { Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value $RestLastAccess }
fsutil behavior set disablelastaccess (if ($RestLastAccess -eq 1) { 1 } else { 0 }) | Out-Null
fsutil behavior set disable8dot3 0 | Out-Null
fsutil behavior set memoryusage (if ($RestMemoryUsage -ne $null) { $RestMemoryUsage } else { 0 }) | Out-Null

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Type DWord -Value 3
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Type DWord -Value 3
powercfg.exe /hibernate on

# =========================================================================
# 8. REVERTIR TELEMETRÍA PROFUNDA Y FILTROS VBS/HVCI
# =========================================================================
Write-Host "[*] Encendiendo filtros de seguridad virtual (VBS / HVCI)..."
$TelemetryBackupPath = "$BackupPath\Telemetry"
$RestVbs = (Get-ItemProperty -Path $TelemetryBackupPath -Name "EnableVirtualizationBasedSecurity" -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
$RestHvci = (Get-ItemProperty -Path $TelemetryBackupPath -Name "Hvci_Enabled" -ErrorAction SilentlyContinue).Hvci_Enabled

Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value (if ($RestVbs -ne $null) { $RestVbs } else { 1 })
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Type DWord -Value (if ($RestHvci -ne $null) { $RestHvci } else { 1 })

try {
    Set-Service "DiagTrack" -StartupType Automatic
    Start-Service "DiagTrack"
} catch {}
Set-MpPreference -ScanAvgCPULoadFactor 50 
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities"
Get-NetFirewallRule -DisplayName "Overlord_Block_*" | Remove-NetFirewallRule

$AutologgerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
$Loggers = @("AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog", "Circular Kernel Context Logger", "ReadyBoot", "SetupPlatformTel", "WdiContextLog")
foreach ($Logger in $Loggers) { reg.exe add "$AutologgerPath\$Logger" /v "Start" /t REG_DWORD /d 1 /f | Out-Null }

if (-not $IsLaptop) {
    powercfg /SETACVALUEINDEX $PowerGuid 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a558deb 1
    $PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    $RestMax = (Get-ItemProperty -Path "$BackupPath\Power" -Name "ValueMax" -ErrorAction SilentlyContinue).ValueMax
    $RestMin = (Get-ItemProperty -Path "$BackupPath\Power" -Name "ValueMin" -ErrorAction SilentlyContinue).ValueMin
    if ($RestMax -ne $null) { Set-ItemProperty -Path $PowerPath -Name "ValueMax" -Type DWord -Value $RestMax }
    if ($RestMin -ne $null) { Set-ItemProperty -Path $PowerPath -Name "ValueMin" -Type DWord -Value $RestMin }
}
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e

# =========================================================================
# 9. REVERTIR GAME HOOKS (IFEO NO DESTRUCTIVO DESDE BACKUP)
# =========================================================================
Write-Host "[*] Removiendo inyecciones competitivas eSports de forma simétrica..."
$HooksBackupPath = "$BackupPath\GameHooks"
$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe", "FortniteClient-Win64-Shipping.exe", "r5apex.exe", "Overwatch.exe")
foreach ($Game in $TargetGames) {
    $GameKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game"
    if (Test-Path $GameKey) {
        if (Test-Path "$GameKey\PerfOptions") { Remove-Item -Path "$GameKey\PerfOptions" -Recurse -Force }
        Remove-ItemProperty -Path $GameKey -Name "DISABLEDXMAXIMIZEDWINDOWEDMODE"
        
        # Si había configuraciones previas inyectadas por el usuario, restaurarlas
        $BckFso = (Get-ItemProperty -Path $HooksBackupPath -Name "${Game}_FsoBypass" -ErrorAction SilentlyContinue)."${Game}_FsoBypass"
        if ($BckFso -ne $null) { Set-ItemProperty -Path $GameKey -Name "DISABLEDXMAXIMIZEDWINDOWEDMODE" -Type DWord -Value $BckFso }

        $KeyObj = Get-Item -Path $GameKey
        if ($KeyObj.SubKeyCount -eq 0 -and $KeyObj.ValueCount -eq 0) { Remove-Item -Path $GameKey -Force }
    }
}

# BORRADO QUIRÚRGICO FINAL DE LA PERSISTENCIA DE OVERLORD
Remove-Item -Path "HKLM:\SOFTWARE\Overlord" -Recurse -Force
Write-Host "[+] Desinfección completa. Sistema operativo restaurado a valores puros de fábrica al 100%."
exit 0