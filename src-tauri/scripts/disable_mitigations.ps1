$ErrorActionPreference = "Stop"

try {
    Write-Host "[*] Iniciando desactivacion de mitigaciones Spectre/Meltdown..."
    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if (!(Test-Path $MemPath)) { New-Item -Path $MemPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverride" -BackupSubFolder "Performance"
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverrideMask" -BackupSubFolder "Performance"
    }

    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value 3 -Force | Out-Null
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value 3 -Force | Out-Null

    if ((Get-ItemPropertyValue -Path $MemPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue) -ne 3) { 
        throw "Fallo al escribir FeatureSettingsOverride" 
    }
    if ((Get-ItemPropertyValue -Path $MemPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue) -ne 3) { 
        throw "Fallo al escribir FeatureSettingsOverrideMask" 
    }

    Write-Host "[+] Mitigaciones Spectre/Meltdown deshabilitadas con exito."
    exit 0
} catch {
    Write-Error "[-] Error critico al desactivar mitigaciones de CPU: $_"
    exit 1
}
