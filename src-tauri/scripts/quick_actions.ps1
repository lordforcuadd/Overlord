param(
    [string]$ActionId,
    [string]$GameList
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TargetAction = if (![string]::IsNullOrWhiteSpace($GameList)) { $GameList } else { $ActionId }

Try {
    switch ($TargetAction) {
        "DeepClean" {
            # Papelera de reciclaje
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null

            # Compactacion del almacen de componentes DISM con limite de espera (5 min)
            $dismProc = Start-Process -FilePath "dism.exe" -ArgumentList "/online /Cleanup-Image /StartComponentCleanup" -NoNewWindow -PassThru -ErrorAction SilentlyContinue
            if ($null -ne $dismProc) {
                if (-not $dismProc.WaitForExit(300000)) {
                    Write-Warning "DISM StartComponentCleanup excedio el tiempo de espera de 5 minutos; continuara finalizando en segundo plano para proteger la integridad del almacen de componentes"
                }
            }

            # Purga directa de Cache de Shaders (DirectX, NVIDIA, AMD, Intel)
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
                $CacheKeys = @(
                    "ActiveX Cache", "Downloaded Program Files", "Internet Cache Files",
                    "Old Chkdsk Files", "Previous Installations", "Setup Log Files",
                    "Temporary Files", "DirectX Shader Cache"
                )
                foreach ($Key in $CacheKeys) {
                    $FullPath = Join-Path $VolumeCaches $Key
                    if (Test-Path $FullPath) {
                        Set-ItemProperty -Path $FullPath -Name "StateFlags0001" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
                # Nota: Omitimos "Update Cleanup" por lentitud extrema e irrelevancia en el rendimiento de juegos
            }

            # Ejecucion y control de finalizacion de cleanmgr.exe (sagerun)
            $CleanProcess = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            if ($CleanProcess) {
                $Timeout = 180 # Ampliado a 3 minutos (180 segundos) para tolerar discos mecanicos HDD
                $Interval = 1
                $Waited = 0
                while (-not $CleanProcess.HasExited -and $Waited -lt $Timeout) {
                    Start-Sleep -Seconds $Interval
                    $Waited += $Interval
                }
                # Forzar detencion si queda colgado o excede el timeout de limpieza rapida
                if (-not $CleanProcess.HasExited) {
                    Stop-Process -InputObject $CleanProcess -Force -ErrorAction SilentlyContinue
                }
            }

            # Limpiar los flags temporales creados para evitar polucion del registro
            if (Test-Path $VolumeCaches) {
                $Caches = Get-ChildItem -Path $VolumeCaches -ErrorAction SilentlyContinue
                foreach ($Cache in $Caches) {
                    Remove-ItemProperty -Path $Cache.PSPath -Name "StateFlags0001" -ErrorAction SilentlyContinue | Out-Null
                }
            }
            
            # Vaciado seguro de carpetas temporales (omite archivos en uso sin corromper datos de procesos en ejecucion)
            $TempFolders = @("$env:localappdata\Temp", "$env:windir\Temp")
            foreach ($TDir in $TempFolders) {
                if (Test-Path $TDir) {
                    Get-ChildItem -Path $TDir -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Get-ChildItem -Path $TDir -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }

            Write-Output "OK: Limpieza profunda de almacenamiento y caches completada."
        }
        "RepairOS" {
            $DismExit = -1
            $SfcExit = -1
            # DISM requiere wuauserv (Windows Update) habilitado e iniciado para descargar reparaciones
            $wuauserv = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
            $originalStartType = $null
            $wasRunning = $false
            $SvcBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Services\wuauserv"
            if ($null -ne $wuauserv) {
                # Persistencia del respaldo del servicio wuauserv para recuperacion robusta en reversion
                if (!(Test-Path $SvcBackupPath)) { New-Item -Path $SvcBackupPath -Force | Out-Null }
                
                # Respaldar tipo de inicio original si no existe backup previo
                $StartProps = Get-ItemProperty -Path $SvcBackupPath -ErrorAction SilentlyContinue
                if ($null -eq $StartProps -or $null -eq $StartProps.PSObject.Properties["Start"]) {
                    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv" -ValueName "Start" -BackupSubFolder "Services\wuauserv"
                }

                # Respaldar estado de ejecucion original si no existe backup previo
                if ($null -eq $StartProps -or $null -eq $StartProps.PSObject.Properties["WasRunning"]) {
                    $WasRunningVal = if ($wuauserv.Status -eq "Running") { 1 } else { 0 }
                    Set-ItemProperty -Path $SvcBackupPath -Name "WasRunning" -Value $WasRunningVal -Force -ErrorAction SilentlyContinue | Out-Null
                }

                $CimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='wuauserv'" -ErrorAction SilentlyContinue
                if ($null -ne $CimSvc) {
                    $originalStartType = $CimSvc.StartMode
                }
                $freshWuauserv = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
                $wasRunning = ($null -ne $freshWuauserv -and $freshWuauserv.Status -eq 'Running')
                if ($null -ne $originalStartType -and $originalStartType -eq 'Disabled') {
                    Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
                }
                if (-not $wasRunning) {
                    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
                }
            }

            try {
                dism.exe /online /cleanup-image /restorehealth | Out-Null
                $DismExit = $LASTEXITCODE
    
                sfc.exe /scannow | Out-Null
                $SfcExit = $LASTEXITCODE
            } finally {
                # Restaurar estado original del servicio Windows Update incondicionalmente
                if ($null -ne $wuauserv) {
                    if (-not $wasRunning) {
                        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                    }
                    if ($null -ne $originalStartType -and $originalStartType -eq 'Disabled') {
                        Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
                    }
                    
                    # En caso de exito, podemos eliminar el backup local del servicio
                    if ($DismExit -eq 0 -and $SfcExit -eq 0) {
                        Remove-Item -Path $SvcBackupPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }

            if ($DismExit -eq 0 -and $SfcExit -eq 0) {
                Write-Output "OK: Almacen de componentes e integridad de sistema reparados."
            } else {
                $FailParts = @()
                if ($DismExit -ne 0) { $FailParts += "DISM (codigo $DismExit)" }
                if ($SfcExit -ne 0) { $FailParts += "SFC (codigo $SfcExit)" }
                $FailMsg = "Fallo en la reparacion del sistema: " + ($FailParts -join " y ") + "."
                Write-Output "[WARNING] $FailMsg"
                exit 2
            }
        }
        "FlushNet" {
            ipconfig /flushdns | Out-Null
            ipconfig /registerdns | Out-Null
            netsh winsock reset | Out-Null
            ipconfig /renew | Out-Null
            Write-Output "OK: DNS vaciado, catalogo Winsock restablecido y DHCP renovado (configuracion de IP estatica preservada). Se recomienda reiniciar si experimentaba problemas de red."
        }
        "RestartExplorer" {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
                Start-Process explorer.exe
            }
            Write-Output "OK: Explorador de Windows reiniciado con exito."
        }
        default {
            throw "Accion rapida no reconocida: '$TargetAction'"
        }
    }
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Acciones Rapidas: $_"
    exit 1
}
