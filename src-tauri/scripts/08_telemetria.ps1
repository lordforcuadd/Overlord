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

    Write-Host "[*] Bloqueando binarios de telemetria en el Firewall..."
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

    Write-Host "[+] VBS destruido. Telemetria cegada por Firewall."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Telemetria: $_"
    exit 1
}