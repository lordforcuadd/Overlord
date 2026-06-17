param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Erradicando telemetria e hilos de recoleccion..."

    $ActivityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"

    if (!(Test-Path $ActivityPath)) { New-Item -Path $ActivityPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $ActivityPath -ValueName "PublishUserActivities" -BackupSubFolder "Telemetry"
    }

    try {
        Stop-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    } catch {}

    try {
        Stop-Service "WerSvc" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        $WerSvcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $WerSvcPath -ValueName "Start" -BackupSubFolder "Telemetry"
        }
        Set-Service "WerSvc" -StartupType Disabled -ErrorAction SilentlyContinue
    } catch {}

    $WerPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    if (!(Test-Path $WerPath)) { New-Item -Path $WerPath -Force | Out-Null }
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $WerPath -ValueName "Disabled" -BackupSubFolder "Telemetry"
    }
    Set-ItemProperty -Path $WerPath -Name "Disabled" -Type DWord -Value 1 -Force | Out-Null
    if ((Get-ItemProperty -Path $WerPath -Name "Disabled").Disabled -ne 1) { 
        throw "Fallo al asegurar la desactivacion de Windows Error Reporting"
    }

    Set-ItemProperty -Path $ActivityPath -Name "PublishUserActivities" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemProperty -Path $ActivityPath -Name "PublishUserActivities").PublishUserActivities -ne 0) { 
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
                Backup-OverlordRegistryValue -TargetKey $LoggerKey -ValueName "Start" -BackupSubFolder "Telemetry"
            }
            Set-ItemProperty -Path $LoggerKey -Name "Start" -Type DWord -Value 0 -Force | Out-Null
            
            if ((Get-ItemProperty -Path $LoggerKey -Name "Start").Start -ne 0) { 
                throw "Fallo al asegurar el estado detenido para el logger: $Logger" 
            }
        }
        logman stop $Logger -ets -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host "[+] Flujos de telemetria e hilos espia erradicados con exito."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Telemetria: $_"
    exit 1
}