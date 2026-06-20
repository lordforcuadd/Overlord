param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando optimizaciones de rendimiento general y Kernel..."

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        $StorePath = "HKCU:\System\GameConfigStore"
        if (Test-Path $StorePath) {
            Backup-OverlordRegistryValue -TargetKey $StorePath -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance"
        }
    }

    if ($RamGB -ge 32) {
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    } else {
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    }
    Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null

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
        if ((Get-ItemProperty -Path $GamesPath -Name "Scheduling Category")."Scheduling Category" -ne "High") { throw "Fallo de verificacion en MMCSS Scheduling Category" }
        if ((Get-ItemProperty -Path $GamesPath -Name "Priority").Priority -ne 6) { throw "Fallo de verificacion en MMCSS Priority" }
    }

    $StorePath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $StorePath)) { New-Item -Path $StorePath -Force | Out-Null }
    Set-ItemProperty -Path $StorePath -Name "GameDVR_Enabled" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemProperty -Path $StorePath -Name "GameDVR_Enabled").GameDVR_Enabled -ne 0) { 
        throw "Fallo de verificacion al intentar desactivar GameDVR_Enabled"
    }



    Write-Host "[+] Optimizaciones de Kernel inyectadas con exito."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Rendimiento: $_"
    exit 1
}