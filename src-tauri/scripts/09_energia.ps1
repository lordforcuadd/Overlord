param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Configurando inyecciones de energía avanzadas y Core Parking..."

    $PowerGuid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='true'").InstanceID.Split('\')[1]

    if ($IsLaptop) {
        Write-Host "    -> Laptop detectada: Optimizando control térmico y límites de energía..."
        # Control térmico equilibrado para evitar estrangulamiento por calor extremo
        powercfg /SETACVALUEINDEX $PowerGuid 54533251-82be-4824-96c1-47b60b740d00 94D3A615-A899-4AC5-AE2B-E4D8F634367F 1 
        powercfg /SETDCVALUEINDEX $PowerGuid 54533251-82be-4824-96c1-47b60b740d00 94D3A615-A899-4AC5-AE2B-E4D8F634367F 1
    } else {
        Write-Host "    -> Computadora de Escritorio detectada: Deshabilitando Core Parking y ahorros PCIe..."
        
        # Deshabilitar ASPM (PCIe Link State Power Management) - Previene caídas bruscas de FPS
        powercfg /SETACVALUEINDEX $PowerGuid 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a558deb 0

        # Anulación completa del Core Parking (Mantiene todos los núcleos activos al 100%)
        $PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
        if (Test-Path $PowerPath) {
            Set-ItemProperty -Path $PowerPath -Name "ValueMax" -Type DWord -Value 0 -Force
            Set-ItemProperty -Path $PowerPath -Name "ValueMin" -Type DWord -Value 0 -Force
        }
        powercfg /SETACVALUEINDEX $PowerGuid 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
        powercfg /SETACVALUEINDEX $PowerGuid 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
    }
    
    powercfg /SETACTIVE $PowerGuid
    exit 0
} Catch {
    exit 1
}