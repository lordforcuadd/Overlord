param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    $RunningOnBattery = $false
    if ($IsLaptop) {
        $BatteryStatus = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue
        if ($null -ne $BatteryStatus) {
            $HasAC = @($BatteryStatus | Where-Object { $_.PowerOnline -eq $true }).Count -gt 0
            $RunningOnBattery = -not $HasAC
        } else {
            # Fallback defensivo a Win32_Battery si root\wmi no esta disponible
            $Win32Bat = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
            if ($null -ne $Win32Bat) {
                $HasAC = @($Win32Bat | Where-Object { $_.BatteryStatus -ne 1 }).Count -gt 0
                $RunningOnBattery = -not $HasAC
            } else {
                # Postura fail-safe para laptops si no se puede determinar la alimentacion: no forzar Core Parking de AC
                $RunningOnBattery = $true
            }
        }
    }

    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }
    Write-Host "[*] Aplicando optimizaciones de rendimiento general y Kernel..."

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

    $StorePath = "$HKCU_Path\System\GameConfigStore"
    Backup-OverlordRegistryValue -TargetKey $StorePath -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance"

    # Guardar backup de MMAgent de forma dinamica y configurar adaptativamente
    try {
        if (Get-Command Get-MMAgent -ErrorAction SilentlyContinue) {
            $PerfBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Performance"
            if (!(Test-Path $PerfBackupPath)) { 
                try { New-Item -Path $PerfBackupPath -Force -ErrorAction SilentlyContinue | Out-Null } catch { Write-Verbose "Fallo al crear PerfBackupPath: $_" } 
            }
            
            if (Test-Path $PerfBackupPath) {
                $Agent = Get-MMAgent -ErrorAction SilentlyContinue
                if ($null -ne $Agent) {
                    $perfProps = Get-ItemProperty -Path $PerfBackupPath -ErrorAction SilentlyContinue
                    if ($null -eq $perfProps -or $null -eq $perfProps.PSObject.Properties["MemoryCompression"]) {
                        $memVal = if ($Agent.MemoryCompression) { 1 } else { 0 }
                        Set-ItemProperty -Path $PerfBackupPath -Name "MemoryCompression" -Value $memVal -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    if ($null -eq $perfProps -or $null -eq $perfProps.PSObject.Properties["PageCombining"]) {
                        $pageVal = if ($Agent.PageCombining) { 1 } else { 0 }
                        Set-ItemProperty -Path $PerfBackupPath -Name "PageCombining" -Value $pageVal -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }

            # Page Combining genera micro-stutters al escanear paginas duplicadas en RAM en segundo plano.
            # Se desactiva para reducir jitter en sistemas con suficiente memoria (> 8 GB).
            # En sistemas de 8 GB o menos, mantener PageCombining activo ahorra memoria fisica critica contra OOM.
            $EffectiveRamGB = if (Get-Variable -Name "RamGB" -Scope "global" -ErrorAction SilentlyContinue) { $global:RamGB } else { $RamGB }
            if ($EffectiveRamGB -le 8) {
                Enable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null
                Write-Host "    -> RAM <= 8 GB ($EffectiveRamGB GB): PageCombining mantenido/habilitado para conservar memoria fisica."
            } else {
                Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null
                Write-Host "    -> RAM > 8 GB ($EffectiveRamGB GB): PageCombining deshabilitado para erradicar jitter de escaneo en kernel."
            }
            Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
            $chkAgent = Get-MMAgent -ErrorAction SilentlyContinue
            if ($null -ne $chkAgent -and $chkAgent.PageCombining -eq $true -and $EffectiveRamGB -gt 8) { 
                Write-Warning "El SO bloqueo la directiva MMAgent de PageCombining (posible politica de grupo o VM)" 
            }
        }
    } catch {
        Write-Warning "El SO bloqueo la comprobacion o configuracion de MMAgent: $_"
    }

    if (-not $RunningOnBattery) {
        Write-Host "    -> Configurando Core Parking 0% para estabilidad de FPS..."
        $CurrentGuid = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes" -Name "ActivePowerScheme" -ErrorAction SilentlyContinue
        if ($null -eq $CurrentGuid -or $CurrentGuid -notmatch "^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$") {
            try {
                $rawScheme = & powercfg.exe /getactivescheme *>&1 | Out-String
                if ($rawScheme -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
                    $CurrentGuid = $Matches[1]
                }
            } catch { Write-Verbose "No se pudo obtener el esquema activo con powercfg: $_" }
        }
        if ($CurrentGuid -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
            Backup-OverlordPowerSetting -SchemeGuid $CurrentGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "0cc5b647-c1df-4637-891a-dec35c318583" -BackupName "Power_${CurrentGuid}_0cc5b647-c1df-4637-891a-dec35c318583"
            Backup-OverlordPowerSetting -SchemeGuid $CurrentGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "ea062031-0e34-4ff1-9b6d-eb1059334028" -BackupName "Power_${CurrentGuid}_ea062031-0e34-4ff1-9b6d-eb1059334028"
            try { 
                & powercfg.exe -setacvalueindex $CurrentGuid 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100 *>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "powercfg -setacvalueindex 0cc5b647 fallo con codigo $LASTEXITCODE" }
                & powercfg.exe -setacvalueindex $CurrentGuid 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 100 *>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "powercfg -setacvalueindex ea062031 fallo con codigo $LASTEXITCODE" }
                & powercfg.exe -setactive $CurrentGuid *>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "powercfg -setactive fallo con codigo $LASTEXITCODE" }
            } catch { Write-Verbose "Fallo al reactivar esquema de energia: $_" }
        }
    }


    # Las mitigaciones de CPU Spectre/Meltdown se gestionan ahora a traves del modulo independiente disableMitigations por seguridad.

    $GamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (Test-Path $GamesPath) {
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "Scheduling Category" -BackupSubFolder "Performance"
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "SFIO Priority" -BackupSubFolder "Performance"
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "Priority" -BackupSubFolder "Performance"
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "GPU Priority" -BackupSubFolder "Performance"
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "Clock Rate" -BackupSubFolder "Performance"
        Set-ItemProperty -Path $GamesPath -Name "Scheduling Category" -Type String -Value "High" -Force | Out-Null
        Set-ItemProperty -Path $GamesPath -Name "SFIO Priority" -Type String -Value "High" -Force | Out-Null
        $PRIORITY_HIGH_6 = 6
        $GPU_PRIORITY_8 = 8
        $CLOCK_RATE_100_PERCENT = 10000

        Set-ItemProperty -Path $GamesPath -Name "Priority" -Type DWord -Value $PRIORITY_HIGH_6 -Force | Out-Null
        Set-ItemProperty -Path $GamesPath -Name "GPU Priority" -Type DWord -Value $GPU_PRIORITY_8 -Force | Out-Null
        Set-ItemProperty -Path $GamesPath -Name "Clock Rate" -Type DWord -Value $CLOCK_RATE_100_PERCENT -Force | Out-Null

        # Verificacion de MMCSS
        if ((Get-ItemPropertyValue -Path $GamesPath -Name "Scheduling Category" -ErrorAction SilentlyContinue) -ne "High") { throw "Fallo de verificacion en MMCSS Scheduling Category" }
        if ((Get-ItemPropertyValue -Path $GamesPath -Name "Priority" -ErrorAction SilentlyContinue) -ne $PRIORITY_HIGH_6) { throw "Fallo de verificacion en MMCSS Priority" }
    }

    if (!(Test-Path $StorePath)) { New-Item -Path $StorePath -Force | Out-Null }
    Set-ItemProperty -Path $StorePath -Name "GameDVR_Enabled" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $StorePath -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue) -ne 0) { 
        throw "Fallo de verificacion al intentar desactivar GameDVR_Enabled"
    }



    Write-Host "[+] Optimizaciones de Kernel inyectadas con exito."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Rendimiento: $_"
    exit 1
}