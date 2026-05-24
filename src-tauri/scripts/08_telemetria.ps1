param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Erradicando telemetría e hilos de recolección en caliente..."

    # 1. DESTRUCCIÓN COMPLETA DE VBS Y SEGURIDAD BASADA EN VIRTUALIZACIÓN (HVCI)
    $VbsPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard"
    Set-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0 -Force
    $HvciPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (!(Test-Path $HvciPath)) { New-Item -Path $HvciPath -Force | Out-Null }
    Set-ItemProperty -Path $HvciPath -Name "Enabled" -Type DWord -Value 0 -Force

    # 2. DETENCIÓN DEL MOTOR CENTRAL DE SEGUIMIENTO (DIAGTRACK)
    try {
        Stop-Service "DiagTrack" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    } catch {}

    $ActivityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $ActivityPath)) { New-Item -Path $ActivityPath -Force | Out-Null }
    Set-ItemProperty -Path $ActivityPath -Name "PublishUserActivities" -Type DWord -Value 0 -Force

    # 3. AISLAMIENTO PERIMETRAL MEDIANTE REGLAS DE FIREWALL PARA BINARIOS CHISMOSOS
    Write-Host "[*] Bloqueando ejecutables nativos de telemetría en el Firewall..."
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
    
    # 4. ASESINATO RADICAL DE SESIONES ETW AUTOLOGGERS EN TIEMPO REAL (WinScript Core)
    Write-Host "[*] Destruyendo recolectores de eventos activos en RAM..."
    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @(
        "AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog",
        "Circular Kernel Context Logger", "ReadyBoot", "SetupPlatformTel", "WdiContextLog"
    )
    foreach ($Logger in $Loggers) {
        $LoggerKey = "$LoggersPath\$Logger"
        if (Test-Path $LoggerKey) {
            reg.exe add "$LoggerKey" /v "Start" /t REG_DWORD /d 0 /f | Out-Null
        }
        # Abortar la sesión de transmisión en caliente activa en memoria inmediatamente
        logman stop $Logger -ets -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host "[+] Recolectores muertos, Firewall configurado y VBS apagado de raíz."
    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo de Telemetría: $_"
    exit 1
}