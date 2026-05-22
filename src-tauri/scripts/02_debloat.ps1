param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando limpieza de Bloatware..."
    
    # Purga de Bloatware segura
    $Bloatware = @(
        "*Microsoft.BingNews*", "*Microsoft.GetHelp*", "*Microsoft.Getstarted*", 
        "*Microsoft.Messaging*", "*Microsoft.Microsoft3DViewer*", "*Microsoft.OneConnect*", 
        "*Microsoft.People*", "*Microsoft.SkypeApp*", "*Microsoft.WindowsFeedbackHub*", 
        "*Microsoft.ZuneVideo*", "*Microsoft.ZuneMusic*", "*TikTok*"
    )
    foreach ($App in $Bloatware) {
        try {
            Get-AppxPackage -Name $App -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        } catch {}
    }

    $BgPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (!(Test-Path $BgPath)) { New-Item -Path $BgPath -Force | Out-Null }
    Set-ItemProperty -Path $BgPath -Name "GlobalUserDisabled" -Type DWord -Value 1 -ErrorAction SilentlyContinue

    Write-Host "[*] Desactivando Telemetria profunda por GPO..."
    $GpoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $GpoPath)) { New-Item -Path $GpoPath -Force | Out-Null }
    Set-ItemProperty -Path $GpoPath -Name "AllowTelemetry" -Type DWord -Value 0 -ErrorAction SilentlyContinue
    
    
    try {
        Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" -ErrorAction SilentlyContinue
    } catch {}

    Write-Host "[*] Aplicando Purga de Servicios (Black Viper Method Seguro)..."
    $ServicesToKill = @("Fax", "MapsBroker", "DiagTrack", "WSearch")
    
    foreach ($Svc in $ServicesToKill) {
        try {
            Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue
            if ($Svc -eq "WSearch") {
                Set-Service -Name $Svc -StartupType Manual -ErrorAction SilentlyContinue 
            } else {
                Set-Service -Name $Svc -StartupType Disabled -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    exit 0
} Catch {
    Write-Error "[-] Error en Debloat: $_"
    exit 1
}