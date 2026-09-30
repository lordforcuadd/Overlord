param(
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }
    Write-Host "[*] Aplicando optimizaciones visuales y calibración de GPU de Grado de Producción..."

    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (!(Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }

    # Validar soporte WDDM >= 2.7 (introducido en Windows Build 19041) para evitar pantallas negras en GPU legacy
    $BuildNum = [int](Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuild" -ErrorAction SilentlyContinue)
    $WddmSupported = $false
    
    if ($BuildNum -ge 19041) {
        $ExistingHwSchMode = Get-ItemProperty -Path $HagsPath -Name "HwSchMode" -ErrorAction SilentlyContinue
        if ($null -ne $ExistingHwSchMode -and $null -ne $ExistingHwSchMode.HwSchMode) {
            $WddmSupported = $true
        } else {
            $Controllers = if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
            } elseif (Get-Command Get-WmiObject -ErrorAction SilentlyContinue) {
                Get-WmiObject Win32_VideoController -ErrorAction SilentlyContinue
            } else {
                $null
            }

            if ($null -ne $Controllers) {
                foreach ($Controller in $Controllers) {
                    if ($Controller.PNPDeviceID -match "ROOT\\|VMBUS\\|PCI\\VEN_1AF4|PCI\\VEN_1B36|PCI\\VEN_15AD|PCI\\VEN_80EE") { continue }
                    $Name = if ($Controller.Name) { $Controller.Name } else { "" }
                    # Descartar GPUs legacy que reportan drivers >= 27 pero no tienen hardware HAGS (evita pantalla negra)
                    if ($Name -match "HD Graphics|UHD Graphics\s*(6[0-9]{2}|G[0-9])|Iris Plus" -and $Name -notmatch "Arc") { continue }
                    if ($Name -match "\bRX\s*[45][0-9]{2}\b|Vega" -and $Name -notmatch "RX\s*5[0-9]{3}") { continue }
                    if ($Name -match "GTX\s*[6789][0-9]{2}|GT\s*[678][0-9]{2}|Quadro\s*[KM][0-9]{3,4}") { continue }

                    $DriverVer = $Controller.DriverVersion
                    # El formato DCH de drivers (NVIDIA/AMD/Intel) mapea el WDDM major en el primer segmento
                    if ($DriverVer -and $DriverVer -match "^(\d+)\.") {
                        if ([int]$Matches[1] -ge 27) {
                            $WddmSupported = $true
                            break
                        }
                    }
                }
            }
        }
    }

    if ($WddmSupported) {
        Backup-OverlordRegistryValue -TargetKey $HagsPath -ValueName "HwSchMode" -BackupSubFolder "GPU"
        Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value 2 -Force | Out-Null
        if ((Get-ItemPropertyValue -Path $HagsPath -Name "HwSchMode" -ErrorAction SilentlyContinue) -ne 2) { throw "Fallo al verificar HwSchMode (HAGS)" }
    } else {
        Write-Warning "HAGS no es compatible con el hardware o driver grafico actual. Saltando optimizacion para evitar pantallas negras."
    }

    $GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }

    Backup-OverlordRegistryValue -TargetKey $GameBarPath -ValueName "AllowGameDVR" -BackupSubFolder "GPU"
    Set-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $GameBarPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo al asegurar la desactivacion de la directiva AllowGameDVR" }

    $UserGameDVRPath = "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    if (!(Test-Path $UserGameDVRPath)) { New-Item -Path $UserGameDVRPath -Force | Out-Null }
    Backup-OverlordRegistryValue -TargetKey $UserGameDVRPath -ValueName "AppCaptureEnabled" -BackupSubFolder "GPU"
    Set-ItemProperty -Path $UserGameDVRPath -Name "AppCaptureEnabled" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $UserGameDVRPath -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo al asegurar la desactivacion de AppCaptureEnabled a nivel de usuario" }

    if ($RamGB -le 6) {
        $ColorPath = "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (!(Test-Path $ColorPath)) { New-Item -Path $ColorPath -Force | Out-Null }
        Backup-OverlordRegistryValue -TargetKey $ColorPath -ValueName "EnableTransparency" -BackupSubFolder "GPU"
        Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 0 -Force | Out-Null
        if ((Get-ItemPropertyValue -Path $ColorPath -Name "EnableTransparency" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo de verificacion en EnableTransparency" }
    }

    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo GPU: $_"
    exit 1
}
