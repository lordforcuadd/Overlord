$ErrorActionPreference = "Stop"

try {
    $isArm = $false
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($null -ne $os -and $os.OSArchitecture -match "(?i)ARM") {
            $isArm = $true
        }
    } catch {
        Write-Verbose "Fallo al consultar arquitectura via CIM: $_"
    }
    if (-not $isArm) {
        $Arch = $env:PROCESSOR_ARCHITECTURE
        $ArchW64 = $env:PROCESSOR_ARCHITEW6432
        if ($Arch -eq "ARM64" -or $ArchW64 -eq "ARM64") {
            $isArm = $true
        }
    }
    if ($isArm) {
        Write-Host "[+] Procesador ARM64 detectado. Las mitigaciones Spectre/Meltdown de x86 no aplican en esta arquitectura."
        exit 0
    }

    Write-Host "[*] Iniciando desactivacion de mitigaciones Spectre/Meltdown..."
    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if (!(Test-Path $MemPath)) { New-Item -Path $MemPath -Force | Out-Null }

    Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverride" -BackupSubFolder "Performance"
    Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverrideMask" -BackupSubFolder "Performance"

    # Constante oficial Microsoft: 8259 (0x2043) deshabilita mitigaciones Spectre v2, Meltdown, SSBD y L1TF
    # La mascara oficial de Microsoft es 3 (bits 0 y 1 para Spectre v2 y Meltdown)
    $SPECTRE_MELTDOWN_DISABLE_FLAGS = 8259
    $SPECTRE_MELTDOWN_MASK = 3
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value $SPECTRE_MELTDOWN_DISABLE_FLAGS -Force | Out-Null
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value $SPECTRE_MELTDOWN_MASK -Force | Out-Null

    if ((Get-ItemPropertyValue -Path $MemPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue) -ne $SPECTRE_MELTDOWN_DISABLE_FLAGS) { 
        throw "Fallo al escribir FeatureSettingsOverride" 
    }
    if ((Get-ItemPropertyValue -Path $MemPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue) -ne $SPECTRE_MELTDOWN_MASK) { 
        throw "Fallo al escribir FeatureSettingsOverrideMask" 
    }

    Write-Host "[+] Mitigaciones Spectre/Meltdown deshabilitadas con exito."
    exit 0
} catch {
    Write-Error "[-] Error critico al desactivar mitigaciones de CPU: $_"
    exit 1
}
