param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    $RunningOnBattery = $false
    if ($IsLaptop) {
        $BatteryStatus = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue
        if ($null -ne $BatteryStatus -and $BatteryStatus.PowerOnline -eq $false) {
            $RunningOnBattery = $true
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
                try { New-Item -Path $PerfBackupPath -Force -ErrorAction SilentlyContinue | Out-Null } catch {} 
            }
            
            if (Test-Path $PerfBackupPath) {
                $Agent = Get-MMAgent -ErrorAction SilentlyContinue
                if ($null -ne $Agent) {
                    $perfProps = Get-ItemProperty -Path $PerfBackupPath -ErrorAction SilentlyContinue
                    if ($null -eq $perfProps -or $null -eq $perfProps.PSObject.Properties["MemoryCompression"]) {
                        Set-ItemProperty -Path $PerfBackupPath -Name "MemoryCompression" -Value (if ($Agent.MemoryCompression) { 1 } else { 0 }) -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    if ($null -eq $perfProps -or $null -eq $perfProps.PSObject.Properties["PageCombining"]) {
                        Set-ItemProperty -Path $PerfBackupPath -Name "PageCombining" -Value (if ($Agent.PageCombining) { 1 } else { 0 }) -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }

            if ($RamGB -ge 32) {
                Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
                Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null
                $chkAgent = Get-MMAgent -ErrorAction SilentlyContinue
                if ($null -ne $chkAgent -and ($chkAgent.MemoryCompression -eq $true -or $chkAgent.PageCombining -eq $true)) { Write-Warning "El SO bloqueo la directiva MMAgent de compresion de RAM (posible politica de grupo o VM)" }
            } else {
                Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
                Enable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null
                $chkAgent = Get-MMAgent -ErrorAction SilentlyContinue
                if ($null -ne $chkAgent -and ($chkAgent.MemoryCompression -eq $false -or $chkAgent.PageCombining -eq $false)) { Write-Warning "El SO bloqueo la directiva MMAgent de compresion de RAM (posible politica de grupo o VM)" }
            }
        }
    } catch {
        Write-Warning "El SO bloqueo la comprobacion o configuracion de MMAgent: $_"
    }

    if (-not $RunningOnBattery) {
        Write-Host "    -> Configurando Core Parking 0% para estabilidad de FPS..."
        $ActivePlan = powercfg /getactivescheme 2>$null
        if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
            $CurrentGuid = $Matches[1]
            Backup-OverlordPowerSetting -SchemeGuid $CurrentGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "0cc5b647-c1df-4637-891a-dec35c318583" -BackupName "Power_${CurrentGuid}_0cc5b647-c1df-4637-891a-dec35c318583"
            Backup-OverlordPowerSetting -SchemeGuid $CurrentGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "ea062031-0e34-4ff1-9b6d-eb1059334028" -BackupName "Power_${CurrentGuid}_ea062031-0e34-4ff1-9b6d-eb1059334028"
            try { 
                & powercfg -setacvalueindex $CurrentGuid 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100 2>$null
                & powercfg -setacvalueindex $CurrentGuid 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 100 2>$null
                & powercfg -setactive $CurrentGuid 2>$null
            } catch {}
        }
    }

    Write-Host "    -> Desactivando Dynamic Tick (requiere reinicio)..."
    $bcdEnum = bcdedit /enum | Select-String "disabledynamictick.*Yes" -Quiet
    if (-not $bcdEnum) {
        $PerfBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Performance"
        if (!(Test-Path $PerfBackupPath)) { try { New-Item -Path $PerfBackupPath -Force -ErrorAction SilentlyContinue | Out-Null } catch {} }
        Set-ItemProperty -Path $PerfBackupPath -Name "DynamicTickWasDisabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
    }
    try { & bcdedit /set disabledynamictick yes 2>$null } catch {}

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
        $CLOCK_RATE_100_PERCENT = 10

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