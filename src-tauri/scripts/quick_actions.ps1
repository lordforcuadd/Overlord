param([string]$Action = "")
$ErrorActionPreference = "Stop"

switch ($Action) {
    
    "DeepClean" {
        # Modificado: AutoClean funciona de forma silenciosa sin necesidad de correr sageset primero.
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/autoclean" -WindowStyle Hidden -Wait
        
        $TempFolder = "$env:TEMP"

if (Test-Path $TempFolder) {
    # Obtenemos todos los elementos del directorio de forma recursiva
    Get-ChildItem -Path $TempFolder -Recurse | ForEach-Object {
        try {
            # Intentamos borrar el elemento actual (archivo o carpeta) sin hacer ruido si falla
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            # Si el archivo está en uso por el Kernel o un proceso, se ignora limpiamente y continúa
        }
    }
}
        
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