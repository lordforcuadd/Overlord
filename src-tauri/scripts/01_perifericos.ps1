param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando inyeccion de Latencia de Perifericos (Modulo 1)..."

    # 1. INTELIGENCIA DE BATERÍA PARA USB (Deshabilitar USB Selective Suspend)
    if (-not $IsLaptop) {
        Write-Host "    -> Desktop detectada: Desactivando USB Selective Suspend para 0ms lag."
        try {
            $PowerGuid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='true'").InstanceID.Split('\')[1]
            powercfg /SETACVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            powercfg /SETDCVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            powercfg /SETACTIVE $PowerGuid
        } catch { Write-Host "    [!] Advertencia: Perfil de energía bloqueado." }
    } else {
        Write-Host "    -> Laptop detectada: Saltando desvio de energía USB para proteger la bateria."
    }

    # 2. Habilitar MSI (Bucle Blindado contra Laptops)
    Write-Host "[*] Habilitando MSI Mode para GPU y USB..."
    $Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters" -ErrorAction SilentlyContinue
    foreach ($Device in $Devices) {
        $Class = (Get-ItemProperty -Path $Device.PSParentPath -ErrorAction SilentlyContinue).Class
        if ($Class -eq "Display" -or $Class -eq "USB") {
            try {
                $MsiPath = "$($Device.PSPath)\Interrupt Management\MessageSignaledInterruptProperties"
                if (!(Test-Path $MsiPath)) { New-Item -Path $MsiPath -Force -ErrorAction Stop | Out-Null }
                Set-ItemProperty -Path $MsiPath -Name "MSISupported" -Type DWord -Value 1 -ErrorAction Stop
            } catch {
                # Si el fabricante de la laptop bloquea este registro, lo ignoramos y seguimos
                continue 
            }
        }
    }


    Write-Host "[*] Ajustando Timer Resolution y destruyendo HPET..."
try {
    bcdedit /deletevalue useplatformclock | Out-Null
    bcdedit /deletevalue useplatformtick | Out-Null
    bcdedit /set disabledynamictick yes | Out-Null
} catch {
    Write-Host "    [!] BCDedit bloqueado por SecureBoot. Continuando..."
}

    # 4. Modificación extra: MouseDataQueueSize y Win32PrioritySeparation
    Write-Host "[*] Optimizando Queue Size de perifericos..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 20 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 20 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 38 -ErrorAction SilentlyContinue

    # 5. ACELERACIÓN DE RATÓN Y TECLAS ESPECIALES
    Write-Host "[*] Destruyendo Aceleracion de Raton y Sticky/Filter Keys..."
    
    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "0" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "0" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "0" -ErrorAction SilentlyContinue

    $StickyPath = "HKCU:\Control Panel\Accessibility\StickyKeys"
    if (!(Test-Path $StickyPath)) { New-Item -Path $StickyPath -Force | Out-Null }
    Set-ItemProperty -Path $StickyPath -Name "Flags" -Type String -Value "506"

    $TogglePath = "HKCU:\Control Panel\Accessibility\ToggleKeys"
    if (!(Test-Path $TogglePath)) { New-Item -Path $TogglePath -Force | Out-Null }
    Set-ItemProperty -Path $TogglePath -Name "Flags" -Type String -Value "58"

    $KeyboardRespPath = "HKCU:\Control Panel\Accessibility\Keyboard Response"
    if (!(Test-Path $KeyboardRespPath)) { New-Item -Path $KeyboardRespPath -Force | Out-Null }
    Set-ItemProperty -Path $KeyboardRespPath -Name "Flags" -Type String -Value "122"

    Write-Host "[+] Input Lag destruido. Tracking 1:1 asegurado. MSI Mode activado."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Periféricos: $_"
    exit 1
}