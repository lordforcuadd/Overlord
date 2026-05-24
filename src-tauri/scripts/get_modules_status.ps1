$ErrorActionPreference = "SilentlyContinue"
$status = @{
    peripheralLatency = $false
    debloat = $false
    networkOptimized = $false
    generalPerformance = $false
    gpuDisplay = $false
    irqAffinity = $false
    smartStorage = $false
    deepTelemetry = $false
    powerProfiles = $false
    gameHooks = $false
}

# 1. Periféricos (Revisa cola y parálisis de la aceleración legacy)
$mouse = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters").MouseDataQueueSize
$speed = (Get-ItemProperty "HKCU:\Control Panel\Mouse").MouseSpeed
if ($mouse -eq 20 -and $speed -eq "0") { $status.peripheralLatency = $true }

# 2. Debloat (Revisa si DiagTrack está deshabilitado de raíz)
$diag = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack").Start
if ($diag -eq 4) { $status.debloat = $true }

# 3. Red (Revisa QoS Limit en 0 y el NetworkThrottlingIndex deshabilitado)
$qos = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched").NonBestEffortLimit
$throttle = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile").NetworkThrottlingIndex
if ($qos -eq 0 -and $throttle -eq 4294967295) { $status.networkOptimized = $true }

# 4. Rendimiento (Revisa FTH deshabilitado y mitigaciones Spectre apagadas en 3)
$fth = (Get-ItemProperty "HKLM:\Software\Microsoft\FTH").Enabled
$spectre = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management").FeatureSettingsOverride
if ($fth -eq 0 -and $spectre -eq 3) { $status.generalPerformance = $true }

# 5. GPU Display (Revisa si el MPO está destruido)
$mpo = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Dwm").OverlayTestMode
if ($mpo -eq 5) { $status.gpuDisplay = $true }

# 6. IRQ Affinity (Revisa si el SystemResponsiveness está al 0%)
$irq = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile").SystemResponsiveness
if ($irq -eq 0) { $status.irqAffinity = $true }

# 7. Almacenamiento Inteligente (Revisa si disablelastaccess está activo y memoryusage en 2)
$lastaccess = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem").NtfsDisableLastAccessUpdate
$memoryusage = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem").NtfsMemoryUsage
if ($lastaccess -eq 1 -and $memoryusage -eq 2) { $status.smartStorage = $true }

# 8. Telemetría Profunda / VBS (Revisa si la Seguridad Basada en Virtualización está apagada)
$vbs = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\DeviceGuard").EnableVirtualizationBasedSecurity
if ($vbs -eq 0) { $status.deepTelemetry = $true }

# 9. Perfiles de Energía (Revisa si el limitador MMCSS de energía está anulado)
$pwr = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583").ValueMax
if ($pwr -eq 0) { $status.powerProfiles = $true }

# 10. Game Hooks (Revisa si al menos un juego tiene inyectada la prioridad de CPU)
$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe", "FortniteClient-Win64-Shipping.exe", "r5apex.exe", "Overwatch.exe")
foreach ($Game in $TargetGames) {
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions") { 
        $status.gameHooks = $true
        break
    }
}

$status | ConvertTo-Json -Compress