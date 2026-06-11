param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Erradicando telemetria e hilos de recoleccion..."

    $VbsPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard"
    $HvciPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    $ActivityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"

    if (!(Test-Path $VbsPath)) { New-Item -Path $VbsPath -Force | Out-Null }
    if (!(Test-Path $HvciPath)) { New-Item -Path $HvciPath -Force | Out-Null }
    if (!(Test-Path $ActivityPath)) { New-Item -Path $ActivityPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $VbsPath -ValueName "EnableVirtualizationBasedSecurity" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey $HvciPath -ValueName "Enabled" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey $ActivityPath -ValueName "PublishUserActivities" -BackupSubFolder "Telemetry"
    }

    $SkipVBSHVCI = $false

    try {
        $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($null -ne $OSInfo -and $OSInfo.Caption -match "Enterprise|EnterpriseG|Education|Server") {
            Write-Host "[+] Sistema Operativo Corporativo detectado ($($OSInfo.Caption)). Preservando VBS/HVCI para mantener directivas de seguridad corporativas." -ForegroundColor Green
            $SkipVBSHVCI = $true
        }
    } catch {
        Write-Warning "No se pudo determinar el tipo de Sistema Operativo: $_"
    }

    try {
        $BitLockerVolumes = Get-CimInstance -Namespace "root\cimv2\Security\MicrosoftVolumeEncryption" -ClassName "Win32_EncryptableVolume" -ErrorAction SilentlyContinue
        if ($BitLockerVolumes) {
            foreach ($Volume in $BitLockerVolumes) {
                if ($Volume.ProtectionStatus -eq 1) {
                    Write-Host "[+] Cifrado de Unidad BitLocker detectado como ACTIVO. Preservando aislamiento de Kernel para evitar corrupcion de llaves TPM." -ForegroundColor Green
                    $SkipVBSHVCI = $true
                    break
                }
            }
        }
    } catch {
        Write-Warning "No se pudo comprobar el cifrado de BitLocker: $_"
    }

    if (-not $SkipVBSHVCI) {
        $SecureBootActive = $false
        try {
            if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
                $SecureBootActive = $true
            }
        } catch {}

        if ($SecureBootActive) {
            Write-Host "[!] ADVERTENCIA: Secure Boot detectado como ACTIVO en el firmware UEFI. La desactivacion por registro de VBS/HVCI no surtira efecto completo hasta deshabilitarlo en la BIOS." -ForegroundColor Yellow
        }

        Write-Host "[!] Desactivando aislamiento de Kernel e Integridad de Código basada en Virtualización (VBS/HVCI)." -ForegroundColor Yellow

        Set-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0 -Force | Out-Null
        Set-ItemProperty -Path $HvciPath -Name "Enabled" -Type DWord -Value 0 -Force | Out-Null

        if ((Get-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity").EnableVirtualizationBasedSecurity -ne 0) { 
            throw "Fallo al asegurar la desactivacion de EnableVirtualizationBasedSecurity"
        }
        if ((Get-ItemProperty -Path $HvciPath -Name "Enabled").Enabled -ne 0) { 
            throw "Fallo al asegurar la desactivacion de Enabled (HVCI)"
        }
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