param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

$BackupManagerPath = Join-Path $PSScriptRoot "backup_manager.psm1"
if (Test-Path $BackupManagerPath) {
    Import-Module $BackupManagerPath -Force
}

Try {
    Write-Host "[*] Erradicando telemetria e hilos de recoleccion..."

    $VbsPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard"
    if (!(Test-Path $VbsPath)) { New-Item -Path $VbsPath -Force | Out-Null }

    $HvciPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (!(Test-Path $HvciPath)) { New-Item -Path $HvciPath -Force | Out-Null }

    $ActivityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $ActivityPath)) { New-Item -Path $ActivityPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $VbsPath -ValueName "EnableVirtualizationBasedSecurity" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey $HvciPath -ValueName "Enabled" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey $ActivityPath -ValueName "PublishUserActivities" -BackupSubFolder "Telemetry"
    }

    $SecureBootActive = $false
    try {
        if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
            $SecureBootActive = $true
        }
    } catch {}

    if ($SecureBootActive) {
        Write-Host "[!] ADVERTENCIA: Secure Boot detectado como ACTIVO en el firmware UEFI. La desactivacion por registro de VBS/HVCI no surtira efecto hasta que lo deshabilites manualmente en la BIOS." -ForegroundColor Yellow
    }

    Write-Host "[!] ADVERTENCIA: Desactivando aislamiento de Kernel e Integridad de Código basada en Virtualización (VBS/HVCI)." -ForegroundColor Yellow

    Set-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $HvciPath -Name "Enabled" -Type DWord -Value 0 -Force | Out-Null

    try {
        Stop-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    } catch {}

    Set-ItemProperty -Path $ActivityPath -Name "PublishUserActivities" -Type DWord -Value 0 -Force | Out-Null

    $TelemetryExes = @(
        "$env:SystemRoot\System32\CompatTelRunner.exe",
        "$env:SystemRoot\System32\DeviceCensus.exe",
        "$env:SystemRoot\System32\wsqmcons.exe"
    )
    foreach ($exe in $TelemetryExes) {
        if (Test-Path $exe) {
            $RuleName = "Overlord_Block_$(Split-Path $exe -Leaf)"
            if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -DisplayName $RuleName -Direction Outbound -Program $exe -Action Block -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @(
        "AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog",
        "SetupPlatformTel", "WdiContextLog"
    )
    foreach ($Logger in $Loggers) {
        $LoggerKey = "$LoggersPath\$Logger"
        if (Test-Path $LoggerKey) {
            if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                Backup-OverlordRegistryValue -TargetKey $LoggerKey -ValueName "Start" -BackupSubFolder "Telemetry"
            }
            Set-ItemProperty -Path $LoggerKey -Name "Start" -Type DWord -Value 0 -Force | Out-Null
        }
        logman stop $Logger -ets -ErrorAction SilentlyContinue | Out-Null
    }

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Telemetria: $_"
    exit 1
}