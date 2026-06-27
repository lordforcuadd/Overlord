param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }
    Write-Host "[*] Aplicando optimizaciones de rendimiento general y Kernel..."

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        $StorePath = "$HKCU_Path\System\GameConfigStore"
        Backup-OverlordRegistryValue -TargetKey $StorePath -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance"
    }

    # Guardar backup de MMAgent de forma dinámica y configurar adaptativamente
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
            } else {
                Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
                Enable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null
            }
        }
    } catch {
        Write-Warning "No se pudo consultar o configurar MMAgent: $_"
    }

    # Las mitigaciones de CPU Spectre/Meltdown se gestionan ahora a través del módulo independiente disableMitigations por seguridad.

    $GamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (Test-Path $GamesPath) {
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "Scheduling Category" -BackupSubFolder "Performance"
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "SFIO Priority" -BackupSubFolder "Performance"
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "Priority" -BackupSubFolder "Performance"
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "GPU Priority" -BackupSubFolder "Performance"
            Backup-OverlordRegistryValue -TargetKey $GamesPath -ValueName "Clock Rate" -BackupSubFolder "Performance"
        }
        Set-ItemProperty -Path $GamesPath -Name "Scheduling Category" -Type String -Value "High" -Force | Out-Null
        Set-ItemProperty -Path $GamesPath -Name "SFIO Priority" -Type String -Value "High" -Force | Out-Null
        Set-ItemProperty -Path $GamesPath -Name "Priority" -Type DWord -Value 6 -Force | Out-Null
        Set-ItemProperty -Path $GamesPath -Name "GPU Priority" -Type DWord -Value 8 -Force | Out-Null
        Set-ItemProperty -Path $GamesPath -Name "Clock Rate" -Type DWord -Value 10 -Force | Out-Null

        # Verificación de MMCSS
        if ((Get-ItemPropertyValue -Path $GamesPath -Name "Scheduling Category" -ErrorAction SilentlyContinue) -ne "High") { throw "Fallo de verificacion en MMCSS Scheduling Category" }
        if ((Get-ItemPropertyValue -Path $GamesPath -Name "Priority" -ErrorAction SilentlyContinue) -ne 6) { throw "Fallo de verificacion en MMCSS Priority" }
    }

    $StorePath = "$HKCU_Path\System\GameConfigStore"
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