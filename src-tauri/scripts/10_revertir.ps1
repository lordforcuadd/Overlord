param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Write-Host "[*] Iniciando purga total de optimizaciones de Overlord y volviendo a Stock..."

$BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"

try {
    $PowerGuid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='true'").InstanceID.Split('\')[1]
} catch {
    $PowerGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
}

# =========================================================================
# 1. REVERTIR PERIFÉRICOS, ACCESIBILIDAD Y RESTAURACIÓN MSI DETALLADA
# =========================================================================
Write-Host "[*] Restableciendo colas de periféricos y respuesta USB desde copia de seguridad..."

$RestMouQueue = (Get-ItemProperty -Path "$BackupPath\mouclass" -Name "MouseDataQueueSize" -ErrorAction SilentlyContinue).MouseDataQueueSize
$RestKbdQueue = (Get-ItemProperty -Path "$BackupPath\kbdclass" -Name "KeyboardDataQueueSize" -ErrorAction SilentlyContinue).KeyboardDataQueueSize

$MouValue = if ($RestMouQueue) { $RestMouQueue } else { 100 }
$KbdValue = if ($RestKbdQueue) { $RestKbdQueue } else { 100 }

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value $MouValue
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value $KbdValue
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 2

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

powercfg /SETACVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
powercfg /SETDCVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1

# =========================================================================
# 2. REVERTIR LIMPIEZA (DEBLOAT) Y RECONSTRUCCIÓN DE PAQUETES APPX NATIVOS
# =========================================================================
Write-Host "[*] Re-provisionando aplicaciones del sistema desde el almacén WinSxS..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Type DWord -Value 1

try {
    Get-AppxProvisionedPackage -Online | ForEach-Object {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
    }
} catch {}

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
Write-Host "[*] Normalizando la pila de red TCP/IP y descargas de hardware..."
$Interfaces = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
foreach ($Interface in $Interfaces) {
    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
    Remove-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue
}
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -ErrorAction SilentlyContinue

$DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
Remove-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -ErrorAction SilentlyContinue

Enable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
Enable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
Enable-NetAdapterLso -Name "*" -IPv4 -ErrorAction SilentlyContinue
Enable-NetAdapterLso -Name "*" -IPv6 -ErrorAction SilentlyContinue
Enable-NetAdapterChecksumOffload -Name "*" -IpIPv4 -ErrorAction SilentlyContinue

netsh int tcp set global autotuninglevel=normal | Out-Null
netsh int tcp set global ecncapability=disabled | Out-Null
netsh int tcp set global chimney=default | Out-Null

# =========================================================================
# 4. REVERTIR RENDIMIENTO, CPU Y RESTAURACIÓN DE PAGINACIÓN DESDE RESPALDO
# =========================================================================
Write-Host "[*] Restableciendo mitigaciones de procesador y archivos de paginación..."
$MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

$RestPaging = (Get-ItemProperty -Path "$BackupPath\Performance" -Name "DisablePagingExecutive" -ErrorAction SilentlyContinue).DisablePagingExecutive
$PagingVal = if ($RestPaging -ne $null) { $RestPaging } else { 0 }

Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value $PagingVal
Remove-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue
Enable-MMAgent -MemoryCompression

Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 1
$GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (Test-Path $GameBarPath) { Remove-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue }
Set-ItemProperty -Path "HKLM:\Software\Microsoft\FTH" -Name "Enabled" -Type DWord -Value 1

# =========================================================================
# 5. REVERTIR CONFIGURACIÓN DE GPU, ENTORNO VISUAL Y PROTECCIÓN HDCP
# =========================================================================
Write-Host "[*] Re-encendiendo MPO y restaurando aceleración de hardware por GPU (HAGS)..."
$RestHags = (Get-ItemProperty -Path "$BackupPath\GPU" -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
if ($RestHags -ne $null) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Type DWord -Value $RestHags
}

Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" -Name "value" -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe" -Recurse -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1

# Restauración granular dispositivo por dispositivo de la llave de protección HDCP
$HdcpBackupKey = "$BackupPath\GPU\HDCP"
$DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$Adapters = Get-ChildItem -Path $DisplayClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
$HdcpBackupKey = "$BackupPath\GPU\HDCP"
$DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$Adapters = Get-ChildItem -Path $DisplayClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
foreach ($Adapter in $Adapters) {
    $AdapterID = $Adapter.PSChildName
    $BackupHdcp = (Get-ItemProperty -Path $HdcpBackupKey -Name $AdapterID -ErrorAction SilentlyContinue).$AdapterID
    
    if ($BackupHdcp -ne $null) {
        if ($BackupHdcp -eq 999) {
            Remove-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" -ErrorAction SilentlyContinue
        } else {
            Set-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" -Type DWord -Value $BackupHdcp -Force
        }
    }
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

$NetDevices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters\Interrupt Management\Affinity Policy" -ErrorAction SilentlyContinue
foreach ($Net in $NetDevices) {
    Remove-ItemProperty -Path $Net.PSPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $Net.PSPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
}

# =========================================================================
# 7. REVERTIR ALMACENAMIENTO E INTELIGENCIA NTFS DESDE RESPALDO DE USUARIO
# =========================================================================
Write-Host "[*] Restableciendo marcas de tiempo del sistema de archivos..."
$NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

$RestLastAccess = (Get-ItemProperty -Path "$BackupPath\Storage" -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
if ($RestLastAccess -ne $null) {
    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value $RestLastAccess
} else {
    Remove-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue
}

fsutil behavior set disablelastaccess 0 | Out-Null
fsutil behavior set disable8dot3 0 | Out-Null
fsutil behavior set memoryusage 0 | Out-Null

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Type DWord -Value 3
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Type DWord -Value 3
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Type DWord -Value 0

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

Get-NetFirewallRule -DisplayName "Overlord_Block_*" | Remove-NetFirewallRule

$AutologgerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
$Loggers = @(
    "AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog",
    "Circular Kernel Context Logger", "ReadyBoot", "SetupPlatformTel", "WdiContextLog"
)
foreach ($Logger in $Loggers) {
    reg.exe add "$AutologgerPath\$Logger" /v "Start" /t REG_DWORD /d 1 /f | Out-Null
}

powercfg /SETACVALUEINDEX $PowerGuid 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a558deb 1

$PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
Set-ItemProperty -Path $PowerPath -Name "ValueMax" -Type DWord -Value 100
Set-ItemProperty -Path $PowerPath -Name "ValueMin" -Type DWord -Value 5
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e

# =========================================================================
# 9. LIMPIAR INTEGRIDAD DE GAME HOOKS (IFEO NO DESTRUCTIVO)
# =========================================================================
Write-Host "[*] Eliminando inyecciones de eSports salvando configuraciones previas..."
$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe", "FortniteClient-Win64-Shipping.exe", "r5apex.exe", "Overwatch.exe")
foreach ($Game in $TargetGames) {
    $GameKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game"
    
    if (Test-Path $GameKey) {
        # Remueve quirúrgicamente solo la subclave de prioridades creada por Overlord
        if (Test-Path "$GameKey\PerfOptions") { 
            Remove-Item -Path "$GameKey\PerfOptions" -Recurse -Force 
        }
        # Remueve la propiedad de pantalla completa específica de Overlord
        Remove-ItemProperty -Path $GameKey -Name "DISABLEDXMAXIMIZEDWINDOWEDMODE" -ErrorAction SilentlyContinue
        
        # Si la clave quedó completamente vacía sin más subllaves o valores, se limpia el registro
        $KeyObj = Get-Item -Path $GameKey
        if ($KeyObj.SubKeyCount -eq 0 -and $KeyObj.ValueCount -eq 0) {
            Remove-Item -Path $GameKey -Force
        }
    }
}

# BORRADO TOTAL DE LA COLMENA DE PERSISTENCIA PERSONALIZADA DE OVERLORD
Remove-Item -Path "HKLM:\SOFTWARE\Overlord" -Recurse -Force

Write-Host "[*] Restaurando preferencias estéticas y ajustes QoL de fábrica..."
$QolBackupKey = "HKLM:\SOFTWARE\Overlord\Backup\QoL"

if (Test-Path $QolBackupKey) {
    # Revertir el estado estructural del Menú Contextual Clásico de Windows 11
    $ClassicMenuStatus = (Get-ItemProperty -Path $QolBackupKey -Name "classicMenu_Status" -ErrorAction SilentlyContinue).classicMenu_Status
    if ($ClassicMenuStatus -eq 0) {
        Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Procesar de forma agregada el resto de propiedades resguardadas en la colmena
    $Properties = (Get-Item -Path $QolBackupKey).Property
    foreach ($Prop in $Properties) {
        if ($Prop -eq "classicMenu_Status") { continue }
        
        $BckVal = (Get-ItemProperty -Path $QolBackupKey -Name $Prop).$Prop
        
        # Desglosar los componentes originales de la propiedad (Ruta y Nombre de valor)
        if ($Prop -match "^(HKCU|HKLM)_(.*)_(.*)$") {
            $Hive = $Matches[1]
            $SubKey = $Matches[2] -replace "_", "\"
            $ValueName = $Matches[3]
            
            $FullRegPath = "${Hive}:\${SubKey}"
            
            if ($BckVal -eq 999) {
                if (Test-Path $FullRegPath) { 
                    Remove-ItemProperty -Path $FullRegPath -Name $ValueName -ErrorAction SilentlyContinue 
                }
            } else {
                if (!(Test-Path $FullRegPath)) { New-Item -Path $FullRegPath -Force | Out-Null }
                
                # Identificación automática de tipos para asegurar la integridad de la estructura
                $Type = "DWord"
                if ($ValueName -match "^(Flags|UserPreferencesMask)$") {
                    $Type = if ($ValueName -eq "Flags") { "String" } else { "Binary" }
                }
                Set-ItemProperty -Path $FullRegPath -Name $ValueName -Type $Type -Value $BckVal -Force | Out-Null
            }
        }
    }
}

Write-Host "[+] Desinfección completa. Sistema operativo restaurado a valores por defecto nativos al 100%."
exit 0