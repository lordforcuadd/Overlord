$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando purga de Bloatware y aplicaciones residuales..."

    $Apps = @(
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.GetHelp",
        "Microsoft.Getstarted", "Microsoft.Messaging", "Microsoft.3DBuilder",
        "Microsoft.People", "Microsoft.SkypeApp", "Microsoft.StickyNotes",
        "Microsoft.Wallet", "Microsoft.YourPhone", "Microsoft.ZuneVideo",
        "Microsoft.ZuneMusic", "Microsoft.MixedReality.Portal",
        "Microsoft.549981C3F5F10", "Microsoft.Windows.Ai.Copilot.Provider",
        "Microsoft.BingSearch", "Clipchamp.Clipchamp", "Microsoft.MicrosoftSolitaireCollection", "Microsoft.Todos",
        "Microsoft.PowerAutomateDesktop", "Microsoft.Cortana", "Microsoft.BingFinance",
        "Microsoft.BingSports", "Microsoft.MicrosoftMahjong", "Microsoft.WindowsFeedbackHub",
        "Microsoft.Print3D", "Microsoft.Microsoft3DViewer", "Microsoft.WindowsMaps"
    )

    $AllProvisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

    foreach ($App in $Apps) {
        if ($App -match "Xbox" -or $App -match "XboxIdentityProvider" -or $App -match "WindowsStore") {
            continue
        }
        try {
            Get-AppxPackage -Name $App -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            $AllProvisioned | Where-Object { $_.DisplayName -eq $App -or $_.PackageName -match $App } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "No se pudo remover la aplicacion bloatware ${App}: $_"
        }
    }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "BingSearchEnabled" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "CortanaConsent" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "Telemetry"
        
        # Copia de seguridad para permisos de aplicaciones de segundo plano
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -ValueName "GlobalUserDisabled" -BackupSubFolder "Telemetry"
        
        # Copia de seguridad para políticas de Microsoft Edge
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ValueName "StartupBoostEnabled" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ValueName "BackgroundModeEnabled" -BackupSubFolder "Telemetry"

        # Copias de seguridad de servicios
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\Fax" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\RetailDemo" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\MapsBroker" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\PhoneSvc" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\AJRouter" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\WpcMonSvc" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\TrkWks" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\RemoteRegistry" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\WdiServiceHost" -ValueName "Start" -BackupSubFolder "Services"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\WdiSystemHost" -ValueName "Start" -BackupSubFolder "Services"
        if (-not $IsLaptop) {
            Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\SensorService" -ValueName "Start" -BackupSubFolder "Services"
        }
    }

    $DataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $DataPath)) { New-Item -Path $DataPath -Force | Out-Null }
    Set-ItemProperty -Path $DataPath -Name "AllowTelemetry" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemProperty -Path $DataPath -Name "AllowTelemetry").AllowTelemetry -ne 0) { Write-Warning "No se pudo asegurar AllowTelemetry" }

    $SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (!(Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $SearchPath -Name "CortanaConsent" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemProperty -Path $SearchPath -Name "BingSearchEnabled").BingSearchEnabled -ne 0) { Write-Warning "No se pudo asegurar BingSearchEnabled" }
    if ((Get-ItemProperty -Path $SearchPath -Name "CortanaConsent").CortanaConsent -ne 0) { Write-Warning "No se pudo asegurar CortanaConsent" }

    $CopilotUserPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotUserPath)) { New-Item -Path $CopilotUserPath -Force | Out-Null }
    Set-ItemProperty -Path $CopilotUserPath -Name "TurnOffWindowsCopilot" -Type DWord -Value 1 -Force | Out-Null

    $CopilotSystemPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotSystemPath)) { New-Item -Path $CopilotSystemPath -Force | Out-Null }
    Set-ItemProperty -Path $CopilotSystemPath -Name "TurnOffWindowsCopilot" -Type DWord -Value 1 -Force | Out-Null

    # Desactivar permisos de apps en segundo plano (UWP)
    $BgAppPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (!(Test-Path $BgAppPath)) { New-Item -Path $BgAppPath -Force | Out-Null }
    Set-ItemProperty -Path $BgAppPath -Name "GlobalUserDisabled" -Type DWord -Value 1 -Force | Out-Null

    # Desactivar inicio rápido y segundo plano de Microsoft Edge
    $EdgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (!(Test-Path $EdgePolicyPath)) { New-Item -Path $EdgePolicyPath -Force | Out-Null }
    Set-ItemProperty -Path $EdgePolicyPath -Name "StartupBoostEnabled" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $EdgePolicyPath -Name "BackgroundModeEnabled" -Type DWord -Value 0 -Force | Out-Null

    $Services = @("DiagTrack", "dmwappushservice", "Fax", "RetailDemo", "MapsBroker", "PhoneSvc", "AJRouter", "WpcMonSvc", "TrkWks", "RemoteRegistry", "WdiServiceHost", "WdiSystemHost")
    if (-not $IsLaptop) {
        $Services += "SensorService"
    }
    foreach ($Service in $Services) {
        $SvcObj = Get-Service -Name $Service -ErrorAction SilentlyContinue
        if ($null -ne $SvcObj) {
            if ($SvcObj.Status -ne "Stopped") {
                Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
            }
            Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    

    $Tasks = @(
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "Microsoft\Windows\Autochk\Proxy",
        "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "Microsoft\Windows\Application Experience\StartupAppTask",
        "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "Microsoft\Windows\Feedback\Siuf\DmClient",
        "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
        "Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "Microsoft\Windows\DiskFootprint\Diagnostics",
        "Microsoft\Windows\Maps\MapsToastTask",
        "Microsoft\Windows\Maps\MapsUpdateTask",
        "Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "Microsoft\Windows\Shell\FamilySafetyMonitor",
        "Microsoft\Windows\Shell\FamilySafetyRefreshTask"
    )

    foreach ($Task in $Tasks) {
        $TPath = "\" + (Split-Path $Task -Parent)
        $TName = Split-Path $Task -Leaf
        Disable-ScheduledTask -TaskPath $TPath -TaskName $TName -ErrorAction SilentlyContinue
    }

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo Debloat: $_"
    exit 1
}