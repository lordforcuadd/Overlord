$ErrorActionPreference = "SilentlyContinue"

# Inicialización de la máquina de estados lógicos simétrica con Pinia Store
$status = @{
    peripheralLatency  = $false
    debloat             = $false
    networkOptimized   = $false
    generalPerformance = $false
    gpuDisplay         = $false
    irqAffinity        = $false
    smartStorage       = $false
    deepTelemetry      = $false
    powerProfiles      = $false
    gameHooks          = $false
}

# Función helper defensiva para prevenir excepciones de desbordamiento en consultas de Registro
function Get-RegValue {
    param([string]$Path, [string]$Name)
    try {
        if (Test-Path $Path) {
            $Item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($Item -ne $null -and $Item.PSObject.Properties[$Name]) { 
                return $Item.$Name 
            }
        }
    } catch {}
    return $null
}

# 1. Respuesta de Teclado y Ratón
$mouse = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" "MouseDataQueueSize"
$speed = Get-RegValue "HKCU:\Control Panel\Mouse" "MouseSpeed"
if ($mouse -eq 20 -and $speed -eq "0") { $status.peripheralLatency = $true }

# 2. Limpieza del Sistema (Debloat)
$diag = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" "Start"
if ($diag -eq 4) { $status.debloat = $true }

# 3. Optimización de Internet
$qos = Get-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit"
$throttle = Get-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex"
if ($qos -eq 0 -and $throttle -eq 4294967295) { $status.networkOptimized = $true }

# 4. Potencia Bruta y Procesador
$fth = Get-RegValue "HKLM:\Software\Microsoft\FTH" "Enabled"
$spectre = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride"
if ($fth -eq 0 -and $spectre -eq 3) { $status.generalPerformance = $true }

# 5. Fluidez de Pantalla y Gráficos
$mpo = Get-RegValue "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode"
if ($mpo -eq 5) { $status.gpuDisplay = $true }

# 6. Organización del Procesador
$irq = Get-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness"
if ($irq -eq 0) { $status.irqAffinity = $true }

# 7. Aceleración de Disco y Almacenamiento
$lastaccess = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate"
$memoryusage = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage"
if ($lastaccess -eq 1 -and $memoryusage -eq 2) { $status.smartStorage = $true }

# 8. Seguridad Virtual y Filtros
$vbs = Get-RegValue "HKLM:\System\CurrentControlSet\Control\DeviceGuard" "EnableVirtualizationBasedSecurity"
if ($vbs -eq 0) { $status.deepTelemetry = $true }

# 9. Energía Inteligente Antiparos
$pwr = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" "ValueMax"
if ($pwr -eq 0) { $status.powerProfiles = $true }

# 10. Prioridad Absoluta para Juegos
$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe", "FortniteClient-Win64-Shipping.exe", "r5apex.exe", "Overwatch.exe")
foreach ($Game in $TargetGames) {
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions") { 
        $status.gameHooks = $true
        break
    }
}

# Serialización comprimida limpia enviada directamente al canal de entrada de Rust
$status | ConvertTo-Json -Compress