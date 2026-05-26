param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Optimizando rendimiento del sistema y potencia de hilos de CPU..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Performance"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    
    # Respaldo dinámico inicial de mitigaciones del Kernel y paginación
    if (Test-Path $MemPath) {
        $OrigPaging = (Get-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -ErrorAction SilentlyContinue).DisablePagingExecutive
        $OrigCache = (Get-ItemProperty -Path $MemPath -Name "LargeSystemCache" -ErrorAction SilentlyContinue).LargeSystemCache
        $OrigSpec = (Get-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue).FeatureSettingsOverride
        $OrigSpecMask = (Get-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue).FeatureSettingsOverrideMask

        if ($OrigPaging -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "DisablePagingExecutive" -ErrorAction SilentlyContinue) -eq $null) { Set-ItemProperty -Path $BackupPath -Name "DisablePagingExecutive" -Type DWord -Value $OrigPaging -Force }
        if ($OrigCache -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "LargeSystemCache" -ErrorAction SilentlyContinue) -eq $null) { Set-ItemProperty -Path $BackupPath -Name "LargeSystemCache" -Type DWord -Value $OrigCache -Force }
        if ($OrigSpec -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue) -eq $null) { Set-ItemProperty -Path $BackupPath -Name "FeatureSettingsOverride" -Type DWord -Value $OrigSpec -Force }
        if ($OrigSpecMask -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue) -eq $null) { Set-ItemProperty -Path $BackupPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value $OrigSpecMask -Force }
    }

    # 1. PLAN DE ENERGÍA DE RENDIMIENTO MÁXIMO DEFINITIVO
    $UltimatePlan = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    $PlanGUID = $UltimatePlan -match "([a-f0-9\-]{36})" | Out-Null
    $PlanGUID = $Matches[1]
    powercfg -setactive $PlanGUID

    # 2. RESTRICCIÓN DE CAPTURAS EN SEGUNDO PLANO GAME DVR (Con Respaldo)
    $GameDVRPath = "HKCU:\System\GameConfigStore"
    Set-ItemProperty -Path $GameDVRPath -Name "GameDVR_Enabled" -Type DWord -Value 0
    $GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (!(Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }
    Set-ItemProperty -Path $GameBarPath -Name "AllowGameDVR" -Type DWord -Value 0

    # 3. PURGA COMPLETA DE CACHÉS VOLÁTILES DE ALTA VELOCIDAD
    Write-Host "[*] Limpiando archivos y registros basura de la caché dinámica de Windows..."
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue

    # 4. GESTIÓN INTEGRAL ADAPTATIVA DE RAM (Evita Stutters de Memoria)
    Write-Host "[*] Evaluando Inteligencia y Factor de Forma de Memoria RAM..."
    # 🚀 REGLA DE ORO v2.5+: Solo forzar el Kernel en la RAM física si el equipo es Desktop y tiene >= 16GB. Evita el ahogo en Laptops.
    if ($RamGB -ge 16 -and !$IsLaptop) {
        Write-Host "    -> Hardware de Gama Alta Detectado: Optimizando Executive Paging y System Cache..."
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 1 -Force
        Set-ItemProperty -Path $MemPath -Name "LargeSystemCache" -Type DWord -Value 1 -Force
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    } else {
        Write-Host "    -> Resguardando Entorno Móvil/Gama Media: Manteniendo paginación elástica estable..."
        Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 0 -Force
        Set-ItemProperty -Path $MemPath -Name "LargeSystemCache" -Type DWord -Value 0 -Force
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    }

    # 5. REMOCIÓN COMPLETA DE LAS MITIGACIONES DE CPU (Spectre y Meltdown Bypass)
    Write-Host "[*] Desactivando mitigaciones Spectre/Meltdown para máxima aceleración de IPC..."
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value 3 -Force
    Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value 3 -Force

    # 6. PROTOCOLO INTELIGENTE BAJA GAMA PARA EQUIPOS COMPROMETIDOS
    if ($RamGB -le 6) {
        Write-Host "    -> RAM Crítica ($RamGB GB) detectada: Activando Protocolo Low-End defensivo..."
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
    Set-MpPreference -ScanAvgCPULoadFactor 25 -ErrorAction SilentlyContinue

    # 8. ERRADICACIÓN DE RESTRICCIONES FAULT TOLERANT HEAP (Evita micro-tirones)
    $FthPath = "HKLM:\Software\Microsoft\FTH"
    if (!(Test-Path $FthPath)) { New-Item -Path $FthPath -Force | Out-Null }
    Set-ItemProperty -Path $FthPath -Name "Enabled" -Type DWord -Value 0 -Force
    
    Write-Host "[+] Rendimiento unificado, latencia de núcleos optimizada y potencia liberada."
    exit 0
} Catch {
    Write-Host "[-] Error en Módulo de Rendimiento General: $_"
    exit 1
}
