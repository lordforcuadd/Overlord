param([string]$ActionId)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Try {
    switch ($ActionId) {
        "DeepClean" {
            # Papelera de reciclaje
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null

            # Compactación del almacén de componentes DISM
            Start-Process -FilePath "dism.exe" -ArgumentList "/online /Cleanup-Image /StartComponentCleanup" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null

            # Purga directa de Caché de Shaders (DirectX, NVIDIA, AMD, Intel)
            $ShaderPaths = @(
                "$env:localappdata\D3DSCache",
                "$env:localappdata\Microsoft\Direct3D",
                "$env:localappdata\NVIDIA\DXCache",
                "$env:localappdata\NVIDIA\ComputeCache",
                "$env:appdata\NVIDIA\GLCache",
                "$env:localappdata\AMD\DxCache",
                "$env:userprofile\AppData\LocalLow\Intel\ShaderCache"
            )
            foreach ($Path in $ShaderPaths) {
                if (Test-Path $Path) {
                    Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }

            # Configurar perfiles para cleanmgr (DirectX Shader Cache y temporales)
            $VolumeCaches = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            if (Test-Path $VolumeCaches) {
                reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\ActiveX Cache" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
                reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
                reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Internet Cache Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
                reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Old Chkdsk Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
                reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
                reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
                reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
                reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\DirectX Shader Cache" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
                
                # Nota: Omitimos "Update Cleanup" por lentitud extrema e irrelevancia en el rendimiento de juegos
            }

            # Ejecución y control de finalización de cleanmgr.exe (sagerun)
            $CleanProcess = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            if ($CleanProcess) {
                $Timeout = 60 # Ampliado a 1 minuto (60 segundos)
                $Interval = 1
                $Waited = 0
                while (-not $CleanProcess.HasExited -and $Waited -lt $Timeout) {
                    Start-Sleep -Seconds $Interval
                    $Waited += $Interval
                }
                # Forzar detención si queda colgado o excede el timeout de limpieza rápida
                if (-not $CleanProcess.HasExited) {
                    Stop-Process -InputObject $CleanProcess -Force -ErrorAction SilentlyContinue
                }
            }

            # Limpiar los flags temporales creados para evitar polución del registro
            if (Test-Path $VolumeCaches) {
                $Caches = Get-ChildItem -Path $VolumeCaches -ErrorAction SilentlyContinue
                foreach ($Cache in $Caches) {
                    Remove-ItemProperty -Path $Cache.PSPath -Name "StateFlags0001" -ErrorAction SilentlyContinue | Out-Null
                }
            }
            
            # Vaciado ultra-rápido multihilo con Robocopy (ideal para sistemas con años sin limpiar)
            $EmptyDir = Join-Path $env:temp "OverlordEmptyDir"
            if (!(Test-Path $EmptyDir)) {
                New-Item -Path $EmptyDir -ItemType Directory -Force | Out-Null
            }

            if (Test-Path $env:localappdata\Temp) {
                robocopy.exe $EmptyDir $env:localappdata\Temp /mir /w:0 /r:0 /MT:32 /njh /njs /ndl /nc /ns /np | Out-Null
            }

            if (Test-Path "$env:windir\Temp") {
                robocopy.exe $EmptyDir "$env:windir\Temp" /mir /w:0 /r:0 /MT:32 /njh /njs /ndl /nc /ns /np | Out-Null
            }

            if (Test-Path $EmptyDir) {
                Remove-Item -Path $EmptyDir -Force -ErrorAction SilentlyContinue | Out-Null
            }

            Write-Output "OK: Limpieza profunda de almacenamiento y caches completada."
        }
        "RepairOS" {
            # DISM requiere wuauserv (Windows Update) habilitado e iniciado para descargar reparaciones
            $wuauserv = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
            $originalStartType = $null
            $wasRunning = $false
            if ($null -ne $wuauserv) {
                $CimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='wuauserv'" -ErrorAction SilentlyContinue
                if ($null -ne $CimSvc) {
                    $originalStartType = $CimSvc.StartMode
                } else {
                    $WmiSvc = Get-WmiObject -Class Win32_Service -Filter "Name='wuauserv'" -ErrorAction SilentlyContinue
                    if ($null -ne $WmiSvc) { $originalStartType = $WmiSvc.StartMode }
                }
                $wasRunning = ($wuauserv.Status -eq 'Running')
                if ($null -ne $originalStartType -and $originalStartType -eq 'Disabled') {
                    Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
                }
                if (-not $wasRunning) {
                    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
                }
            }

            dism.exe /online /cleanup-image /restorehealth | Out-Null
            sfc.exe /scannow | Out-Null

            # Restaurar estado original del servicio Windows Update
            if ($null -ne $wuauserv) {
                if (-not $wasRunning) {
                    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                }
                if ($null -ne $originalStartType -and $originalStartType -eq 'Disabled') {
                    Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
            Write-Output "OK: Almacen de componentes e integridad de sistema reparados."
        }
        "FlushNet" {
            ipconfig /release | Out-Null
            ipconfig /flushdns | Out-Null
            ipconfig /renew | Out-Null
            netsh int ip reset | Out-Null
            netsh winsock reset | Out-Null
            Write-Output "ADVERTENCIA: Catalogos de red restablecidos. Es obligatorio reiniciar el equipo para evitar estados de red inconsistentes."
        }
        "RestartExplorer" {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
                Start-Process explorer.exe
            }
            Write-Output "OK: Explorador de Windows reiniciado con exito."
        }
    }
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Acciones Rapidas: $_"
    exit 1
}