param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Optimizando rendimiento del sistema..."

    $UltimatePlan = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    $PlanGUID = $UltimatePlan -match "([a-f0-9\-]{36})" | Out-Null
    $PlanGUID = $Matches[1]
    powercfg -setactive $PlanGUID

    $GameDVRPath = "HKCU:\System\GameConfigStore"
    Set-ItemProperty -Path $GameDVRPath -Name "GameDVR_Enabled" -Type DWord -Value 0
    $GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }
    Set-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" -Type DWord -Value 0

    Write-Host "[*] Limpiando Cache Dinamica de Windows..."
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue

    Write-Host "[*] Evaluando Inteligencia de RAM..."
    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if ($RamGB -ge 16) {
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 1
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    } else {
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 0
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    }

    # --- INTELIGENCIA LOW-END (NUEVO) ---
    if ($RamGB -le 6) {
        Write-Host "    -> RAM Baja ($RamGB GB) detectada: Activando Protocolo Low-End..."
        
        # 1. Arranque Ultrarrapido
        bcdedit /timeout 3 | Out-Null
        bcdedit /set quietboot on | Out-Null
        bcdedit /set bootux disabled | Out-Null
        bcdedit /set numproc $env:NUMBER_OF_PROCESSORS | Out-Null

        # 2. Asesinato de Servicios Asfixiantes
        Stop-Service -Name WSearch -Force -Confirm:$false -ErrorAction SilentlyContinue
        Set-Service -Name WSearch -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name MapsBroker -Force -Confirm:$false -ErrorAction SilentlyContinue
        Set-Service -Name MapsBroker -StartupType Disabled -ErrorAction SilentlyContinue

        # 4. Modo Maximo Rendimiento Visual (Mata las animaciones pesadas)
        $VisualFxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        If (-Not (Test-Path $VisualFxPath)) { New-Item -Path $VisualFxPath -Force | Out-Null }
        Set-ItemProperty -Path $VisualFxPath -Name "VisualFXSetting" -Type DWord -Value 2
    }

    Write-Host "[*] Bajando el consumo al motor de Windows Defender..."
    Set-MpPreference -ScanAvgCPULoadFactor 25 -ErrorAction SilentlyContinue

    Write-Host "[+] Plan Ultimate activado, Defender domado y Rendimiento ajustado."
    
    Write-Host "[*] Destruyendo el Fault Tolerant Heap (FTH) para evitar estrangulamiento de FPS..."
    $FthPath = "HKLM:\Software\Microsoft\FTH"
    if (!(Test-Path $FthPath)) { New-Item -Path $FthPath -Force | Out-Null }
    Set-ItemProperty -Path $FthPath -Name "Enabled" -Type DWord -Value 0 -Force
    exit 0

} Catch {
    # Cambiado a Write-Host para no romper el flujo
    Write-Host "[-] Error en Rendimiento General: $_"
    exit 1
}
