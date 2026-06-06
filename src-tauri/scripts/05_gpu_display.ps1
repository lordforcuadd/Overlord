param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando optimizaciones visuales y calibración de GPU de Grado de Producción..."

    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $DwmMpoPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    
    if (!(Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }
    if (!(Test-Path $DwmMpoPath)) { New-Item -Path $DwmMpoPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $HagsPath -ValueName "HwSchMode" -BackupSubFolder "GPU"
    }

    Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value 2 -Force | Out-Null
    if ((Get-ItemProperty -Path $HagsPath -Name "HwSchMode").HwSchMode -ne 2) { throw "Fallo al verificar HwSchMode (HAGS)" }

    

    $FsoPath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $FsoPath)) { New-Item -Path $FsoPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $FsoPath -ValueName "GameDVR_FSEBehaviorMode" -BackupSubFolder "GPU"
        Backup-OverlordRegistryValue -TargetKey $FsoPath -ValueName "GameDVR_HonorUserFSEBehaviorMode" -BackupSubFolder "GPU"
        Backup-OverlordRegistryValue -TargetKey $FsoPath -ValueName "GameDVR_FSEBehavior" -BackupSubFolder "GPU"
    }

    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2 -Force | Out-Null
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior" -Type DWord -Value 2 -Force | Out-Null

    if ((Get-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode").GameDVR_FSEBehaviorMode -ne 2) { throw "Fallo de verificacion en GameDVR_FSEBehaviorMode" }
    if ((Get-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode").GameDVR_HonorUserFSEBehaviorMode -ne 1) { throw "Fallo de verificacion en GameDVR_HonorUserFSEBehaviorMode" }
    if ((Get-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior").GameDVR_FSEBehavior -ne 2) { throw "Fallo de verificacion en GameDVR_FSEBehavior" }

    $GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $GameBarPath -ValueName "AllowGameDVR" -BackupSubFolder "GPU"
    }
    Set-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemProperty -Path $GameBarPath -Name "AllowGameDVR").AllowGameDVR -ne 0) { throw "Fallo al asegurar la desactivacion de la directiva AllowGameDVR" }

    $DwmColorPath = "HKCU:\Software\Microsoft\Windows\DWM"
    if (!(Test-Path $DwmColorPath)) { New-Item -Path $DwmColorPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $DwmColorPath -ValueName "ColorPrevalence" -BackupSubFolder "GPU"
    }
    Set-ItemProperty -Path $DwmColorPath -Name "ColorPrevalence" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemProperty -Path $DwmColorPath -Name "ColorPrevalence").ColorPrevalence -ne 0) { throw "Fallo de verificacion en ColorPrevalence" }

    if ($RamGB -le 6) {
        $ColorPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (!(Test-Path $ColorPath)) { New-Item -Path $ColorPath -Force | Out-Null }
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $ColorPath -ValueName "EnableTransparency" -BackupSubFolder "GPU"
        }
        Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 0 -Force | Out-Null
        if ((Get-ItemProperty -Path $ColorPath -Name "EnableTransparency").EnableTransparency -ne 0) { throw "Fallo de verificacion en EnableTransparency" }
    }

    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo GPU: $_"
    exit 1
}