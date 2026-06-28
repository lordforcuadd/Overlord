param(
    [bool]$IsLaptop = $false
)
$ErrorActionPreference = "Stop"

Try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }
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
            Get-AppxPackage -Name $App -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            $AllProvisioned | Where-Object { $_.DisplayName -eq $App -or $_.PackageName -match $App } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "No se pudo remover la aplicacion bloatware ${App}: $_"
        }
    }

    Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -BackupSubFolder "Telemetry"
    Backup-OverlordRegistryValue -TargetKey "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "BingSearchEnabled" -BackupSubFolder "Telemetry"
    Backup-OverlordRegistryValue -TargetKey "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "CortanaConsent" -BackupSubFolder "Telemetry"
    Backup-OverlordRegistryValue -TargetKey "$HKCU_Path\Software\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "Telemetry"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "Telemetry"
    
    # Copia de seguridad para permisos de aplicaciones de segundo plano
    Backup-OverlordRegistryValue -TargetKey "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -ValueName "GlobalUserDisabled" -BackupSubFolder "Telemetry"
    
    # Copia de seguridad para políticas de Microsoft Edge
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ValueName "StartupBoostEnabled" -BackupSubFolder "Telemetry"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ValueName "BackgroundModeEnabled" -BackupSubFolder "Telemetry"

    # Copias de seguridad de servicios
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" -ValueName "Start" -BackupSubFolder "Services\DiagTrack"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -ValueName "Start" -BackupSubFolder "Services\dmwappushservice"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\Fax" -ValueName "Start" -BackupSubFolder "Services\Fax"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\RetailDemo" -ValueName "Start" -BackupSubFolder "Services\RetailDemo"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\MapsBroker" -ValueName "Start" -BackupSubFolder "Services\MapsBroker"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\PhoneSvc" -ValueName "Start" -BackupSubFolder "Services\PhoneSvc"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\AJRouter" -ValueName "Start" -BackupSubFolder "Services\AJRouter"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\WpcMonSvc" -ValueName "Start" -BackupSubFolder "Services\WpcMonSvc"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\TrkWks" -ValueName "Start" -BackupSubFolder "Services\TrkWks"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\RemoteRegistry" -ValueName "Start" -BackupSubFolder "Services\RemoteRegistry"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\WdiServiceHost" -ValueName "Start" -BackupSubFolder "Services\WdiServiceHost"
    Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\WdiSystemHost" -ValueName "Start" -BackupSubFolder "Services\WdiSystemHost"
    if (-not $IsLaptop) {
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\SensorService" -ValueName "Start" -BackupSubFolder "Services\SensorService"
    }

    $DataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $DataPath)) { New-Item -Path $DataPath -Force | Out-Null }
    Set-ItemProperty -Path $DataPath -Name "AllowTelemetry" -Type DWord -Value 0 -Force | Out-Null
    $AllowTelemetry = Get-ItemPropertyValue -Path $DataPath -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    if ($null -eq $AllowTelemetry -or $AllowTelemetry -ne 0) { Write-Warning "No se pudo asegurar AllowTelemetry" }

    $SearchPath = "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\Search"
    if (!(Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $SearchPath -Name "CortanaConsent" -Type DWord -Value 0 -Force | Out-Null
    $BingSearchEnabled = Get-ItemPropertyValue -Path $SearchPath -Name "BingSearchEnabled" -ErrorAction SilentlyContinue
    $CortanaConsent = Get-ItemPropertyValue -Path $SearchPath -Name "CortanaConsent" -ErrorAction SilentlyContinue
    if ($null -eq $BingSearchEnabled -or $BingSearchEnabled -ne 0) { Write-Warning "No se pudo asegurar BingSearchEnabled" }
    if ($null -eq $CortanaConsent -or $CortanaConsent -ne 0) { Write-Warning "No se pudo asegurar CortanaConsent" }

    $CopilotUserPath = "$HKCU_Path\Software\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotUserPath)) { New-Item -Path $CopilotUserPath -Force | Out-Null }
    Set-ItemProperty -Path $CopilotUserPath -Name "TurnOffWindowsCopilot" -Type DWord -Value 1 -Force | Out-Null

    $CopilotSystemPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotSystemPath)) { New-Item -Path $CopilotSystemPath -Force | Out-Null }
    Set-ItemProperty -Path $CopilotSystemPath -Name "TurnOffWindowsCopilot" -Type DWord -Value 1 -Force | Out-Null

    # Desactivar permisos de apps en segundo plano (UWP)
    $BgAppPath = "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (!(Test-Path $BgAppPath)) { New-Item -Path $BgAppPath -Force | Out-Null }
    Set-ItemProperty -Path $BgAppPath -Name "GlobalUserDisabled" -Type DWord -Value 1 -Force | Out-Null

    # Desactivar inicio rápido y segundo plano de Microsoft Edge
    $EdgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (!(Test-Path $EdgePolicyPath)) { New-Item -Path $EdgePolicyPath -Force | Out-Null }
    Set-ItemProperty -Path $EdgePolicyPath -Name "StartupBoostEnabled" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $EdgePolicyPath -Name "BackgroundModeEnabled" -Type DWord -Value 0 -Force | Out-Null

    # DiagTrack y servicios generales se deshabilitan. WdiServiceHost, WdiSystemHost y dmwappushservice se configuran como Manual para no romper Windows Update.
    $ServicesToDisable = @("DiagTrack", "Fax", "RetailDemo", "MapsBroker", "PhoneSvc", "AJRouter", "WpcMonSvc", "TrkWks", "RemoteRegistry")
    if (-not $IsLaptop) {
        $ServicesToDisable += "SensorService"
    }
    foreach ($Service in $ServicesToDisable) {
        $SvcObj = Get-Service -Name $Service -ErrorAction SilentlyContinue
        if ($null -ne $SvcObj) {
            # Respaldar WasRunning
            $SvcBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Services\$Service"
            if (!(Test-Path $SvcBackupPath)) { New-Item -Path $SvcBackupPath -Force | Out-Null }
            $WasRunning = if ($SvcObj.Status -eq "Running") { 1 } else { 0 }
            Set-ItemProperty -Path $SvcBackupPath -Name "WasRunning" -Value $WasRunning -Force -ErrorAction SilentlyContinue | Out-Null

            if ($SvcObj.Status -ne "Stopped") {
                Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue | Out-Null
        }
    }

    $ServicesToManual = @("WdiServiceHost", "WdiSystemHost", "dmwappushservice")
    foreach ($Service in $ServicesToManual) {
        $SvcObj = Get-Service -Name $Service -ErrorAction SilentlyContinue
        if ($null -ne $SvcObj) {
            # Respaldar WasRunning
            $SvcBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Services\$Service"
            if (!(Test-Path $SvcBackupPath)) { New-Item -Path $SvcBackupPath -Force | Out-Null }
            $WasRunning = if ($SvcObj.Status -eq "Running") { 1 } else { 0 }
            Set-ItemProperty -Path $SvcBackupPath -Name "WasRunning" -Value $WasRunning -Force -ErrorAction SilentlyContinue | Out-Null

            Set-Service -Name $Service -StartupType Manual -ErrorAction SilentlyContinue | Out-Null
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
        "Microsoft\Windows\Shell\FamilySafetyRefreshTask",
        "Microsoft\Windows\Device Information\Device"
    )

    $TasksBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Tasks"
    if (!(Test-Path $TasksBackupPath)) {
        try { New-Item -Path $TasksBackupPath -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    }

    foreach ($Task in $Tasks) {
        $TPath = "\" + (Split-Path $Task -Parent)
        $TName = Split-Path $Task -Leaf
        
        $TaskObj = Get-ScheduledTask -TaskPath $TPath -TaskName $TName -ErrorAction SilentlyContinue
        if ($null -ne $TaskObj) {
            # 1 = Habilitada (Ready, Running, etc.), 0 = Deshabilitada
            $IsEnabled = if ($TaskObj.State -ne "Disabled") { 1 } else { 0 }
            $TaskKeyName = $Task -replace '\\', '_'
            
            if (Test-Path $TasksBackupPath) {
                $props = Get-ItemProperty -Path $TasksBackupPath -ErrorAction SilentlyContinue
                $existing = if ($null -ne $props -and $null -ne $props.PSObject.Properties[$TaskKeyName]) { $props.PSObject.Properties[$TaskKeyName].Value } else { $null }
                if ($null -eq $existing) {
                    Set-ItemProperty -Path $TasksBackupPath -Name $TaskKeyName -Value $IsEnabled -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
        
        Disable-ScheduledTask -TaskPath $TPath -TaskName $TName -ErrorAction SilentlyContinue | Out-Null
    }

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo Debloat: $_"
    exit 1
}