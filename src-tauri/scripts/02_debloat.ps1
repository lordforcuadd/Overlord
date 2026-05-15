param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Try {
    Write-Host "[*] Iniciando limpieza de Bloatware..."
    
    $Bloatware = @(
        "*Microsoft.BingNews*", "*Microsoft.GetHelp*", "*Microsoft.Getstarted*", 
        "*Microsoft.Messaging*", "*Microsoft.Microsoft3DViewer*", "*Microsoft.OneConnect*", 
        "*Microsoft.People*", "*Microsoft.SkypeApp*", "*Microsoft.WindowsFeedbackHub*", 
        "*Microsoft.ZuneVideo*", "*Microsoft.ZuneMusic*", "*TikTok*"
    )
    foreach ($App in $Bloatware) {
        Get-AppxPackage -Name $App -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }

    $BgPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (!(Test-Path $BgPath)) { New-Item -Path $BgPath -Force | Out-Null }
    Set-ItemProperty -Path $BgPath -Name "GlobalUserDisabled" -Type DWord -Value 1

    Write-Host "[*] Desactivando Telemetria profunda por GPO..."
    $GpoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $GpoPath)) { New-Item -Path $GpoPath -Force | Out-Null }
    Set-ItemProperty -Path $GpoPath -Name "AllowTelemetry" -Type DWord -Value 0
    
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" -ErrorAction SilentlyContinue
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" -ErrorAction SilentlyContinue

    Write-Host "[*] Aplicando Purga de Servicios (Black Viper Method Seguro)..."
    # Se eliminó Spooler y WSearch para mantener compatibilidad universal
    $ServicesToKill = @("Fax", "CDPSvc", "MapsBroker", "PcaSvc")
    
    foreach ($Svc in $ServicesToKill) {
        Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue
        Set-Service -Name $Svc -StartupType Disabled -ErrorAction SilentlyContinue
    }

    Write-Host "[+] Limpieza completada. Bloatware erradicado."
    exit 0
} Catch {
    Write-Error "[-] Error en Debloat: $_"
    exit 1
}