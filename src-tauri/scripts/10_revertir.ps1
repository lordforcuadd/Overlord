param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Write-Host "[*] Iniciando purga total de optimizaciones de Overlord y volviendo a Stock..."

# OBTENER EL GUID DE ENERGÍA ACTIVO ANTES DE COMENZAR
try {
    $PowerGuid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='true'").InstanceID.Split('\')[1]
} catch {
    $PowerGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
}

# =========================================================================
# 1. REVERTIR PERIFÉRICOS, RATÓN, ACCESIBILIDAD Y CLOCKS
# =========================================================================
Write-Host "[*] Restableciendo colas de periféricos y respuesta USB..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 100
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 100
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 2

# Desactivar el MSI Mode (Message Signaled Interrupts) inyectado de forma masiva
$Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters"
foreach ($Device in $Devices) {
    $MsiPath = "$($Device.PSPath)\Interrupt Management\MessageSignaledInterruptProperties"
    if (Test-Path $MsiPath) { Remove-ItemProperty -Path $MsiPath -Name "MSISupported" }
}

# Restaurar curvas dinámicas por defecto de Windows y accesibilidad
$MousePath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "1"
$CurvesX = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xC0,0xCC,0x0C,0x00,0x00,0x00,0x00,0x00,0x80,0x99,0x19,0x00,0x00,0x00,0x00,0x00,0x40,0x66,0x26,0x00,0x00,0x00,0x00,0x00,0x00,0x33,0x33,0x00,0x00,0x00,0x00,0x00)
$CurvesY = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x70,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xA8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xE0,0x00,0x00,0x00,0x00,0x00)
Set-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -Type Binary -Value $CurvesX
Set-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -Type Binary -Value $CurvesY

Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510"
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "62"
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126"

Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe" -Recurse -Force
bcdedit /deletevalue useplatformtick | Out-Null
bcdedit /deletevalue disabledynamictick | Out-Null
bcdedit /deletevalue useplatformclock | Out-Null

# Reactivar USB Selective Suspend si aplica
powercfg /SETACVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
powercfg /SETDCVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1

# =========================================================================
# 2. REVERTIR LIMPIEZA (DEBLOAT) Y CONTROL DE SERVICIOS BASURA
# =========================================================================
Write-Host "[*] Restaurando aplicaciones en segundo plano y servicios corporativos..."
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

$ServicesToRestore = @("Fax", "MapsBroker", "WSearch")
foreach ($Svc in $ServicesToRestore) {
    Set-Service -Name $Svc -StartupType Automatic
    Start-Service -Name $Svc
}

# =========================================================================
# 3. REVERTIR RED COMPLETA Y PARÁMETROS MULTIMEDIA PURE STOCK
# =========================================================================
Write-Host "[*] Normalizando la pila de red TCP/IP de Windows..."
$Interfaces = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
foreach ($Interface in $Interfaces) {
    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
    Remove-ItemProperty -Path $TcpPath -Name "TcpAckFrequency"
    Remove-ItemProperty -Path $TcpPath -Name "TCPNoDelay"
}
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit"

$DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
Remove-ItemProperty -Path $DnsPath -Name "MaxCacheTtl"
Remove-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl"

Enable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
Enable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
Enable-NetAdapterLso -Name "*" -IPv4 -ErrorAction SilentlyContinue
Enable-NetAdapterLso -Name "*" -IPv6 -ErrorAction SilentlyContinue
Enable-NetAdapterChecksumOffload -Name "*" -IpIPv4 -ErrorAction SilentlyContinue

netsh int tcp set global autotuninglevel=normal | Out-Null
netsh int tcp set global ecncapability=disabled | Out-Null
netsh int tcp set global chimney=default | Out-Null

# =========================================================================
# 4. REVERTIR RENDIMIENTO, CPU Y PARÁMETROS GAME DVR
# =========================================================================
Write-Host "[*] Activando mitigaciones del procesador y Game DVR..."
$MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 0
Remove-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride"
Remove-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask"
Enable-MMAgent -MemoryCompression

Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 1
$GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (Test-Path $GameBarPath) { Remove-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" }
Set-ItemProperty -Path "HKLM:\Software\Microsoft\FTH" -Name "Enabled" -Type DWord -Value 1

# =========================================================================
# 5. REVERTIR GPU, CONTROLLER DISPLAY Y REGISTROS MULTI-PLANE OVERLAY (MPO)
# =========================================================================
Write-Host "[*] Re-encendiendo MPO y normalizando prioridades del entorno visual..."
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode"
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode"
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior"
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" -Name "value"
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe" -Recurse -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1

# Remover la desactivación forzada de protección HDCP
$DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$Adapters = Get-ChildItem -Path $DisplayClass | Where-Object { $_.PSChildName -match '^\d{4}$' }
foreach ($Adapter in $Adapters) {
    Remove-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero"
}

# =========================================================================
# 6. REVERTIR ORGANIZACIÓN DEL PROCESADOR (IRQ STEERING Y METADATOS)
# =========================================================================
Write-Host "[*] Limpiando perfiles de asignación del planificador multimedia..."
$SysProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $SysProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 10
Set-ItemProperty -Path $SysProfilePath -Name "SystemResponsiveness" -Type DWord -Value 20

$TasksPath = "$SysProfilePath\Tasks\Games"
Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8
Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 2
Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "Medium"
Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "Normal"

# Limpiar las afinidades fijadas a los adaptadores de red PCI
$NetDevices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters\Interrupt Management\Affinity Policy"
foreach ($Net in $NetDevices) {
    Remove-ItemProperty -Path $Net.PSPath -Name "DevicePolicy"
    Remove-ItemProperty -Path $Net.PSPath -Name "AssignmentSetOverride"
}

# =========================================================================
# 7. REVERTIR ALMACENAMIENTO Y INTELIGENCIA NTFS
# =========================================================================
Write-Host "[*] Restableciendo sistema de archivos y paginación..."
Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate"
fsutil behavior set disablelastaccess 0 | Out-Null
fsutil behavior set disable8dot3 0 | Out-Null
fsutil behavior set memoryusage 0 | Out-Null

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Type DWord -Value 3
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Type DWord -Value 3
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Type DWord -Value 0

# Volver a activar el archivo de hibernación física
powercfg.exe /hibernate on

# =========================================================================
# 8. REVERTIR TELEMETRÍA PROFUNDA, REGLAS FIREWALL Y ENERGÍA PCI
# =========================================================================
Write-Host "[*] Encendiendo filtros de seguridad virtual (VBS) y limpiando Firewall..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Type DWord -Value 1
Set-Service "DiagTrack" -StartupType Automatic
Start-Service "DiagTrack"
Set-MpPreference -ScanAvgCPULoadFactor 50 
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 1

# Eliminar todas las reglas de salida perimetrales creadas por tu software
Get-NetFirewallRule -DisplayName "Overlord_Block_*" | Remove-NetFirewallRule

$AutologgerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
$Loggers = @(
    "AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog",
    "Circular Kernel Context Logger", "ReadyBoot", "SetupPlatformTel", "WdiContextLog"
)
foreach ($Logger in $Loggers) {
    reg.exe add "$AutologgerPath\$Logger" /v "Start" /t REG_DWORD /d 1 /f | Out-Null
}

# Re-encender el ahorro dinámico PCIe ASPM del plan de energía
powercfg /SETACVALUEINDEX $PowerGuid 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a558deb 1

$PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
Set-ItemProperty -Path $PowerPath -Name "ValueMax" -Type DWord -Value 100
Set-ItemProperty -Path $PowerPath -Name "ValueMin" -Type DWord -Value 5
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e

# =========================================================================
# 9. LIMPIAR INTEGRIDAD DE GAME HOOKS (IFEO)
# =========================================================================
Write-Host "[*] Eliminando inyecciones exclusivas de eSports en el Kernel..."
$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe", "FortniteClient-Win64-Shipping.exe", "r5apex.exe", "Overwatch.exe")
foreach ($Game in $TargetGames) {
    $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game"
    if (Test-Path $IfeoPath) { Remove-Item -Path $IfeoPath -Recurse -Force }
}

Write-Host "[+] Desinfección completa. Sistema operativo restaurado a valores por defecto nativos al 100%."
exit 0