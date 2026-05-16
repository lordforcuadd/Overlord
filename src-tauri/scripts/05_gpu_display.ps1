param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Try {
    Write-Host "[*] Aplicando inyecciones de Kernel para la GPU..."

    # 1. HAGS (Hardware-Accelerated GPU Scheduling)
    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (!(Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }
    Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value 2

    # --- NUEVO: DESTRUCTOR DE MPO (Multi-Plane Overlay) ---
    Write-Host "[*] Destruyendo Multi-Plane Overlay (MPO) para estabilizar frametime..."
    $MpoPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    if (!(Test-Path $MpoPath)) { New-Item -Path $MpoPath -Force | Out-Null }
    Set-ItemProperty -Path $MpoPath -Name "OverlayTestMode" -Type DWord -Value 5 -Force

    # --- CORREGIDO: FULLSCREEN OPTIMIZATIONS (FSO) REALES ---
    Write-Host "[*] Forzando Modo Exclusivo de Pantalla Completa..."
    $FsoPath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $FsoPath)) { New-Item -Path $FsoPath -Force | Out-Null }
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2 -Force
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1 -Force
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior" -Type DWord -Value 2 -Force

    # 4. Prioridad DWM
    Write-Host "[*] Forzando prioridad GPU a High y ajustando Color Depth a 8-bit..."
    $DwmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"
    if (!(Test-Path $DwmPath)) { New-Item -Path $DwmPath -Force | Out-Null }
    Set-ItemProperty -Path $DwmPath -Name "CpuPriorityClass" -Type DWord -Value 3 

    $DwmColorPath = "HKCU:\Software\Microsoft\Windows\DWM"
    if (!(Test-Path $DwmColorPath)) { New-Item -Path $DwmColorPath -Force | Out-Null }
    Set-ItemProperty -Path $DwmColorPath -Name "ColorPrevalence" -Type DWord -Value 0

    # --- OPTIMIZACION DE GPU PARA GAMA BAJA ---
    if ($RamGB -le 6) {
        Write-Host "    -> RAM Baja ($RamGB GB) detectada: Apagando Transparencias (Mica/Acrylic)..."
        
        $ColorPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        If (-Not (Test-Path $ColorPath)) { New-Item -Path $ColorPath -Force | Out-Null }
        Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 0
    }

    # HDCP
    Write-Host "[*] Erradicando proteccion HDCP para reducir latencia de comunicacion GPU-Monitor..."
    $DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    $Adapters = Get-ChildItem -Path $DisplayClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
    
    foreach ($Adapter in $Adapters) {
        $Path = $Adapter.PSPath
        New-ItemProperty -Path $Path -Name "RMHdcpKeyLocalZero" -Value 1 -PropertyType DWORD -Force | Out-Null
    }

    Write-Host "[+] HAGS activado, MPO destruido, HDCP erradicado, FSO purgado."
    exit 0
} Catch {
    Write-Host "[-] Error critico en Modulo GPU: $_"
    exit 1
}