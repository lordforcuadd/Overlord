$ErrorActionPreference = "SilentlyContinue"

# Detectar dinámicamente el factor de forma del equipo antes del mapeo de estados
try {
    $Chasis = (Get-CimInstance -ClassName Win32_SystemEnclosure).ChassisTypes
    $IsLaptop = if ($Chasis -intersect @(8, 9, 10, 11, 14, 30, 31)) { $true } else { $false }
} catch {
    $IsLaptop = $false
}

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

# 1. Respuesta de Teclado y Ratón (Detección Adaptativa de Touchpad)
$mouseQueue = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" "MouseDataQueueSize"
$kbdQueue   = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" "KeyboardDataQueueSize"
if ($mouseQueue -eq 20 -and $kbdQueue -eq 20) { 
    $status.peripheralLatency = $true 
}

# 2. Limpieza del Sistema (Debloat)
$diag = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" "Start"
if ($diag -eq 4) { $status.debloat = $true }

# 3. Optimización de Internet (Detección Flexible de Controladores Wi-Fi)
$qos = Get-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit"
$throttle = Get-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex"
if ($qos -eq 0 -and $throttle -eq 4294967295) { 
    $status.networkOptimized = $true 
}

# 4. Potencia Bruta y Procesador (Detección Sensible a Planes Móviles)
$fth = Get-RegValue "HKLM:\Software\Microsoft\FTH" "Enabled"
$spectre = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride"
if ($fth -eq 0) {
    if ($IsLaptop -or $spectre -eq 3) {
        $status.generalPerformance = $true
    }
}

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

# 9. Energía Inteligente Antiparos (Validación de Límites Adaptativos de Laptop)
if ($IsLaptop) {
    # Si es Laptop, validamos la existencia de las directivas del plan móvil optimizado
    $acValue = powercfg /q SCHEME_CURRENT SUB_PROCESSOR 94D3A615-A899-4AC5-AE2B-E4D8F634367F
    if ($acValue -match "0x00000001" -or $null -eq $acValue) { $status.powerProfiles = $true }
} else {
    $pwr = Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" "ValueMax"
    if ($pwr -eq 0) { $status.powerProfiles = $true }
}

# 10. Prioridad Absoluta para Juegos
$IfeoRoot = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
$Catalog = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe", "FortniteClient-Win64-Shipping.exe", "r5apex.exe", "Overwatch.exe")

if (Test-Path $IfeoRoot) {
    # Escanear las subclaves reales creadas en el registro del sistema operativo
    $SubKeys = Get-ChildItem -Path $IfeoRoot -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
    
    # Filtrar si los ganchos optimizados activos pertenecen a la suite de Overlord
    $ActiveHooks = $SubKeys | Where-Object { $_ -in $Catalog }
    
    foreach ($Hook in $ActiveHooks) {
        $CpuPriority = Get-RegValue "$IfeoRoot\$Hook\PerfOptions" "CpuPriorityClass"
        $FsoBypass   = Get-RegValue "$IfeoRoot\$Hook" "DISABLEDXMAXIMIZEDWINDOWEDMODE"
        
        # Si al menos un juego seleccionado posee los ganchos inyectados, el módulo está activo
        if ($CpuPriority -eq 3 -and $FsoBypass -eq 1) {
            $status.gameHooks = $true
            break
        }
    }
}

# Serialización comprimida limpia hacia el backend de Rust
$status | ConvertTo-Json -Compress