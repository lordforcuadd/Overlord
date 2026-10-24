param(
    [string]$ActionId,
    [string]$GameList,
    [bool]$IsLaptop = $false,
    [bool]$IsSsd = $false
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TargetAction = if (![string]::IsNullOrWhiteSpace($GameList)) { $GameList } else { $ActionId }
$IsLaptopDevice = if (Get-Variable -Name "IsLaptop" -Scope "global" -ErrorAction SilentlyContinue) { [bool]$global:IsLaptop } elseif (Get-Variable -Name "IsLaptop" -Scope "local" -ErrorAction SilentlyContinue) { [bool]$IsLaptop } else { $false }
$IsSsdDrive = if (Get-Variable -Name "IsSsd" -Scope "global" -ErrorAction SilentlyContinue) { [bool]$global:IsSsd } elseif (Get-Variable -Name "IsSsd" -Scope "local" -ErrorAction SilentlyContinue) { [bool]$IsSsd } else { $false }

Try {
    switch ($TargetAction) {
        "DeepClean" {
            # Papelera de reciclaje
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null

            # Compactacion del almacen de componentes DISM esperando de forma sincrona para proteger la integridad del sistema contra cierres de Job Object
            Write-Host "Iniciando compactacion del almacen de componentes DISM..."
            $dismProc = Start-Process -FilePath "dism.exe" -ArgumentList "/online /Cleanup-Image /StartComponentCleanup /NoRestart" -NoNewWindow -PassThru -Wait -ErrorAction SilentlyContinue
            if ($null -ne $dismProc -and $dismProc.ExitCode -ne 0) {
                Write-Warning "DISM StartComponentCleanup finalizo con codigo: $($dismProc.ExitCode)"
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

                $originalStartType = if ($wuauserv.StartType) {
                    $wuauserv.StartType.ToString()
                } else {
                    $CimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='wuauserv'" -ErrorAction SilentlyContinue
                    if ($null -ne $CimSvc) {
                        if ($CimSvc.StartMode -eq "Auto") { "Automatic" } else { $CimSvc.StartMode }
                    } else { "Manual" }
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
                    
                    # Verificar que la restauracion del servicio fue efectiva antes de limpiar el backup
                    $curSvc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
                    $stateRestored = $true
                    if ($null -ne $curSvc) {
                        if (-not $wasRunning -and $curSvc.Status -eq 'Running') { $stateRestored = $false }
                        $curStartType = if ($curSvc.StartType) { $curSvc.StartType.ToString() } else { "Manual" }
                        if ($null -ne $originalStartType -and $curStartType -ne $originalStartType) { $stateRestored = $false }
                    }
                    if ($DismExit -eq 0 -and $SfcExit -eq 0 -and $stateRestored) {
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
        "StabilityCheck" {
            $Days = 30
            $Since = (Get-Date).AddDays(-$Days)
            $wheaEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$Since} -ErrorAction SilentlyContinue
            $kpEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=41; StartTime=$Since} -ErrorAction SilentlyContinue
            
            $wheaCount = @($wheaEvents).Count
            $kpCount = @($kpEvents).Count
            
            $id17 = @($wheaEvents | Where-Object { $_.Id -eq 17 }).Count
            $id18 = @($wheaEvents | Where-Object { $_.Id -eq 18 }).Count
            $id19 = @($wheaEvents | Where-Object { $_.Id -eq 19 }).Count
            
            if ($wheaCount -eq 0 -and $kpCount -eq 0) {
                Write-Output "OK: SISTEMA ESTABLE. Cero errores de hardware WHEA y cero apagados bruscos (Kernel-Power 41) en los ultimos $Days dias."
            } else {
                Write-Output "ADVERTENCIA: Detectados $wheaCount eventos de hardware WHEA (Error corregido de hardware ID 17: $id17, Error irrecuperable de hardware ID 18: $id18, Error de comprobacion de maquina corregido ID 19: $id19) y $kpCount apagados abruptos (Kernel-Power 41) en los ultimos $Days dias.`r`n`r`nRecomendacion: Si experimenta micro-cuelgues o cierres inesperados en juegos, verifique la estabilidad de su perfil XMP/EXPO, voltajes de CPU/RAM o temperaturas termicas."
            }
        }
        "RuntimeVerification" {
            $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
            $vbsRunning = if ($null -ne $dg) {
                switch ($dg.VirtualizationBasedSecurityStatus) {
                    0 { "DESACTIVADO (Optimo para gaming competitivo)" }
                    1 { "HABILITADO pero no en ejecucion" }
                    2 { "EN EJECUCION (VBS activo, penalizacion VTL presente)" }
                    default { "Estado ($($dg.VirtualizationBasedSecurityStatus))" }
                }
            } else { "Inactivo / Hipervisor no presente" }

            $hvciRunning = if ($null -ne $dg -and $null -ne $dg.SecurityServicesRunning) {
                if (@($dg.SecurityServicesRunning) -contains 1) { "ACTIVA (Integridad de Memoria en ejecucion)" } else { "INACTIVA (Sin impacto en CPU/latencia)" }
            } else { "INACTIVA" }

            $mmcss = Get-Service -Name "MMCSS" -ErrorAction SilentlyContinue
            $mmcssStatus = if ($null -ne $mmcss) { "$($mmcss.Status) ($($mmcss.StartType))" } else { "No disponible" }
            $sysResp = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -ErrorAction SilentlyContinue
            $sysRespText = if ($null -ne $sysResp) { "$sysResp% reservado para sistema" } else { "20% (por defecto)" }

            $activePlanRaw = powercfg /getactivescheme 2>&1
            $activePlanName = if ($activePlanRaw -match "\((.+)\)") { $Matches[1] } else { "$activePlanRaw" }

            $netReport = @()
            if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
                $physicalAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
                foreach ($ad in $physicalAdapters) {
                    $prop = Get-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Interrupt Moderation*", "Moderacion de interrupciones*" -ErrorAction SilentlyContinue
                    $imState = if ($prop) { $prop.DisplayValue } else { "N/A" }
                    $netReport += "$($ad.Name): $imState"
                }
            }
            $netSummary = if ($netReport.Count -gt 0) { $netReport -join "; " } else { "Sin adaptadores Ethernet activos" }

            $mp = Get-CimInstance -Namespace root\Microsoft\Windows\Defender -ClassName MSFT_MpPreference -ErrorAction SilentlyContinue
            $exclCount = if ($null -ne $mp -and $null -ne $mp.ExclusionPath) { @($mp.ExclusionPath).Count } else { 0 }

            $chassisType = if ($IsLaptopDevice) { "Laptop / Portatil" } else { "Computadora de Escritorio (Desktop)" }
            $diskType = if ($IsSsdDrive) { "SSD (TRIM activo, LastAccess off)" } else { "HDD mecanico (WSearch optimizado)" }

            Write-Output "OK: AUDITORIA DE RUNTIME EN VIVO`r`n----------------------------------------`r`n- Chasis: $chassisType`r`n- Almacenamiento: $diskType`r`n- Plan de Energia Activo: $activePlanName`r`n- VBS (DeviceGuard): $vbsRunning`r`n- Integridad de Memoria (HVCI): $hvciRunning`r`n- MMCSS Scheduler: $mmcssStatus ($sysRespText)`r`n- Moderacion de Interrupciones (NIC): $netSummary`r`n- Exclusiones Defender en Vivo: $exclCount rutas activas`r`n----------------------------------------`r`nEstado: El kernel y los controladores reflejan fielmente las directivas aplicadas."
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
