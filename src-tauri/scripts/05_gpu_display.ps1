param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    $HKCU_Path = $global:HKCU_Path
    Write-Host "[*] Aplicando optimizaciones visuales y calibración de GPU de Grado de Producción..."

    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    
    if (!(Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $HagsPath -ValueName "HwSchMode" -BackupSubFolder "GPU"
    }

    Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value 2 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $HagsPath -Name "HwSchMode" -ErrorAction SilentlyContinue) -ne 2) { throw "Fallo al verificar HwSchMode (HAGS)" }

    $GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $GameBarPath -ValueName "AllowGameDVR" -BackupSubFolder "GPU"
    }
    Set-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $GameBarPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo al asegurar la desactivacion de la directiva AllowGameDVR" }

    $UserGameDVRPath = "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    if (!(Test-Path $UserGameDVRPath)) { New-Item -Path $UserGameDVRPath -Force | Out-Null }
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $UserGameDVRPath -ValueName "AppCaptureEnabled" -BackupSubFolder "GPU"
    }
    Set-ItemProperty -Path $UserGameDVRPath -Name "AppCaptureEnabled" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $UserGameDVRPath -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo al asegurar la desactivacion de AppCaptureEnabled a nivel de usuario" }

    if ($RamGB -le 6) {
        $ColorPath = "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (!(Test-Path $ColorPath)) { New-Item -Path $ColorPath -Force | Out-Null }
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $ColorPath -ValueName "EnableTransparency" -BackupSubFolder "GPU"
        }
        Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 0 -Force | Out-Null
        if ((Get-ItemPropertyValue -Path $ColorPath -Name "EnableTransparency" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo de verificacion en EnableTransparency" }
    }

    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo GPU: $_"
    exit 1
}