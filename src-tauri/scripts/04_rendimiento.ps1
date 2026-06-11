param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando optimizaciones de rendimiento general y Kernel..."

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    
    $ControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control"

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "DisablePagingExecutive" -BackupSubFolder "Performance"
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverride" -BackupSubFolder "Performance"
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "FeatureSettingsOverrideMask" -BackupSubFolder "Performance"
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "ClearPageFileAtShutdown" -BackupSubFolder "Performance"
        Backup-OverlordRegistryValue -TargetKey $ControlPath -ValueName "SvcHostSplitThresholdInKB" -BackupSubFolder "Performance"
        
        $StorePath = "HKCU:\System\GameConfigStore"
        if (Test-Path $StorePath) {
            Backup-OverlordRegistryValue -TargetKey $StorePath -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance"
        }
        
        $FthPath = "HKLM:\Software\Microsoft\FTH"
        if (Test-Path $FthPath) {
            Backup-OverlordRegistryValue -TargetKey $FthPath -ValueName "Enabled" -BackupSubFolder "Performance"
        }
    }

    $targetPaging = 0
    if ($RamGB -ge 16 -and -not $IsLaptop) {
        $targetPaging = 1
    }
    Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value $targetPaging -Force | Out-Null
    if ((Get-ItemProperty -Path $MemPath -Name "DisablePagingExecutive").DisablePagingExecutive -ne $targetPaging) { 
        throw "Fallo al verificar DisablePagingExecutive en el Kernel"
    }

    # Dynamic SvcHost split threshold: RAM in KB
    $SplitThreshold = $RamGB * 1024 * 1024
    Set-ItemProperty -Path $ControlPath -Name "SvcHostSplitThresholdInKB" -Type DWord -Value $SplitThreshold -Force | Out-Null
    if ((Get-ItemProperty -Path $ControlPath -Name "SvcHostSplitThresholdInKB").SvcHostSplitThresholdInKB -ne $SplitThreshold) {
        Write-Warning "No se pudo asegurar SvcHostSplitThresholdInKB"
    }

    # Configurar temporizadores BCD (Desactivar HPET platform clock y Dynamic Ticks)
    try {
        bcdedit /set disabledynamictick yes 2>$null | Out-Null
        bcdedit /set useplatformclock no 2>$null | Out-Null
    } catch {}

    $ClearPage = (Get-ItemProperty -Path $MemPath -Name "ClearPageFileAtShutdown" -ErrorAction SilentlyContinue).ClearPageFileAtShutdown
    if ($ClearPage -eq 1) {
        Set-ItemProperty -Path $MemPath -Name "ClearPageFileAtShutdown" -Type DWord -Value 0 -Force | Out-Null
        if ((Get-ItemProperty -Path $MemPath -Name "ClearPageFileAtShutdown").ClearPageFileAtShutdown -ne 0) { 
            throw "Fallo al asegurar el flag ClearPageFileAtShutdown en 0"
        }
    }

    if ($RamGB -ge 32) {
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    } else {
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    }
    Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null

    if (-not $IsLaptop) {
        $CPUName = ""
        try {
            $CPUName = (Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" -ErrorAction SilentlyContinue).ProcessorNameString
        } catch {}

        $IsModernCPU = $false
        if (![string]::IsNullOrWhiteSpace($CPUName)) {
            if ($CPUName -like "*Intel*") {
                if ($CPUName -match "i[3579]-(1\d{4})") { 
                    $IsModernCPU = $true 
                } elseif ($CPUName -like "*Ultra*") { 
                    $IsModernCPU = $true 
                }
            } elseif ($CPUName -like "*AMD*") {
                if ($CPUName -match "Ryzen [3579]\s+([5789]\d{3})") { 
                    $IsModernCPU = $true 
                }
            }
        }

        if ($IsModernCPU) {
            Write-Host "[+] Procesador moderno detectado ($CPUName). Las mitigaciones de seguridad ya vienen integradas de fábrica en el silicio. Saltando tweak para mantener protecciones intactas sin pérdida de throughput." -ForegroundColor Green
        } else {
            Write-Host "[!] Procesador legacy detectado o no identificado ($CPUName). Desactivando mitigaciones estructurales Spectre/Meltdown para maximizar ciclos por segundo." -ForegroundColor Yellow
            Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value 3 -Force | Out-Null
            Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value 3 -Force | Out-Null
            
            if ((Get-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride").FeatureSettingsOverride -ne 3) { throw "Fallo de escritura en FeatureSettingsOverride (Spectre/Meltdown)" }
            if ((Get-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask").FeatureSettingsOverrideMask -ne 3) { throw "Fallo de escritura en FeatureSettingsOverrideMask (Spectre/Meltdown)" }
        }
    }

    $StorePath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $StorePath)) { New-Item -Path $StorePath -Force | Out-Null }
    Set-ItemProperty -Path $StorePath -Name "GameDVR_Enabled" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemProperty -Path $StorePath -Name "GameDVR_Enabled").GameDVR_Enabled -ne 0) { 
        throw "Fallo de verificacion al intentar desactivar GameDVR_Enabled"
    }

    if (-not $IsLaptop -and $RamGB -ge 16) {
        $FthPath = "HKLM:\Software\Microsoft\FTH"
        if (!(Test-Path $FthPath)) { New-Item -Path $FthPath -Force | Out-Null }
        Set-ItemProperty -Path $FthPath -Name "Enabled" -Type DWord -Value 0 -Force | Out-Null
        if ((Get-ItemProperty -Path $FthPath -Name "Enabled").Enabled -ne 0) { 
            throw "Fallo al asegurar el flag de desactivacion del servicio FTH"
        }
    }

    Write-Host "[+] Optimizaciones de Kernel inyectadas con exito."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Rendimiento: $_"
    exit 1
}