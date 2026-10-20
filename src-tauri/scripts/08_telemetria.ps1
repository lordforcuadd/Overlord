# 08_telemetria.ps1
$ErrorActionPreference = "Stop"
$HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }

Try {
    Write-Host "[*] Erradicando telemetria e hilos de recoleccion..."

    $ActivityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"

    if (!(Test-Path $ActivityPath)) { New-Item -Path $ActivityPath -Force | Out-Null }

    Backup-OverlordRegistryValue -TargetKey $ActivityPath -ValueName "PublishUserActivities" -BackupSubFolder "Telemetry"

    try {
        $SvcObj = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        if ($null -ne $SvcObj) {
            $SvcBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Services\DiagTrack"
            if (!(Test-Path $SvcBackupPath)) { New-Item -Path $SvcBackupPath -Force | Out-Null }
            $svcProps = Get-ItemProperty -Path $SvcBackupPath -ErrorAction SilentlyContinue
            if ($null -eq $svcProps -or $null -eq $svcProps.PSObject.Properties["WasRunning"]) {
                $WasRunning = if ($SvcObj.Status -eq "Running") { 1 } else { 0 }
                Set-ItemProperty -Path $SvcBackupPath -Name "WasRunning" -Value $WasRunning -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" -ValueName "Start" -BackupSubFolder "Services\DiagTrack"
        Stop-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
        Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue | Out-Null
        $diagStart = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" -Name "Start" -ErrorAction SilentlyContinue
        if ($diagStart -ne 4) {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" -Name "Start" -Type DWord -Value 4 -Force -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-Verbose "Fallo al detener DiagTrack: $_"
    }

    try {
        $DoSvcObj = Get-Service -Name "DoSvc" -ErrorAction SilentlyContinue
        if ($null -ne $DoSvcObj) {
            $DoSvcBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Services\DoSvc"
            if (!(Test-Path $DoSvcBackupPath)) { New-Item -Path $DoSvcBackupPath -Force | Out-Null }
            $svcProps = Get-ItemProperty -Path $DoSvcBackupPath -ErrorAction SilentlyContinue
            if ($null -eq $svcProps -or $null -eq $svcProps.PSObject.Properties["WasRunning"]) {
                $WasRunning = if ($DoSvcObj.Status -eq "Running") { 1 } else { 0 }
                Set-ItemProperty -Path $DoSvcBackupPath -Name "WasRunning" -Value $WasRunning -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc" -ValueName "Start" -BackupSubFolder "Services\DoSvc"
        Stop-Service "DoSvc" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
        Set-Service "DoSvc" -StartupType Manual -ErrorAction SilentlyContinue | Out-Null
    } catch {
        Write-Verbose "Fallo al detener DoSvc: $_"
    }

    try {
        $SvcObj = Get-Service -Name "WerSvc" -ErrorAction SilentlyContinue
        if ($null -ne $SvcObj) {
            $SvcBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Services\WerSvc"
            if (!(Test-Path $SvcBackupPath)) { New-Item -Path $SvcBackupPath -Force | Out-Null }
            $svcProps = Get-ItemProperty -Path $SvcBackupPath -ErrorAction SilentlyContinue
            if ($null -eq $svcProps -or $null -eq $svcProps.PSObject.Properties["WasRunning"]) {
                $WasRunning = if ($SvcObj.Status -eq "Running") { 1 } else { 0 }
                Set-ItemProperty -Path $SvcBackupPath -Name "WasRunning" -Value $WasRunning -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
        $WerSvcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"
        Backup-OverlordRegistryValue -TargetKey $WerSvcPath -ValueName "Start" -BackupSubFolder "Services\WerSvc"
        # Asegurar inicio Manual para no romper Windows Update
        Set-Service "WerSvc" -StartupType Manual -ErrorAction SilentlyContinue | Out-Null
        if ($null -ne $SvcObj -and $SvcObj.Status -eq "Running") {
            Stop-Service "WerSvc" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-Verbose "Fallo al ajustar WerSvc: $_"
    }

    $WerPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    if (!(Test-Path $WerPath)) { New-Item -Path $WerPath -Force | Out-Null }
    Backup-OverlordRegistryValue -TargetKey $WerPath -ValueName "Disabled" -BackupSubFolder "Telemetry"
    Set-ItemProperty -Path $WerPath -Name "Disabled" -Type DWord -Value 1 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $WerPath -Name "Disabled" -ErrorAction SilentlyContinue) -ne 1) { 
        throw "Fallo al asegurar la desactivacion de Windows Error Reporting"
    }

    # Evitar reinicios automaticos de Windows Update con sesion iniciada
    $WUpPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (!(Test-Path $WUpPath)) { New-Item -Path $WUpPath -Force | Out-Null }
    Backup-OverlordRegistryValue -TargetKey $WUpPath -ValueName "NoAutoRebootWithLoggedOnUsers" -BackupSubFolder "Telemetry"
    Set-ItemProperty -Path $WUpPath -Name "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1 -Force | Out-Null

    Set-ItemProperty -Path $ActivityPath -Name "PublishUserActivities" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $ActivityPath -Name "PublishUserActivities" -ErrorAction SilentlyContinue) -ne 0) { 
        throw "Fallo al asegurar la directiva PublishUserActivities en 0"
    }

    try {
        $TelemetryExes = @(
            "$env:SystemRoot\System32\CompatTelRunner.exe",
            "$env:SystemRoot\System32\DeviceCensus.exe",
            "$env:SystemRoot\System32\wsqmcons.exe"
        )
        foreach ($exe in $TelemetryExes) {
            if (Test-Path $exe) {
                $RuleName = "Overlord_Block_$(Split-Path $exe -Leaf)"
                if (-not (Get-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue)) {
                    New-NetFirewallRule -Name $RuleName -DisplayName $RuleName -Direction Outbound -Program $exe -Action Block -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
    } catch {
        Write-Warning "No se pudieron inyectar las reglas del Firewall de Windows (es posible que el servicio MpsSvc este deshabilitado): $_"
    }

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @(
        "AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog"
    )
    foreach ($Logger in $Loggers) {
        $LoggerKey = "$LoggersPath\$Logger"
        if (Test-Path $LoggerKey) {
            Backup-OverlordRegistryValue -TargetKey $LoggerKey -ValueName "Start" -BackupSubFolder "Telemetry\Loggers\$Logger"
            Set-ItemProperty -Path $LoggerKey -Name "Start" -Type DWord -Value 0 -Force | Out-Null
            
            if ((Get-ItemPropertyValue -Path $LoggerKey -Name "Start" -ErrorAction SilentlyContinue) -ne 0) { 
                throw "Fallo al asegurar el estado detenido para el logger: $Logger" 
            }
            try { logman.exe stop $Logger -ets *>&1 | Out-Null } catch { Write-Verbose "Logger ETW ${Logger} no estaba activo o no se pudo detener: $_" }
        }
    }

    # Bloqueo de Windows Recall (Directivas de Windows AI)
    $WindowsAIPolicyHKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"

    Backup-OverlordRegistryValue -TargetKey $WindowsAIPolicyHKLM -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "Telemetry\WindowsAI_HKLM"
    Backup-OverlordRegistryValue -TargetKey $WindowsAIPolicyHKLM -ValueName "DisableAIDataAnalysis" -BackupSubFolder "Telemetry\WindowsAI_HKLM"
    Backup-OverlordRegistryValue -TargetKey $WindowsAIPolicyHKLM -ValueName "AllowRecallEnablement" -BackupSubFolder "Telemetry\WindowsAI_HKLM"

    if (!(Test-Path $WindowsAIPolicyHKLM)) { New-Item -Path $WindowsAIPolicyHKLM -Force | Out-Null }
    Set-ItemProperty -Path $WindowsAIPolicyHKLM -Name "TurnOffUserCameraCapture" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path $WindowsAIPolicyHKLM -Name "DisableAIDataAnalysis" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path $WindowsAIPolicyHKLM -Name "AllowRecallEnablement" -Type DWord -Value 0 -Force | Out-Null

    Write-Host "[+] Flujos de telemetria e hilos espia erradicados con exito."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Telemetria: $_"
    exit 1
}
