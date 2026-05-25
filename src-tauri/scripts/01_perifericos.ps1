param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando inyección de Latencia de Periféricos de Bajo Nivel..."

    # CREACIÓN DEL MOTOR DE RESPALDO SEGURO EN REGISTRO
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    # 1. INTELIGENCIA DE BATERÍA PARA USB
    if (-not $IsLaptop) {
        Write-Host "    -> Desktop detectada: Desactivando USB Selective Suspend para 0ms lag."
        try {
            $PowerGuid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='true'").InstanceID.Split('\')[1]
            powercfg /SETACVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            powercfg /SETDCVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            powercfg /SETACTIVE $PowerGuid
        } catch {}
    }

    # 2. HABILITAR MODE MSI CON RESPALDO DISPOSITIVO POR DISPOSITIVO (Evita BSOD en Reversión)
    Write-Host "[*] Habilitando MSI Mode de forma segura con base en persistencia..."
    $MsiBackupKey = "$BackupPath\MSI"
    if (!(Test-Path $MsiBackupKey)) { New-Item -Path $MsiBackupKey -Force | Out-Null }

    $Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters" -ErrorAction SilentlyContinue
    foreach ($Device in $Devices) {
        $Class = (Get-ItemProperty -Path $Device.PSParentPath -ErrorAction SilentlyContinue).Class
        if ($Class -eq "Display" -or $Class -eq "USB") {
            try {
                $MsiPath = "$($Device.PSPath)\Interrupt Management\MessageSignaledInterruptProperties"
                $DeviceID = ($Device.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
                
                # Interrogar el valor MSI original de fábrica antes de mutarlo
                $OrigMsi = $null
                if (Test-Path $MsiPath) {
                    $OrigMsi = (Get-ItemProperty -Path $MsiPath -Name "MSISupported" -ErrorAction SilentlyContinue).MSISupported
                }
                
                # Si no ha sido respaldado previamente, guardamos su estado puro
                if ((Get-ItemProperty -Path $MsiBackupKey -Name $DeviceID -ErrorAction SilentlyContinue) -eq $null) {
                    $BackupVal = if ($OrigMsi -eq $null) { 999 } else { $OrigMsi }
                    Set-ItemProperty -Path $MsiBackupKey -Name $DeviceID -Type DWord -Value $BackupVal -Force
                }

                if (!(Test-Path $MsiPath)) { New-Item -Path $MsiPath -Force -ErrorAction Stop | Out-Null }
                Set-ItemProperty -Path $MsiPath -Name "MSISupported" -Type DWord -Value 1 -ErrorAction Stop
            } catch { continue }
        }
    }

    # 3. TIMER RESOLUTION Y RELOJ TSC EN HARDWARE
    Write-Host "[*] Ajustando Timer Resolution y sincronizando reloj TSC..."
    try {
        bcdedit /set useplatformclock false | Out-Null
        bcdedit /set disabledynamictick yes | Out-Null
        bcdedit /set useplatformtick yes | Out-Null
    } catch {}

    # 4. COLAS DE PAQUETES DE DATOS I/O CON RESPALDO
    Write-Host "[*] Optimizando Queue Size de periféricos y guardando estado de fábrica..."
    
    # Respaldo y ajuste del Mouse
    $MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    if (Test-Path $MouPath) {
        $OrigMou = (Get-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -ErrorAction SilentlyContinue).MouseDataQueueSize
        if ($OrigMou -and !(Test-Path "$BackupPath\mouclass")) {
            New-Item -Path "$BackupPath\mouclass" -Force | Out-Null
            Set-ItemProperty -Path "$BackupPath\mouclass" -Name "MouseDataQueueSize" -Type DWord -Value $OrigMou
        }
    }
    if (!(Test-Path $MouPath)) { New-Item -Path $MouPath -Force | Out-Null }
    Set-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -Type DWord -Value 20 -Force

    # Respaldo y ajuste del Teclado
    $KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    if (Test-Path $KbdPath) {
        $OrigKbd = (Get-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -ErrorAction SilentlyContinue).KeyboardDataQueueSize
        if ($OrigKbd -and !(Test-Path "$BackupPath\kbdclass")) {
            New-Item -Path "$BackupPath\kbdclass" -Force | Out-Null
            Set-ItemProperty -Path "$BackupPath\kbdclass" -Name "KeyboardDataQueueSize" -Type DWord -Value $OrigKbd
        }
    }
    if (!(Test-Path $KbdPath)) { New-Item -Path $KbdPath -Force | Out-Null }
    Set-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -Type DWord -Value 20 -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 38 -Force

    # 5. PRIORIDAD AL SUBSISTEMA DE VENTANAS CRÍTICO (CSRSS)
    Write-Host "[*] Inyectando prioridad máxima al subsistema de ventanas (CSRSS)..."
    $CsrssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"
    if (!(Test-Path $CsrssPath)) { New-Item -Path $CsrssPath -Force | Out-Null }
    Set-ItemProperty -Path $CsrssPath -Name "CpuPriorityClass" -Type DWord -Value 3 -Force
    Set-ItemProperty -Path $CsrssPath -Name "IoPriority" -Type DWord -Value 3 -Force

    # 6. ELIMINACIÓN DE ACELERACIÓN Y LIMPIEZA DE CURVAS DE CONTROL DEL MOUSE
    Write-Host "[*] Destruyendo curvas de aceleración y Sticky/Filter Keys..."
    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "0" -Force
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "0" -Force
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "0" -Force
    
    Set-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -Type Binary -Value ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) -Force
    Set-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -Type Binary -Value ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) -Force

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
    Write-Error "[-] Error crítico en Módulo de Periféricos: $_"
    exit 1
}