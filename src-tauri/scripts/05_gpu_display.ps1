param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando inyecciones de Kernel para la GPU y optimización visual..."

    # 1. HAGS (Hardware-Accelerated GPU Scheduling)
    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (!(Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }
    Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value 2

    # 2. Destructor de MPO (Multi-Plane Overlay) - Elimina parpadeos y stutters
    Write-Host "[*] Destruyendo Multi-Plane Overlay (MPO) para la estabilidad del Frametime..."
    $MpoPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    if (!(Test-Path $MpoPath)) { New-Item -Path $MpoPath -Force | Out-Null }
    Set-ItemProperty -Path $MpoPath -Name "OverlayTestMode" -Type DWord -Value 5 -Force

    # 3. Forzar Modo Exclusivo de Pantalla Completa Global (FSO Bypass)
    Write-Host "[*] Forzando configuración avanzada de Pantalla Completa..."
    $FsoPath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $FsoPath)) { New-Item -Path $FsoPath -Force | Out-Null }
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2 -Force
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1 -Force
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior" -Type DWord -Value 2 -Force

    # 4. Erradicación total de GameBar y DVR nativos en segundo plano
    Write-Host "[*] Erradicando GameBar/DVR nativos del Registro..."
    $GameBarPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }
    Set-ItemProperty -Path $GameBarPath -Name "value" -Type DWord -Value 0 -Force

    # 5. Prioridad del Gestor de Ventanas (DWM) y Color Depth
    Write-Host "[*] Optimizando prioridad de procesamiento del DWM..."
    $DwmOptionsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"
    if (!(Test-Path $DwmOptionsPath)) { New-Item -Path $DwmOptionsPath -Force | Out-Null }
    Set-ItemProperty -Path $DwmOptionsPath -Name "CpuPriorityClass" -Type DWord -Value 6 -Force # Above Normal para evitar tirones de interfaz

    $DwmColorPath = "HKCU:\Software\Microsoft\Windows\DWM"
    if (!(Test-Path $DwmColorPath)) { New-Item -Path $DwmColorPath -Force | Out-Null }
    Set-ItemProperty -Path $DwmColorPath -Name "ColorPrevalence" -Type DWord -Value 0

    # 6. Optimización de Interfaz para Equipos de Gama Baja
    if ($RamGB -le 6) {
        Write-Host "    -> RAM Baja ($RamGB GB) detectada: Desactivando transparencias pesadas..."
        $ColorPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        If (-Not (Test-Path $ColorPath)) { New-Item -Path $ColorPath -Force | Out-Null }
        Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 0
    }

    # 7. Desactivación de Protección HDCP (Reduce latencia de transmisión GPU-Monitor)
    Write-Host "[*] Deshabilitando protección anticopia HDCP para reducir la latencia de video..."
    $DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    $Adapters = Get-ChildItem -Path $DisplayClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
    foreach ($Adapter in $Adapters) {
        New-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" -Value 1 -PropertyType DWORD -Force | Out-Null
    }

    Write-Host "[+] GPU optimizada, MPO destruido, HDCP deshabilitado y fluidez máxima asegurada."
    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo GPU: $_"
    exit 1
}