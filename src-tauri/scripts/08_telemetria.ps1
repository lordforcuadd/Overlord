param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Try {
    Write-Host "[*] Erradicando Telemetria y apagando VBS..."

    $VbsPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard"
    Set-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0
    $HvciPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (!(Test-Path $HvciPath)) { New-Item -Path $HvciPath -Force | Out-Null }
    Set-ItemProperty -Path $HvciPath -Name "Enabled" -Type DWord -Value 0

    Stop-Service "DiagTrack" -WarningAction SilentlyContinue
    Set-Service "DiagTrack" -StartupType Disabled

    $ActivityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $ActivityPath)) { New-Item -Path $ActivityPath -Force | Out-Null }
    Set-ItemProperty -Path $ActivityPath -Name "PublishUserActivities" -Type DWord -Value 0

    Write-Host "[*] Inyectando bloqueos DNS en el archivo Hosts..."
    
    $HostsPath = "$env:windir\System32\drivers\etc\hosts"
    $TelemetryDomains = @(
        "0.0.0.0 vortex.data.microsoft.com",
        "0.0.0.0 settings-win.data.microsoft.com",
        "0.0.0.0 telemetry.microsoft.com",
        "0.0.0.0 oca.telemetry.microsoft.com"
    )
    
    foreach ($Domain in $TelemetryDomains) {
        if (!(Select-String -Path $HostsPath -Pattern $Domain -Quiet)) {
            Add-Content -Path $HostsPath -Value "`n$Domain"
        }
    }

    Write-Host "[+] VBS destruido. Telemetria cegada por DNS."
    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo de Telemetria: $_"
    exit 1
}