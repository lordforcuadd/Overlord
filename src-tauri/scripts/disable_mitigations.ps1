$ErrorActionPreference = "Stop"

try {
    Write-Host "[*] Iniciando desactivacion de mitigaciones Spectre/Meltdown..."
    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if (!(Test-Path $MemPath)) { New-Item -Path $MemPath -Force | Out-Null }

    Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverride" -BackupSubFolder "Performance"
    Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverrideMask" -BackupSubFolder "Performance"

    # Magic Number 8259 (0x2043): Deshabilita mitigaciones de Spectre, Meltdown, SSBD y L1TF
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value 8259 -Force | Out-Null
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value 8259 -Force | Out-Null

    if ((Get-ItemPropertyValue -Path $MemPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue) -ne 8259) { 
        throw "Fallo al escribir FeatureSettingsOverride" 
    }
    if ((Get-ItemPropertyValue -Path $MemPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue) -ne 8259) { 
        throw "Fallo al escribir FeatureSettingsOverrideMask" 
    }

    Write-Host "[+] Mitigaciones Spectre/Meltdown deshabilitadas con exito."
    exit 0
} catch {
    Write-Error "[-] Error critico al desactivar mitigaciones de CPU: $_"
    exit 1
}
