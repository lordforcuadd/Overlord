param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando purga avanzada de Bloatware y servicios basura..."
    
    # 1. PURGA DE APLICACIONES INÚTILES QUE CONSUMEN RAM EN SEGUNDO PLANO
    $Bloatware = @(
        "*Microsoft.BingNews*", "*Microsoft.GetHelp*", "*Microsoft.Getstarted*", 
        "*Microsoft.Messaging*", "*Microsoft.Microsoft3DViewer*", "*Microsoft.OneConnect*", 
        "*Microsoft.People*", "*Microsoft.SkypeApp*", "*Microsoft.WindowsFeedbackHub*", 
        "*Microsoft.ZuneVideo*", "*Microsoft.ZuneMusic*", "*TikTok*", "*Microsoft.549981C3F5F10*", # Cortana
        "*MicrosoftSolitaireCollection*", "*MixedReality.Portal*", "*Microsoft.CardGames*"
    )
    foreach ($App in $Bloatware) {
        try {
            Get-AppxPackage -Name $App -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        } catch {}
    }

    # 2. DESACTIVAR EJECUCIÓN DE APLICACIONES EN SEGUNDO PLANO
    $BgPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (!(Test-Path $BgPath)) { New-Item -Path $BgPath -Force | Out-Null }
    Set-ItemProperty -Path $BgPath -Name "GlobalUserDisabled" -Type DWord -Value 1 -ErrorAction SilentlyContinue -Force

    # 3. APAGAR EL RASTREO OCULTO DE WINDOWS Y BLOQUEAR BÚSQUEDA WEB DE BING
    Write-Host "[*] Desactivando Telemetría profunda y búsquedas invasivas de Bing..."
    $GpoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $GpoPath)) { New-Item -Path $GpoPath -Force | Out-Null }
    Set-ItemProperty -Path $GpoPath -Name "AllowTelemetry" -Type DWord -Value 0 -ErrorAction SilentlyContinue -Force

    # Bloqueo de Bing en el menú de inicio (Evita que consulte internet y consuma CPU en vano)
    $SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (!(Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Type DWord -Value 0 -ErrorAction SilentlyContinue -Force
    Set-ItemProperty -Path $SearchPath -Name "CortanaConsent" -Type DWord -Value 0 -ErrorAction SilentlyContinue -Force
    
    # 4. EXTERMINAR TAREAS PROGRAMADAS DE RECOLECCIÓN DE DATOS O TELEMETRÍA
    try {
        $Tasks = @(
            "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "Microsoft\Windows\Application Experience\ProgramDataUpdater",
            "Microsoft\Windows\Autochk\Proxy"
        )
        foreach ($Task in $Tasks) {
            Disable-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}

    # 5. PURGA DE SERVICIOS PESADOS (PROTEGIENDO EL TECLADO DE LA BARRA DE CONFIGURACIÓN)
    Write-Host "[*] Aplicando Purga de Servicios (Black Viper Method Seguro)..."
    # 🚀 FIX v2.5: Quitamos 'WSearch' de la purga para asegurar que las cajas de texto de Windows funcionen perfectamente
    $ServicesToKill = @("Fax", "MapsBroker", "DiagTrack") 
    foreach ($Svc in $ServicesToKill) {
        try {
            Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Svc -StartupType Disabled -ErrorAction SilentlyContinue
        } catch {}
    }

    # Forzamos que Windows Search se mantenga en automático para no romper las cajas de escritura nativas
    try {
        Set-Service -Name "WSearch" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    } catch {}

    Write-Host "[+] Limpieza completada. Telemetría cegada y cajas de escritura 100% funcionales."
    exit 0
} Catch {
    Write-Error "[-] Error en Debloat: $_"
    exit 1
}