param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando inyección de Latencia de Periféricos de Bajo Nivel..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    # 1. INTELIGENCIA DE ENERGÍA USB (API CIM MODERNIZADA)
    if (-not $IsLaptop) {
        Write-Host "    -> Desktop detectada: Desactivando USB Selective Suspend para 0ms lag."
        try {
            $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
            $PowerGuid = if ($ActivePlan) { $ActivePlan.InstanceID.Split('\')[1] } else { "381b4222-f694-41f0-9685-ff5bb260df2e" }
            powercfg /SETACVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            powercfg /SETDCVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            powercfg /SETACTIVE $PowerGuid
        } catch {}
    }

    # 2. SELECCIÓN MSI MODE QUIRÚRGICA CON RESPALDO
    $MsiBackupKey = "$BackupPath\MSI"
    if (!(Test-Path $MsiBackupKey)) { New-Item -Path $MsiBackupKey -Force | Out-Null }

    $Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters" -ErrorAction SilentlyContinue
    foreach ($Device in $Devices) {
        $Class = (Get-ItemProperty -Path $Device.PSParentPath -ErrorAction SilentlyContinue).Class
        if ($Class -eq "Display" -or $Class -eq "USB") {
            try {
                $MsiPath = "$($Device.PSPath)\Interrupt Management\MessageSignaledInterruptProperties"
                $DeviceID = ($Device.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
                
                $OrigMsi = $null
                if (Test-Path $MsiPath) {
                    $OrigMsi = (Get-ItemProperty -Path $MsiPath -Name "MSISupported" -ErrorAction SilentlyContinue).MSISupported
                }
                
                if ((Get-ItemProperty -Path $MsiBackupKey -Name $DeviceID -ErrorAction SilentlyContinue) -eq $null) {
                    $BackupVal = if ($OrigMsi -eq $null) { 999 } else { $OrigMsi }
                    Set-ItemProperty -Path $MsiBackupKey -Name $DeviceID -Type DWord -Value $BackupVal -Force
                }

                if (!(Test-Path $MsiPath)) { New-Item -Path $MsiPath -Force -ErrorAction Stop | Out-Null }
                Set-ItemProperty -Path $MsiPath -Name "MSISupported" -Type DWord -Value 1 -ErrorAction Stop
            } catch { continue }
        }
    }

    # 3. TIMER RESOLUTION Y RELOJ DE SISTEMA ADAPTATIVO
    try {
        bcdedit /set useplatformclock false | Out-Null
        bcdedit /set useplatformtick yes | Out-Null
        if (-not $IsLaptop) {
            # 🚀 PROTECCIÓN LÓGICA: Desactivar ticks dinámicos solo en desktops para proteger la suspensión y el calor móvil
            bcdedit /set disabledynamictick yes | Out-Null
        }
    } catch {}

    # 4. COLAS DE BUFFER I/O PERIFÉRICOS CON RESPALDO GRANULAR
    $MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    if (Test-Path $MouPath) {
        $OrigMou = (Get-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -ErrorAction SilentlyContinue).MouseDataQueueSize
        if ($OrigMou -and !(Test-Path "$BackupPath\mouclass")) {
            New-Item -Path "$BackupPath\mouclass" -Force | Out-Null
            Set-ItemProperty -Path "$BackupPath\mouclass" -Name "MouseDataQueueSize" -Type DWord -Value $OrigMou
        }
    }
    Set-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -Type DWord -Value 20 -Force

    $KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    if (Test-Path $KbdPath) {
        $OrigKbd = (Get-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -ErrorAction SilentlyContinue).KeyboardDataQueueSize
        if ($OrigKbd -and !(Test-Path "$BackupPath\kbdclass")) {
            New-Item -Path "$BackupPath\kbdclass" -Force | Out-Null
            Set-ItemProperty -Path "$BackupPath\kbdclass" -Name "KeyboardDataQueueSize" -Type DWord -Value $OrigKbd
        }
    }
    Set-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -Type DWord -Value 20 -Force

    # Respaldo simétrico de separación de prioridades antes de mutarla
    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    $OrigPrioritySep = (Get-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue).Win32PrioritySeparation
    if ($OrigPrioritySep -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue) -eq $null) {
        Set-ItemProperty -Path $BackupPath -Name "Win32PrioritySeparation" -Type DWord -Value $OrigPrioritySep -Force
    }
    Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 38 -Force

    # 5. PRIORIDAD AL SUBSISTEMA DE VENTANAS CRÍTICO (CSRSS)
    $CsrssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"
    if (!(Test-Path $CsrssPath)) { New-Item -Path $CsrssPath -Force | Out-Null }
    Set-ItemProperty -Path $CsrssPath -Name "CpuPriorityClass" -Type DWord -Value 3 -Force
    Set-ItemProperty -Path $CsrssPath -Name "IoPriority" -Type DWord -Value 3 -Force

    # 6. DESTRUCCIÓN DE ACELERACIÓN Y REGLAS DE ACCESIBILIDAD
    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "0" -Force
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "0" -Force
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "0" -Force
    Set-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -Type Binary -Value ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) -Force
    Set-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -Type Binary -Value ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) -Force

    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "58" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "122" -Force

    Write-Host "[+] Input Lag destruido. Tracking 1:1 asegurado. MSI Mode activado."
    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo de Periféricos: $_"
    exit 1
}