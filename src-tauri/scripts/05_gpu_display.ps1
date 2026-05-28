param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando optimizaciones visuales y calibración de GPU de Grado de Producción..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\GPU"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }
    
    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (!(Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }

    $OrigHags = (Get-ItemProperty -Path $HagsPath -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
    if ($OrigHags -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "HwSchMode" -ErrorAction SilentlyContinue) -eq $null) {
        Set-ItemProperty -Path $BackupPath -Name "HwSchMode" -Type DWord -Value $OrigHags -Force
    }

    $GpuDevices = Get-CimInstance Win32_VideoController
    $HasHighEndGpu = $false
    $GpuGen = "Desconocida"

    foreach ($Device in $GpuDevices) {
        if ($Device.Description -match "RTX [345]" -or $Device.Description -match "RX [6789]") {
            $HasHighEndGpu = $true
            $GpuGen = $Device.Description
            break
        }
    }

    if ($HasHighEndGpu) {
        Write-Host "    -> Hardware dedicado compatible detectado ($GpuGen): Activando HAGS (Modo 2)..."
        Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value 2 -Force
    } else {
        $FirstGpu = $GpuDevices | Select-Object -First 1
        $GpuGen = if ($FirstGpu) { $FirstGpu.Description } else { "Integrada/Antigua" }
        Write-Host "    -> Hardware integrado o básico detectado ($GpuGen): Preservando asignación nativa."
    }

    Write-Host "[*] Ajustando directivas globales de GameConfigStore..."
    $FsoPath = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $FsoPath)) { New-Item -Path $FsoPath -Force | Out-Null }
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2 -Force
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1 -Force
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior" -Type DWord -Value 2 -Force

    Write-Host "[*] Deshabilitando servicios invasivos de GameBar y DVR..."
    $GameBarPath = "HKLM:\SOFTWARE\Microsoft\Policies\Microsoft\Windows\GameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }
    Set-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" -Type DWord -Value 0 -Force

    $DwmOptionsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe"
    if (Test-Path "$DwmOptionsPath\PerfOptions") {
        Remove-Item -Path "$DwmOptionsPath\PerfOptions" -Recurse -Force | Out-Null
    }

    $DwmColorPath = "HKCU:\Software\Microsoft\Windows\DWM"
    if (!(Test-Path $DwmColorPath)) { New-Item -Path $DwmColorPath -Force | Out-Null }
    Set-ItemProperty -Path $DwmColorPath -Name "ColorPrevalence" -Type DWord -Value 0 -Force

    if ($RamGB -le 6) {
        Write-Host "    -> RAM Crítica ($RamGB GB) detectada: Apagando efectos de transparencia transicionales..."
        $ColorPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (!(Test-Path $ColorPath)) { New-Item -Path $ColorPath -Force | Out-Null }
        Set-ItemProperty -Path $ColorPath -Name "EnableTransparency" -Type DWord -Value 0 -Force
    }

    Write-Host "[*] Configurando baja latencia en adaptadores de video activos..."
    $HdcpBackupKey = "$BackupPath\HDCP"
    if (!(Test-Path $HdcpBackupKey)) { New-Item -Path $HdcpBackupKey -Force | Out-Null }

    $DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    $Adapters = Get-ChildItem -Path $DisplayClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
    
    foreach ($Adapter in $Adapters) {
        $AdapterID = $Adapter.PSChildName
        $OrigHdcp = (Get-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" -ErrorAction SilentlyContinue).RMHdcpKeyLocalZero
        
        if ($OrigHdcp -ne $null) { 
            Set-ItemProperty -Path $HdcpBackupKey -Name "Adapter_${AdapterID}_RMHdcpKeyLocalZero" -Value $OrigHdcp -Force 
        }
        
        
        Set-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" -Type DWord -Value 0 -Force
    } 

    Write-Host "[+] Subsistema gráfico estabilizado y prioridades normalizadas."
    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo GPU: $_"
    exit 1
}