param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Try {
    Write-Host "[*] Aplicando inyecciones de Kernel para la GPU..."

    # 1. HAGS (Hardware-Accelerated GPU Scheduling)
    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (!(Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }
    Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value 2

    # 2. Destructor de MPO (Multi-Plane Overlay)
    Write-Host "[*] Destruyendo Multi-Plane Overlay (MPO) para estabilizar frametime..."
    $MpoPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    if (!(Test-Path $MpoPath)) { New-Item -Path $MpoPath -Force | Out-Null }
    Set-ItemProperty -Path $MpoPath -Name "OverlayTestMode" -Type DWord -Value 5 -Force

    # 3. Optimización de Pantalla Completa (FSO) - Recuperado de tu código
    Write-Host "[*] Forzando Modo Exclusivo de Pantalla Completa..."
    $FsoPath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $FsoPath)) { New-Item -Path $FsoPath -Force | Out-Null }
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2 -Force
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1 -Force
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior" -Type DWord -Value 2 -Force

    # 4. Erradicando GameBar/DVR nativos globalmente
    Write-Host "[*] Erradicando GameBar/DVR Nativos del Registro..."
    $GameBarPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }
    Set-ItemProperty -Path $GameBarPath -Name "value" -Type DWord -Value 0 -Force

    # 5. Prioridad DWM (Corregida a 6 para evitar stutters) y Color Depth
    Write-Host "[*] Ajustando prioridad de DWM de forma segura (Above Normal) y Color..."
    $DwmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"
    if (!(Test-Path $DwmPath)) { New-Item -Path $DwmPath -Force | Out-Null }
    Set-ItemProperty -Path $DwmPath -Name "CpuPriorityClass" -Type DWord -Value 6 -Force 

    $DwmColorPath = "HKCU:\Software\Microsoft\Windows\DWM"
    if (!(Test-Path $DwmColorPath)) { New-Item -Path $DwmColorPath -Force | Out-Null }
    Set-ItemProperty -Path $DwmColorPath -Name "ColorPrevalence" -Type DWord -Value 0

    # 6. Optimizacion GPU Gama Baja - Recuperado de tu código
    if ($RamGB -le 6) {
        Write-Host "    -> RAM Baja ($RamGB GB) detectada: Apagando Transparencias (Mica/Acrylic)..."
        
        $ColorPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        If (-Not (Test-Path $ColorPath)) { New-Item -Path $ColorPath -Force | Out-Null }
        Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 0
    }

    # 7. HDCP
    Write-Host "[*] Erradicando proteccion HDCP para reducir latencia GPU-Monitor..."
    $DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    $Adapters = Get-ChildItem -Path $DisplayClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
    
    foreach ($Adapter in $Adapters) {
        New-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" -Value 1 -PropertyType DWORD -Force | Out-Null
    }

    Write-Host "[+] HAGS activado, MPO destruido, HDCP erradicado, FSO purgado."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo GPU: $_"
    exit 1
}