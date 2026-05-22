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

# 1. Periféricos (Revisa si el MouseDataQueueSize bajó de 100)
$mouse = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters").MouseDataQueueSize
if ($null -ne $mouse -and $mouse -lt 100) { $status.peripheralLatency = $true }

# 2. Debloat (Revisa si DiagTrack / Telemetría de Windows está apagada)
$diag = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack").Start
if ($null -ne $diag -and $diag -eq 4) { $status.debloat = $true }

# 3. Red (Revisa si QoS Limit está en 0)
$qos = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched").NonBestEffortLimit
if ($null -ne $qos -and $qos -eq 0) { $status.networkOptimized = $true }

# 4. Rendimiento (Revisa si el Fault Tolerant Heap está apagado)
$fth = (Get-ItemProperty "HKLM:\Software\Microsoft\FTH").Enabled
if ($null -ne $fth -and $fth -eq 0) { $status.generalPerformance = $true }

# 5. GPU Display (Revisa si el MPO está destruido)
$mpo = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Dwm").OverlayTestMode
if ($null -ne $mpo -and $mpo -eq 5) { $status.gpuDisplay = $true }

# 6. IRQ Affinity (Revisa si el SystemResponsiveness está al 0%)
$irq = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile").SystemResponsiveness
if ($null -ne $irq -and $irq -eq 0) { $status.irqAffinity = $true }

# 7. Almacenamiento Inteligente (Revisa si la creación 8dot3 está apagada)
$fs = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem").NtfsDisable8dot3NameCreation
if ($null -ne $fs -and $fs -eq 1) { $status.smartStorage = $true }

# 8. Telemetría Profunda / VBS (Revisa si la Seguridad Basada en Virtualización está apagada)
$vbs = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\DeviceGuard").EnableVirtualizationBasedSecurity
if ($null -ne $vbs -and $vbs -eq 0) { $status.deepTelemetry = $true }

# 9. Perfiles de Energía (Revisa si el limitador MMCSS de energía está anulado)
$pwr = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583").ValueMax
if ($null -ne $pwr -and $pwr -eq 0) { $status.powerProfiles = $true }

# 10. Game Hooks (Revisa si AL MENOS UN JUEGO tiene inyectada la prioridad de CPU)
$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe", "FortniteClient-Win64-Shipping.exe", "r5apex.exe", "Overwatch.exe")
foreach ($Game in $TargetGames) {
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions") { 
        $status.gameHooks = $true
        break # Si encuentra uno, ya marca el módulo como activo
    }
}

# Devuelve el objeto en JSON puro y minificado para que Vue lo lea
$status | ConvertTo-Json -Compress