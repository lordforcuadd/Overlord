param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"
$HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }

Try {
    Write-Host "[*] Erradicando telemetria e hilos de recoleccion..."

    $ActivityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"

    if (!(Test-Path $ActivityPath)) { New-Item -Path $ActivityPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $ActivityPath -ValueName "PublishUserActivities" -BackupSubFolder "Telemetry"
    }

    try {
        $SvcObj = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        if ($null -ne $SvcObj) {
            $SvcBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Services\DiagTrack"
            if (!(Test-Path $SvcBackupPath)) { New-Item -Path $SvcBackupPath -Force | Out-Null }
            $WasRunning = if ($SvcObj.Status -eq "Running") { 1 } else { 0 }
            Set-ItemProperty -Path $SvcBackupPath -Name "WasRunning" -Value $WasRunning -Force -ErrorAction SilentlyContinue | Out-Null
        }
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" -ValueName "Start" -BackupSubFolder "Services\DiagTrack"
        }
        Stop-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
        Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    try {
        $SvcObj = Get-Service -Name "WerSvc" -ErrorAction SilentlyContinue
        if ($null -ne $SvcObj) {
            $SvcBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Services\WerSvc"
            if (!(Test-Path $SvcBackupPath)) { New-Item -Path $SvcBackupPath -Force | Out-Null }
            $WasRunning = if ($SvcObj.Status -eq "Running") { 1 } else { 0 }
            Set-ItemProperty -Path $SvcBackupPath -Name "WasRunning" -Value $WasRunning -Force -ErrorAction SilentlyContinue | Out-Null
        }
        $WerSvcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $WerSvcPath -ValueName "Start" -BackupSubFolder "Services\WerSvc"
        }
        # Asegurar inicio Manual para no romper Windows Update
        Set-Service "WerSvc" -StartupType Manual -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    $WerPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    if (!(Test-Path $WerPath)) { New-Item -Path $WerPath -Force | Out-Null }
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $WerPath -ValueName "Disabled" -BackupSubFolder "Telemetry"
    }
    Set-ItemProperty -Path $WerPath -Name "Disabled" -Type DWord -Value 1 -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $WerPath -Name "Disabled" -ErrorAction SilentlyContinue) -ne 1) { 
        throw "Fallo al asegurar la desactivacion de Windows Error Reporting"
    }

    # Evitar reinicios automáticos de Windows Update con sesión iniciada
    $WUpPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (!(Test-Path $WUpPath)) { New-Item -Path $WUpPath -Force | Out-Null }
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $WUpPath -ValueName "NoAutoRebootWithLoggedOnUsers" -BackupSubFolder "Telemetry"
    }
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
        Write-Warning "No se pudieron inyectar las reglas del Firewall de Windows (es posible que el servicio MpsSvc esté deshabilitado): $_"
    }

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @(
        "AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog"
    )
    foreach ($Logger in $Loggers) {
        $LoggerKey = "$LoggersPath\$Logger"
        if (Test-Path $LoggerKey) {
            if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                Backup-OverlordRegistryValue -TargetKey $LoggerKey -ValueName "Start" -BackupSubFolder "Telemetry\Loggers\$Logger"
            }
            Set-ItemProperty -Path $LoggerKey -Name "Start" -Type DWord -Value 0 -Force | Out-Null
            
            if ((Get-ItemPropertyValue -Path $LoggerKey -Name "Start" -ErrorAction SilentlyContinue) -ne 0) { 
                throw "Fallo al asegurar el estado detenido para el logger: $Logger" 
            }
        }
        logman stop $Logger -ets -ErrorAction SilentlyContinue | Out-Null
    }

    # Bloqueo de Windows Recall (Directivas de Windows AI)
    $WindowsAIPolicyHKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    $WindowsAIPolicyHKCU = "$HKCU_Path\Software\Policies\Microsoft\Windows\WindowsAI"

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $WindowsAIPolicyHKLM -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey $WindowsAIPolicyHKLM -ValueName "DisableAIDataAnalysis" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey $WindowsAIPolicyHKLM -ValueName "AllowRecallEnablement" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey $WindowsAIPolicyHKCU -ValueName "TurnOffUserCameraCapture" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey $WindowsAIPolicyHKCU -ValueName "DisableAIDataAnalysis" -BackupSubFolder "Telemetry"
    }

    if (!(Test-Path $WindowsAIPolicyHKLM)) { New-Item -Path $WindowsAIPolicyHKLM -Force | Out-Null }
    Set-ItemProperty -Path $WindowsAIPolicyHKLM -Name "TurnOffUserCameraCapture" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path $WindowsAIPolicyHKLM -Name "DisableAIDataAnalysis" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path $WindowsAIPolicyHKLM -Name "AllowRecallEnablement" -Type DWord -Value 0 -Force | Out-Null

    if (!(Test-Path $WindowsAIPolicyHKCU)) { New-Item -Path $WindowsAIPolicyHKCU -Force | Out-Null }
    Set-ItemProperty -Path $WindowsAIPolicyHKCU -Name "TurnOffUserCameraCapture" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path $WindowsAIPolicyHKCU -Name "DisableAIDataAnalysis" -Type DWord -Value 1 -Force | Out-Null

    Write-Host "[+] Flujos de telemetria e hilos espia erradicados con exito."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Telemetria: $_"
    exit 1
}