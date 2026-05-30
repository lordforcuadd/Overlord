param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

$BackupManagerPath = Join-Path $PSScriptRoot "backup_manager.psm1"
if (Test-Path $BackupManagerPath) {
    Import-Module $BackupManagerPath -Force
}

Try {
    Write-Host "[*] Aplicando optimizaciones de rendimiento general y Kernel..."

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "DisablePagingExecutive" -BackupSubFolder "Performance"
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverride" -BackupSubFolder "Performance"
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverrideMask" -BackupSubFolder "Performance"
        
        $StorePath = "HKCU:\System\GameConfigStore"
        if (Test-Path $StorePath) {
            Backup-OverlordRegistryValue -TargetKey $StorePath -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance"
        }
        
        $FthPath = "HKLM:\Software\Microsoft\FTH"
        if (Test-Path $FthPath) {
            Backup-OverlordRegistryValue -TargetKey $FthPath -ValueName "Enabled" -BackupSubFolder "Performance"
        }
    }

    if ($RamGB -ge 16 -and -not $IsLaptop) {
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 1 -Force
    } else {
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 0 -Force
    }

    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue

    if (-not $IsLaptop) {
        Write-Host "[!] ADVERTENCIA: Desactivando mitigaciones estructurales Spectre/Meltdown para maximizar throughput." -ForegroundColor Yellow
        Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value 3 -Force
        Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value 3 -Force
    }

    $StorePath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $StorePath)) { New-Item -Path $StorePath -Force | Out-Null }
    Set-ItemProperty -Path $StorePath -Name "GameDVR_Enabled" -Type DWord -Value 0 -Force

    if (-not $IsLaptop -and $RamGB -ge 16) {
        $FthPath = "HKLM:\Software\Microsoft\FTH"
        if (!(Test-Path $FthPath)) { New-Item -Path $FthPath -Force | Out-Null }
        Set-ItemProperty -Path $FthPath -Name "Enabled" -Type DWord -Value 0 -Force
    }

    Write-Host "[+] Optimizaciones de Kernel inyectadas con exito."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Rendimiento: $_"
    exit 1
}