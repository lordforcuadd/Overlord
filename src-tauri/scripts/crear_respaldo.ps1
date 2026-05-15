param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando protocolo de seguridad: Punto de Restauracion..."
    
    $Description = "Overlord V1 - Punto Seguro (Stock)"

    # Activar la protección del sistema en el disco C: (por si el usuario lo tiene apagado)
    Enable-ComputerRestore -Drive "C:\" | Out-Null

    # Crear el punto de restauración
    Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"

    Write-Host "[+] Punto de restauración creado con exito. El sistema está blindado."
    exit 0
} Catch {
    Write-Error "[-] Error al crear el punto de restauracion. Revisa si el servicio VSS está activo: $_"
    exit 1
}