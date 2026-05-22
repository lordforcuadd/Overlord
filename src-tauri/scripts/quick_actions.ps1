param([string]$Action = "")
$ErrorActionPreference = "Stop"

switch ($Action) {
    "DeepClean" {
        # Modificado: AutoClean funciona de forma silenciosa sin necesidad de correr sageset primero.
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/autoclean" -WindowStyle Hidden -Wait
        
        # Opcional: Borrado forzado de basura temporal
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -Confirm:$false
        Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -Confirm:$false
        
        Write-Output "Limpieza finalizada."
        exit 0
    }
    "FlushNet" {
        ipconfig /flushdns | Out-Null
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-Output "Red reiniciada."
        exit 0
    }
    "RepairOS" {
        DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
        sfc /scannow | Out-Null
        Write-Output "OS Reparado."
        exit 0
    }
}