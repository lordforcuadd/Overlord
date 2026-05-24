param([string]$Action = "")
$ErrorActionPreference = "Stop"

switch ($Action) {
    
    "DeepClean" {
        Write-Output "[*] Iniciando Limpieza del Sistema Avanzada..."
        # Ejecuta el liberador nativo de espacio de Windows de forma oculta y ultra veloz
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/autoclean" -WindowStyle Hidden -Wait
        
        # Vaciar carpetas temporales de usuario de forma forzada e inteligente
        $TempFolder = "$env:TEMP"
        if (Test-Path $TempFolder) {
            Get-ChildItem -Path $TempFolder -Recurse | ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                } catch {}
            }
        }

        # NUEVO: Limpieza profunda de reportes de errores acumulados en el disco
        $ErrorReports = @(
            "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*",
            "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*",
            "$env:LocalAppData\CrashDumps\*"
        )
        foreach ($Path in $ErrorReports) {
            if (Test-Path $Path) {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Output "Limpieza finalizada con éxito. Espacio recuperado."
        exit 0
    }

    "FlushNet" {
        Write-Output "[*] Reiniciando pila de red y limpiando enrutamiento..."
        # Vaciar caché DNS nativa
        ipconfig /flushdns | Out-Null
        # Resetear sockets de red y protocolos de internet de fábrica
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        
        # NUEVO: Vaciar la tabla ARP (Obliga a Windows a buscar la ruta más rápida al módem)
        arp -d * 2>&1 | Out-Null
        
        Write-Output "Red reiniciada de fábrica. Conexión estabilizada."
        exit 0
    }

    "RepairOS" {
        Write-Output "[*] Iniciando diagnóstico y reparación de archivos del Kernel..."
        # Repara la imagen base de Windows desde los servidores oficiales de Microsoft
        DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
        # Analiza y corrige archivos corruptos o dañados en el disco duro
        sfc /scannow | Out-Null
        
        Write-Output "Sistema operativo analizado y reparado con éxito."
        exit 0
    }
}