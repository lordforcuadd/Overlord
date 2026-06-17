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
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "ClearPageFileAtShutdown" -BackupSubFolder "Performance"
        
        $StorePath = "HKCU:\System\GameConfigStore"
        if (Test-Path $StorePath) {
            Backup-OverlordRegistryValue -TargetKey $StorePath -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance"
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

    # Configurar temporizadores BCD (Desactivar HPET platform clock) con respaldo
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Performance"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }
    
    $BcdEnum = bcdedit /enum
    $OrigClock = if ($BcdEnum -match "useplatformclock\s+Yes") { "Yes" } elseif ($BcdEnum -match "useplatformclock\s+No") { "No" } else { "_ABSENT_" }
    
    if ((Get-ItemProperty -Path $BackupPath -Name "useplatformclock" -ErrorAction SilentlyContinue) -eq $null) {
        Set-ItemProperty -Path $BackupPath -Name "useplatformclock" -Value $OrigClock -Force | Out-Null
    }
    
    try {
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

    # Las mitigaciones de CPU Spectre/Meltdown se gestionan ahora a través del módulo independiente disableMitigations por seguridad.

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