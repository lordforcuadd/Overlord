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

    Write-Host "[*] Bloqueando dominios de telemetria via Windows Firewall..."
    
    $TelemetryDomains = @(
        "vortex.data.microsoft.com",
        "settings-win.data.microsoft.com",
        "telemetry.microsoft.com",
        "oca.telemetry.microsoft.com"
    )
    
    
    foreach ($Domain in $TelemetryDomains) {
        Try {
            $IPs = [System.Net.Dns]::GetHostAddresses($Domain) | Select-Object -ExpandProperty IPAddressToString
            foreach ($IP in $IPs) {
                $RuleName = "Overlord_Block_$Domain"
                
                if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
                    New-NetFirewallRule -DisplayName $RuleName -Direction Outbound -Action Block -RemoteAddress $IP -ErrorAction SilentlyContinue | Out-Null
                }
            }
        } Catch {}
    }

    Write-Host "[+] VBS destruido. Telemetria cegada por Firewall."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Telemetria: $_"
    exit 1
}