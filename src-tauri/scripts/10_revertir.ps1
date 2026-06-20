param(
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

function Invoke-OverlordSafeRestore {
    param(
        [string]$TargetKey,
        [string]$ValueName,
        [string]$BackupSubFolder,
        $DefaultValue,
        [string]$DefaultType = "DWord"
    )
    $BackupKey = "HKLM:\SOFTWARE\Overlord\Backup\$BackupSubFolder"
    $HasBackup = $false
    if (Test-Path $BackupKey) {
        $BckVal = (Get-ItemProperty -Path $BackupKey -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
        if ($null -ne $BckVal) {
            $HasBackup = $true
        }
    }
    if ($HasBackup) {
        if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Restore-OverlordRegistryValue -TargetKey $TargetKey -ValueName $ValueName -BackupSubFolder $BackupSubFolder | Out-Null
        }
    } else {
        if ($null -ne $DefaultValue) {
            if (!(Test-Path $TargetKey)) { New-Item -Path $TargetKey -Force | Out-Null }
            Set-ItemProperty -Path $TargetKey -Name $ValueName -Type $DefaultType -Value $DefaultValue -Force | Out-Null
        }
    }
}

Try {
    Write-Host "[*] Iniciando reversion simetrica de Overlord con helpers globales..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    $MsiBackupKey = "$BackupPath\MSI"
    $NetBackupKey = "$BackupPath\CPU\NetworkAffinity"
    $GameHooksBackup = "$BackupPath\GameHooks"

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ValueName "Win32PrioritySeparation" -BackupSubFolder "Performance" -DefaultValue 2

    $MousePath = "HKCU:\Control Panel\Mouse"
    Invoke-OverlordSafeRestore -TargetKey $MousePath -ValueName "MouseSpeed" -BackupSubFolder "Mouse" -DefaultValue "1" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey $MousePath -ValueName "MouseThreshold1" -BackupSubFolder "Mouse" -DefaultValue "6" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey $MousePath -ValueName "MouseThreshold2" -BackupSubFolder "Mouse" -DefaultValue "10" -DefaultType "String"
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -ErrorAction SilentlyContinue | Out-Null

    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\StickyKeys" -ValueName "Flags" -BackupSubFolder "Accessibility" -DefaultValue "510" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\ToggleKeys" -ValueName "Flags" -BackupSubFolder "Accessibility" -DefaultValue "62"  -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "Flags" -BackupSubFolder "Accessibility" -DefaultValue "126" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "AutoRepeatDelay" -BackupSubFolder "Accessibility" -DefaultValue "1000" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "AutoRepeatRate" -BackupSubFolder "Accessibility" -DefaultValue "500" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "DelayBeforeAcceptance" -BackupSubFolder "Accessibility" -DefaultValue "1000" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "BounceTime" -BackupSubFolder "Accessibility" -DefaultValue "0" -DefaultType "String"

    $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $false)
    if ($pciKey) {
        foreach ($venId in $pciKey.GetSubKeyNames()) {
            $venKey = $pciKey.OpenSubKey($venId, $false)
            if ($venKey) {
                foreach ($devId in $venKey.GetSubKeyNames()) {
                    $devKey = $venKey.OpenSubKey($devId, $false)
                    if ($devKey) {
                        $class = $devKey.GetValue("Class")
                        $deviceRegID = "PCI_${venId}_${devId}_Device Parameters"
                        $paramPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\$venId\$devId\Device Parameters"

                        if ($class -eq "Display" -or $class -eq "USB" -or $class -eq "MEDIA" -or $class -eq "AudioEndpoint") {
                            try {
                                if (Test-Path $MsiBackupKey) {
                                    $savedMsi = (Get-ItemProperty -Path $MsiBackupKey -Name $deviceRegID -ErrorAction SilentlyContinue).$deviceRegID
                                    if ($null -ne $savedMsi) {
                                        $MsiSubKey = "$paramPath\Interrupt Management\MessageSignaledInterruptProperties"
                                        if ($savedMsi -eq '_ABSENT_') {
                                            if (Test-Path $MsiSubKey) { Remove-ItemProperty -Path $MsiSubKey -Name "MSISupported" -ErrorAction SilentlyContinue | Out-Null }
                                        } else {
                                            if (!(Test-Path $MsiSubKey)) { New-Item -Path $MsiSubKey -Force | Out-Null }
                                            Set-ItemProperty -Path $MsiSubKey -Name "MSISupported" -Type DWord -Value $savedMsi -Force | Out-Null
                                        }
                                    }
                                    
                                    # Revertir prioridad de interrupción
                                    $priorityRegID = "PCI_${venId}_${devId}_DevicePriority"
                                    $savedPriority = (Get-ItemProperty -Path $MsiBackupKey -Name $priorityRegID -ErrorAction SilentlyContinue).$priorityRegID
                                    if ($null -ne $savedPriority) {
                                        $AffinitySubKey = "$paramPath\Interrupt Management\Affinity Policy"
                                        if ($savedPriority -eq '_ABSENT_') {
                                            if (Test-Path $AffinitySubKey) { Remove-ItemProperty -Path $AffinitySubKey -Name "DevicePriority" -ErrorAction SilentlyContinue | Out-Null }
                                        } else {
                                            if (!(Test-Path $AffinitySubKey)) { New-Item -Path $AffinitySubKey -Force | Out-Null }
                                            Set-ItemProperty -Path $AffinitySubKey -Name "DevicePriority" -Type DWord -Value $savedPriority -Force | Out-Null
                                        }
                                    }
                                }
                            } catch {
                                Write-Warning "No se pudieron revertir los parametros MSI para el dispositivo ${deviceRegID}: $_"
                            }
                        }

                        if ($class -eq "Net") {
                            try {
                                if (Test-Path $NetBackupKey) {
                                    $savedPolicy   = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Policy"   -ErrorAction SilentlyContinue)."${deviceRegID}_Policy"
                                    $savedOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Override" -ErrorAction SilentlyContinue)."${deviceRegID}_Override"

                                    if ($null -ne $savedPolicy) {
                                        $affinityPath = "$paramPath\Interrupt Management\Affinity Policy"
                                        if ($savedPolicy -eq '_ABSENT_') {
                                            if (Test-Path $affinityPath) {
                                                Remove-ItemProperty -Path $affinityPath -Name "DevicePolicy" -ErrorAction SilentlyContinue | Out-Null
                                                Remove-ItemProperty -Path $affinityPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue | Out-Null
                                            }
                                        } else {
                                            if (!(Test-Path $affinityPath)) { New-Item -Path $affinityPath -Force | Out-Null }
                                            Set-ItemProperty -Path $affinityPath -Name "DevicePolicy" -Type DWord -Value $savedPolicy -Force | Out-Null
                                            if ($null -ne $savedOverride -and $savedOverride -ne '_ABSENT_') {
                                                Set-ItemProperty -Path $affinityPath -Name "AssignmentSetOverride" -Type Binary -Value $savedOverride -Force | Out-Null
                                            } else {
                                                Remove-ItemProperty -Path $affinityPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue | Out-Null
                                            }
                                        }
                                    }
                                }
                            } catch {
                                Write-Warning "No se pudieron revertir los parametros de Afinidad de Red para el dispositivo ${deviceRegID}: $_"
                            }
                        }
                        $devKey.Close()
                    }
                }
                $venKey.Close()
            }
        }
        $pciKey.Close()
    }

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -BackupSubFolder "Telemetry" -DefaultValue 3
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc" -ValueName "Start" -BackupSubFolder "Telemetry" -DefaultValue 3
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -ValueName "Disabled" -BackupSubFolder "Telemetry" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "BingSearchEnabled" -BackupSubFolder "Telemetry" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "CortanaConsent" -BackupSubFolder "Telemetry" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -ValueName "GlobalUserDisabled" -BackupSubFolder "Telemetry" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ValueName "StartupBoostEnabled" -BackupSubFolder "Telemetry" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ValueName "BackgroundModeEnabled" -BackupSubFolder "Telemetry" -DefaultValue $null
    Remove-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"  -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue | Out-Null

    $StartTypeMap = @{ 2 = "Automatic"; 3 = "Manual"; 4 = "Disabled" }
    $ServicesFallback = @{
        "DiagTrack"        = "Automatic"
        "dmwappushservice" = "Manual"
        "Fax"              = "Manual"
        "RetailDemo"       = "Disabled"
        "MapsBroker"       = "Automatic"
        "PhoneSvc"         = "Manual"
        "AJRouter"         = "Manual"
        "WpcMonSvc"        = "Manual"
        "SensorService"    = "Manual"
        "TrkWks"           = "Automatic"
        "RemoteRegistry"   = "Disabled"
        "WdiServiceHost"   = "Manual"
        "WdiSystemHost"    = "Manual"
    }
    foreach ($Svc in $ServicesFallback.Keys) {
        $SavedStart = $null
        if (Test-Path "$BackupPath\Services") {
            $SavedStart = (Get-ItemProperty -Path "$BackupPath\Services" -Name $Svc -ErrorAction SilentlyContinue).$Svc
        }
        $StartType = if ($null -ne $SavedStart -and $SavedStart -notmatch '_ABSENT_') { $StartTypeMap[[int]$SavedStart] } else { $ServicesFallback[$Svc] }
        if ($StartType) {
            Set-Service -Name $Svc -StartupType $StartType -ErrorAction SilentlyContinue
            if ($StartType -ne "Disabled") { Start-Service -Name $Svc -ErrorAction SilentlyContinue }
        }
    }

    try {
        Get-NetFirewallRule -DisplayName "Overlord_Block_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue | Out-Null
    } catch {
        Write-Warning "No se pudieron remover las reglas del Firewall de Windows: $_"
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
        Enable-ScheduledTask -TaskPath $TPath -TaskName $TName -ErrorAction SilentlyContinue | Out-Null
    }

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ValueName "NetworkThrottlingIndex" -BackupSubFolder "Network" -DefaultValue 10
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ValueName "SystemResponsiveness" -BackupSubFolder "Network" -DefaultValue 20
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -ValueName "InitialRto" -BackupSubFolder "Network" -DefaultValue 3000
    
    $GamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (Test-Path $GamesPath) {
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "Scheduling Category" -BackupSubFolder "Performance" -DefaultValue "Medium" -DefaultType "String"
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "SFIO Priority" -BackupSubFolder "Performance" -DefaultValue "Normal" -DefaultType "String"
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "Priority" -BackupSubFolder "Performance" -DefaultValue 2 -DefaultType "DWord"
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "GPU Priority" -BackupSubFolder "Performance" -DefaultValue 8 -DefaultType "DWord"
        Invoke-OverlordSafeRestore -TargetKey $GamesPath -ValueName "Clock Rate" -BackupSubFolder "Performance" -DefaultValue 10 -DefaultType "DWord"
    }

    # Revertir configuraciones especificas de interfaces de red
    $InterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $InterfacesPath) {
        $InterfaceKeys = Get-ChildItem -Path $InterfacesPath -ErrorAction SilentlyContinue
        foreach ($Key in $InterfaceKeys) {
            if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                Restore-OverlordRegistryValue -TargetKey $Key.PSPath -ValueName "TcpAckFrequency" -BackupSubFolder "Network" | Out-Null
                Restore-OverlordRegistryValue -TargetKey $Key.PSPath -ValueName "TcpNoDelay" -BackupSubFolder "Network" | Out-Null
            }
        }
    }

    # Revertir ahorros de energia en adaptadores de red advanced
    $NetClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $NetClassPath) {
        $NetAdapters = Get-ChildItem -Path $NetClassPath -ErrorAction SilentlyContinue
        foreach ($Adapter in $NetAdapters) {
            if ($Adapter.PSChildName -match "^\d{4}$") {
                $PowerKeys = @("*EEE", "EEE", "*GreenEnergy", "GreenEnergy", "*EEELinkAdvertisement", "EEELinkAdvertisement", "*EnergyEfficientEthernet", "EnergyEfficientEthernet", "*PacketCoalescing", "PacketCoalescing", "*InterruptModeration", "InterruptModeration", "*FlowControl", "FlowControl")
                foreach ($PKey in $PowerKeys) {
                    if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                        Restore-OverlordRegistryValue -TargetKey $Adapter.PSPath -ValueName $PKey -BackupSubFolder "Network" | Out-Null
                    }
                }
            }
        }
    }

    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh int tcp set global ecncapability=default | Out-Null

    $Adapters = Get-NetAdapter -ErrorAction SilentlyContinue
    foreach ($Adapter in $Adapters) {
        if ($Adapter.Status -eq "Up" -or $Adapter.HardwareInterface -eq $true) {
            Enable-NetAdapterLso -Name $Adapter.Name -IPv4 -IPv6 -ErrorAction SilentlyContinue | Out-Null
            Enable-NetAdapterRsc -Name $Adapter.Name -IPv4 -IPv6 -ErrorAction SilentlyContinue | Out-Null
            Set-NetAdapterRss -Name $Adapter.Name -Profile ClosestStatic -ErrorAction SilentlyContinue | Out-Null
        }
    }

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $ControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "FeatureSettingsOverride" -BackupSubFolder "Performance" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "FeatureSettingsOverrideMask" -BackupSubFolder "Performance" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\System\GameConfigStore" -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance" -DefaultValue 1
    Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    Enable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ValueName "HwSchMode" -BackupSubFolder "GPU" -DefaultValue 2
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ValueName "EnableTransparency" -BackupSubFolder "GPU" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -ValueName "AllowGameDVR" -BackupSubFolder "GPU" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -ValueName "AppCaptureEnabled" -BackupSubFolder "GPU" -DefaultValue 1

    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    $FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "NtfsDisableLastAccessUpdate" -BackupSubFolder "Storage" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "NtfsDisable8dot3NameCreation" -BackupSubFolder "Storage" -DefaultValue 2
    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "NtfsMemoryUsage" -BackupSubFolder "Storage" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $FastStartPath -ValueName "HiberbootEnabled" -BackupSubFolder "Storage" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -ValueName "SystemRestorePointCreationFrequency" -BackupSubFolder "Storage" -DefaultValue $null

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -ValueName "PublishUserActivities" -BackupSubFolder "Telemetry" -DefaultValue 1

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @("AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog")
    foreach ($Logger in $Loggers) {
        Invoke-OverlordSafeRestore -TargetKey "$LoggersPath\$Logger" -ValueName "Start" -BackupSubFolder "Telemetry" -DefaultValue 1
    }

    $PowerBackup = "$BackupPath\Power"
    if (Test-Path $PowerBackup) {
        $Data = Get-ItemProperty -Path $PowerBackup -ErrorAction SilentlyContinue
        $SavedActiveGuid = $Data.ActivePowerPlan
        $CustomPlanGuid = $Data.CustomPowerPlan

        
        if (![string]::IsNullOrWhiteSpace($CustomPlanGuid)) {
            try {
                
                $current = powercfg /getactivescheme
                if ($current -match $CustomPlanGuid) {
                    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
                }
                powercfg /delete $CustomPlanGuid 2>$null | Out-Null
            } catch {
                Write-Host "[!] Aviso: No se pudo borrar el plan custom, posiblemente ya no existe."
            }
        }

        
        if (![string]::IsNullOrWhiteSpace($SavedActiveGuid)) {
            try {
                powercfg /setactive $SavedActiveGuid 2>$null | Out-Null
            } catch {
                powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null
            }
        }

        $PowerSettingsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
        Invoke-OverlordSafeRestore -TargetKey $PowerSettingsPath -ValueName "ValueMax" -BackupSubFolder "Power" -DefaultValue $null
        Invoke-OverlordSafeRestore -TargetKey $PowerSettingsPath -ValueName "ValueMin" -BackupSubFolder "Power" -DefaultValue $null
    }
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -ValueName "PowerThrottlingOff" -BackupSubFolder "Power" -DefaultValue 0

    $StorageBackup = "HKLM:\SOFTWARE\Overlord\Backup\Storage"
    $SavedHibernate = $null
    if (Test-Path $StorageBackup) {
        $SavedHibernate = (Get-ItemProperty -Path $StorageBackup -Name "HibernateEnabled" -ErrorAction SilentlyContinue).HibernateEnabled
    }
    if ($null -ne $SavedHibernate -and $SavedHibernate -ne '_ABSENT_') {
        if ($SavedHibernate -eq 0) { powercfg.exe /hibernate off | Out-Null } else { powercfg.exe /hibernate on | Out-Null }
    }

    if (Test-Path $GameHooksBackup) {
        Write-Host "[*] Revirtiendo capas de compatibilidad grafica de forma determinista..."
        $SubKeys = Get-ChildItem -Path $GameHooksBackup -ErrorAction SilentlyContinue
        foreach ($Key in $SubKeys) {
            $RegData = Get-ItemProperty -Path $Key.PSPath -ErrorAction SilentlyContinue
            $GamePath = $RegData.Path
            $PreviousLayers = $RegData.PreviousLayers
            
            if (![string]::IsNullOrWhiteSpace($GamePath)) {
                $LayersPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
                if (Test-Path $LayersPath) {
                    if (![string]::IsNullOrWhiteSpace($PreviousLayers)) {
                        Set-ItemProperty -Path $LayersPath -Name $GamePath -Type String -Value $PreviousLayers -Force | Out-Null
                    } else {
                        Remove-ItemProperty -Path $LayersPath -Name $GamePath -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }
        }
    }

    $KnownGameFolders = @("FortniteGame", "VALORANT", "ShooterGame", "Apex", "Cyberpunk 2077", "Dota 2", "Call of Duty")
    foreach ($Folder in $KnownGameFolders) {
        $GamePath = Join-Path $env:LOCALAPPDATA $Folder
        if (Test-Path $GamePath) {
            Get-ChildItem -Path $GamePath -Filter "GameUserSettings.ini" -Recurse -Depth 4 -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.IsReadOnly) { Set-ItemProperty -Path $_.FullName -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null }
            }
        }
    }

    $TaskName = "OverlordPriorityMonitor"
    $ProgData = $env:ProgramData
    if ([string]::IsNullOrWhiteSpace($ProgData)) { 
        $SysDrive = $env:SystemDrive
        if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
        $ProgData = Join-Path $SysDrive "ProgramData"
    }
    $InstallDir = Join-Path $ProgData "Overlord"
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $ExistingTask) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Out-Null
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    # Restaurar Suspension Selectiva de USB (Habilitar por defecto)
    try {
        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a8713cd-255e-4fc5-a639-12b87a5b3e8a d874b2c9-943b-47dd-9190-25e0e3c95a12 1 2>$null | Out-Null
        $ActivePlan = powercfg /getactivescheme 2>$null
        if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
            $CurrentGuid = $Matches[1]
            & powercfg /setactive $CurrentGuid 2>$null | Out-Null
        }
    } catch {}

    # Intento de re-registro de aplicaciones AppX provisionadas del sistema eliminadas durante el debloat
    $AppsToRestore = @(
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
    foreach ($App in $AppsToRestore) {
        try {
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $App -or $_.PackageName -match $App } | ForEach-Object {
                $ManifestPath = Join-Path $_.InstallLocation "AppXManifest.xml" -ErrorAction SilentlyContinue
                if ($ManifestPath -and (Test-Path $ManifestPath)) {
                    Add-AppxPackage -DisableDevelopmentMode -Register $ManifestPath -ErrorAction SilentlyContinue | Out-Null
                }
            }
        } catch {}
    }

    if (Test-Path $BackupPath) { Remove-Item -Path $BackupPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }

    # Eliminar la clave padre principal si queda vacía tras la reversión para no dejar huella
    $OverlordKey = "HKLM:\SOFTWARE\Overlord"
    if (Test-Path $OverlordKey) {
        $Subkeys = Get-ChildItem -Path $OverlordKey -ErrorAction SilentlyContinue
        if ($null -eq $Subkeys -or $Subkeys.Count -eq 0) {
            Remove-Item -Path $OverlordKey -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

    Write-Host "[+] Reversion completa de Overlord finalizada con exito."
    Write-Host "Reiniciando el entorno del Explorador de Windows..."
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe | Out-Null
    }
    exit 0

} Catch {
    Write-Error "[-] Error fatal durante la ejecucion de la reversion: $($_.Exception.Message)"
    exit 1
}