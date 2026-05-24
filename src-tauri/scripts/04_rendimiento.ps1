param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Optimizando rendimiento del sistema y potencia de hilos..."

    # 1. PLAN DE ENERGÍA DE RENDIMIENTO MÁXIMO DEFINITIVO
    $UltimatePlan = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    $PlanGUID = $UltimatePlan -match "([a-f0-9\-]{36})" | Out-Null
    $PlanGUID = $Matches[1]
    powercfg -setactive $PlanGUID

    # 2. RESTRICCIÓN DE CAPTURAS EN SEGUNDO PLANO GAME DVR
    $GameDVRPath = "HKCU:\System\GameConfigStore"
    Set-ItemProperty -Path $GameDVRPath -Name "GameDVR_Enabled" -Type DWord -Value 0
    $GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }
    Set-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" -Type DWord -Value 0

    # 3. PURGA COMPLETA DE CACHÉS VOLÁTILES DE ALTA VELOCIDAD
    Write-Host "[*] Limpiando Caché Dinámica de Windows..."
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue

    # 4. GESTIÓN INTELIGENTE DE EJECUCIÓN DE PÁGINAS DE MEMORIA CORRIENDO EN RAM
    Write-Host "[*] Evaluando Inteligencia de RAM..."
    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if ($RamGB -ge 16) {
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 1
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    } else {
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 0
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    }

    # 5. REMOCIÓN COMPLETA DE LAS MITIGACIONES DE CPU (Spectre y Meltdown Bypass)
    Write-Host "[*] Removiendo parches de mitigación Spectre/Meltdown para máxima potencia de IPC..."
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value 3 -Force
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value 3 -Force

    # 6. PROTOCOLO INTELIGENTE BAJA GAMA PARA EQUIPOS COMPROMETIDOS
    if ($RamGB -le 6) {
        Write-Host "    -> RAM Baja ($RamGB GB) detectada: Activando Protocolo Low-End..."
        bcdedit /timeout 3 | Out-Null
        bcdedit /set quietboot on | Out-Null
        bcdedit /set bootux disabled | Out-Null
        bcdedit /set numproc $env:NUMBER_OF_PROCESSORS | Out-Null

        Stop-Service -Name WSearch -Force -Confirm:$false -ErrorAction SilentlyContinue
        Set-Service -Name WSearch -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name MapsBroker -Force -Confirm:$false -ErrorAction SilentlyContinue
        Set-Service -Name MapsBroker -StartupType Disabled -ErrorAction SilentlyContinue

        $VisualFxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        If (-Not (Test-Path $VisualFxPath)) { New-Item -Path $VisualFxPath -Force | Out-Null }
        Set-ItemProperty -Path $VisualFxPath -Name "VisualFXSetting" -Type DWord -Value 2
    }

    # 7. RESTRICCIÓN DE PRIORIDAD DE CONDUCCIÓN DE WINDOWS DEFENDER
    Write-Host "[*] Bajando el consumo al motor de Windows Defender..."
    Set-MpPreference -ScanAvgCPULoadFactor 25 -ErrorAction SilentlyContinue

    # 8. ERRADICACIÓN DE RESTRICCIONES FAULT TOLERANT HEAP (Evita estrangulamiento)
    Write-Host "[*] Destruyendo el Fault Tolerant Heap (FTH) para evitar micro-tirones..."
    $FthPath = "HKLM:\Software\Microsoft\FTH"
    if (!(Test-Path $FthPath)) { New-Item -Path $FthPath -Force | Out-Null }
    Set-ItemProperty -Path $FthPath -Name "Enabled" -Type DWord -Value 0 -Force
    
    Write-Host "[+] Potencia desatada, Defender domado y parches removidos."
    exit 0
} Catch {
    Write-Host "[-] Error en Rendimiento General: $_"
    exit 1
}
