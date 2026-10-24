$ErrorActionPreference = "Stop"

try {
    Write-Host "[*] Iniciando protocolo de desactivacion de VBS (Virtualization-Based Security) y HVCI (Integridad de Memoria)..."

    $DeviceGuardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    $HvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

    if (!(Test-Path $DeviceGuardPath)) { New-Item -Path $DeviceGuardPath -Force | Out-Null }
    if (!(Test-Path $HvciPath)) { New-Item -Path $HvciPath -Force | Out-Null }

    # Respaldo 1:1 de los valores de seguridad previos
    Backup-OverlordRegistryValue -TargetKey $DeviceGuardPath -ValueName "EnableVirtualizationBasedSecurity" -BackupSubFolder "Security\VBS"
    Backup-OverlordRegistryValue -TargetKey $DeviceGuardPath -ValueName "RequirePlatformSecurityFeatures" -BackupSubFolder "Security\VBS"
    Backup-OverlordRegistryValue -TargetKey $HvciPath -ValueName "Enabled" -BackupSubFolder "Security\VBS"

    # Desactivar VBS y requerimientos de plataforma
    Set-ItemProperty -Path $DeviceGuardPath -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $DeviceGuardPath -Name "RequirePlatformSecurityFeatures" -Type DWord -Value 0 -Force | Out-Null

    # Desactivar HVCI (Hypervisor-Enforced Code Integrity / Integridad de Memoria)
    Set-ItemProperty -Path $HvciPath -Name "Enabled" -Type DWord -Value 0 -Force | Out-Null

    # Verificacion estricta de escritura
    $chkVbs = Get-ItemPropertyValue -Path $DeviceGuardPath -Name "EnableVirtualizationBasedSecurity" -ErrorAction SilentlyContinue
    $chkHvci = Get-ItemPropertyValue -Path $HvciPath -Name "Enabled" -ErrorAction SilentlyContinue

    if ($chkVbs -ne 0) { throw "Fallo al verificar EnableVirtualizationBasedSecurity en 0" }
    if ($chkHvci -ne 0) { throw "Fallo al verificar HypervisorEnforcedCodeIntegrity\Enabled en 0" }

    Write-Host "[+] VBS y HVCI deshabilitados con exito. (Se requiere reiniciar el sistema para que el hipervisor de Windows libere los recursos)."
    exit 0
} catch {
    Write-Error "[-] Error critico al desactivar VBS/HVCI: $_"
    exit 1
}
