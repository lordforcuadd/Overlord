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
    if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Restore-OverlordRegistryValue -TargetKey $TargetKey -ValueName $ValueName -BackupSubFolder $BackupSubFolder | Out-Null
    }
    if (Test-Path $TargetKey) {
        $CurrentVal = (Get-ItemProperty -Path $TargetKey -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
        if ($null -eq $CurrentVal -and $null -ne $DefaultValue) {
            Set-ItemProperty -Path $TargetKey -Name $ValueName -Type $DefaultType -Value $DefaultValue -Force | Out-Null
        }
    } elseif ($null -ne $DefaultValue) {
        New-Item -Path $TargetKey -Force | Out-Null
        Set-ItemProperty -Path $TargetKey -Name $ValueName -Type $DefaultType -Value $DefaultValue -Force | Out-Null
    }
}

Try {
    Write-Host "[*] Iniciando reversion simetrica de Overlord con helpers globales..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    $MsiBackupKey = "$BackupPath\MSI"
    $NetBackupKey = "$BackupPath\CPU\NetworkAffinity"
    $GameHooksBackup = "$BackupPath\GameHooks"

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -ValueName "MouseDataQueueSize" -BackupSubFolder "mouclass" -DefaultValue 100
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -ValueName "KeyboardDataQueueSize" -BackupSubFolder "kbdclass" -DefaultValue 100
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ValueName "Win32PrioritySeparation" -BackupSubFolder "Performance" -DefaultValue 2

    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed"      -Type String -Value "1"  -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "6"  -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "10" -Force | Out-Null
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -ErrorAction SilentlyContinue | Out-Null

    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys"        -Name "Flags" -Type String -Value "510" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys"        -Name "Flags" -Type String -Value "62"  -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126" -Force | Out-Null

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

                        if ($class -eq "Display" -or $class -eq "USB") {
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
                            }
                        }

                        if ($class -eq "Net" -or $class -eq "MEDIA") {
                            if (Test-Path $NetBackupKey) {
                                $savedPolicy = $null
                                $savedOverride = $null
                                if ($class -eq "Net") {
                                    $savedPolicy   = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Policy"   -ErrorAction SilentlyContinue)."${deviceRegID}_Policy"
                                    $savedOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Override" -ErrorAction SilentlyContinue)."${deviceRegID}_Override"
                                } else {
                                    $savedPolicy   = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_AudioPolicy"   -ErrorAction SilentlyContinue)."${deviceRegID}_AudioPolicy"
                                    $savedOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_AudioOverride" -ErrorAction SilentlyContinue)."${deviceRegID}_AudioOverride"
                                }

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
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "BingSearchEnabled" -BackupSubFolder "Telemetry" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "CortanaConsent" -BackupSubFolder "Telemetry" -DefaultValue 1
    Remove-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"  -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue | Out-Null

    $StartTypeMap = @{ 2 = "Automatic"; 3 = "Manual"; 4 = "Disabled" }
    $ServicesFallback = @{
        "DiagTrack"        = "Automatic"
        "dmwappushservice" = "Manual"
        "Spooler"          = "Automatic"
        "Fax"              = "Manual"
        "RetailDemo"       = "Disabled"
        "MapsBroker"       = "Automatic"
        "PhoneSvc"         = "Manual"
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

    Get-NetFirewallRule -DisplayName "Overlord_Block_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue | Out-Null

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

    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheTtl" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxNegativeCacheTtl" -ErrorAction SilentlyContinue | Out-Null
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -ValueName "TcpTimedWaitDelay" -BackupSubFolder "Network" -DefaultValue 30
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ValueName "NetworkThrottlingIndex" -BackupSubFolder "Network" -DefaultValue 10

    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global timestamps=enabled | Out-Null
    netsh interface ipv6 teredo set state default | Out-Null
    netsh interface ipv6 isatap set state default  | Out-Null

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "DisablePagingExecutive" -BackupSubFolder "Performance" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "ClearPageFileAtShutdown" -BackupSubFolder "Performance" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "FeatureSettingsOverride" -BackupSubFolder "Performance" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "FeatureSettingsOverrideMask" -BackupSubFolder "Performance" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\System\GameConfigStore" -ValueName "GameDVR_Enabled" -BackupSubFolder "Performance" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\Software\Microsoft\FTH" -ValueName "Enabled" -BackupSubFolder "Performance" -DefaultValue 1
    Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ValueName "HwSchMode" -BackupSubFolder "GPU" -DefaultValue 2
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -ValueName "OverlayTestMode" -BackupSubFolder "GPU" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" -ValueName "CpuPriorityClass" -BackupSubFolder "GPU" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\DWM" -ValueName "ColorPrevalence" -BackupSubFolder "GPU" -DefaultValue 1
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ValueName "EnableTransparency" -BackupSubFolder "GPU" -DefaultValue 1
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -ErrorAction SilentlyContinue | Out-Null

    Invoke-OverlordSafeRestore -TargetKey "HKCU:\System\GameConfigStore" -ValueName "GameDVR_FSEBehaviorMode" -BackupSubFolder "GPU" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\System\GameConfigStore" -ValueName "GameDVR_HonorUserFSEBehaviorMode" -BackupSubFolder "GPU" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey "HKCU:\System\GameConfigStore" -ValueName "GameDVR_FSEBehavior" -BackupSubFolder "GPU" -DefaultValue 0

    $TasksPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Invoke-OverlordSafeRestore -TargetKey $TasksPath -ValueName "GPU Priority" -BackupSubFolder "CPU" -DefaultValue 8
    Invoke-OverlordSafeRestore -TargetKey $TasksPath -ValueName "Priority" -BackupSubFolder "CPU" -DefaultValue 2
    Invoke-OverlordSafeRestore -TargetKey $TasksPath -ValueName "Scheduling Category" -BackupSubFolder "CPU" -DefaultValue "Medium" -DefaultType "String"
    Invoke-OverlordSafeRestore -TargetKey $TasksPath -ValueName "SFIO Priority" -BackupSubFolder "CPU" -DefaultValue "Normal" -DefaultType "String"

    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    $FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "NtfsDisableLastAccessUpdate" -BackupSubFolder "Storage" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $NtfsPath -ValueName "NtfsMemoryUsage" -BackupSubFolder "Storage" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $PrefetchPath -ValueName "EnablePrefetcher" -BackupSubFolder "Storage" -DefaultValue 3
    Invoke-OverlordSafeRestore -TargetKey $PrefetchPath -ValueName "EnableSuperfetch" -BackupSubFolder "Storage" -DefaultValue 3
    Invoke-OverlordSafeRestore -TargetKey $MemPath -ValueName "LargeSystemCache" -BackupSubFolder "Storage" -DefaultValue 0
    Invoke-OverlordSafeRestore -TargetKey $FastStartPath -ValueName "HiberbootEnabled" -BackupSubFolder "Storage" -DefaultValue 1
    
    fsutil behavior set disablelastaccess 0 | Out-Null
    fsutil behavior set disable8dot3 0 | Out-Null

    Invoke-OverlordSafeRestore -TargetKey "HKLM:\System\CurrentControlSet\Control\DeviceGuard" -ValueName "EnableVirtualizationBasedSecurity" -BackupSubFolder "Telemetry" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -ValueName "Enabled" -BackupSubFolder "Telemetry" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -ValueName "PublishUserActivities" -BackupSubFolder "Telemetry" -DefaultValue 1

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @("AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog")
    foreach ($Logger in $Loggers) {
        Invoke-OverlordSafeRestore -TargetKey "$LoggersPath\$Logger" -ValueName "Start" -BackupSubFolder "Telemetry" -DefaultValue 1
    }

    $PowerBackup = "$BackupPath\Power"
    if (Test-Path $PowerBackup) {
    $SavedActiveGuid = (Get-ItemProperty -Path $PowerBackup -Name "ActivePowerPlan" -ErrorAction SilentlyContinue).ActivePowerPlan
    $CustomPlanGuid = (Get-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -ErrorAction SilentlyContinue).CustomPowerPlan

    if (![string]::IsNullOrWhiteSpace($CustomPlanGuid)) { powercfg /delete $CustomPlanGuid 2>$null | Out-Null }
    if (![string]::IsNullOrWhiteSpace($SavedActiveGuid)) {
        powercfg /setactive $SavedActiveGuid 2>$null | Out-Null
    } else {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null
    }

    $PowerSettingsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    Invoke-OverlordSafeRestore -TargetKey $PowerSettingsPath -ValueName "ValueMax" -BackupSubFolder "Power" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey $PowerSettingsPath -ValueName "ValueMin" -BackupSubFolder "Power" -DefaultValue $null
    Invoke-OverlordSafeRestore -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -ValueName "DisableSelectiveSuspend" -BackupSubFolder "Power" -DefaultValue $null
    }

   $SavedHibernate = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -ErrorAction SilentlyContinue).HibernateEnabled
   if ($null -ne $SavedHibernate -and $SavedHibernate -ne '_ABSENT_') {
    if ($SavedHibernate -eq 0) { powercfg.exe /hibernate off | Out-Null } else { powercfg.exe /hibernate on | Out-Null }
      } elseif (-not $IsLaptop) {
    powercfg.exe /hibernate on | Out-Null
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

    $GlobalAppData = Join-Path $env:LOCALAPPDATA "*"
    Get-ChildItem -Path $GlobalAppData -Filter "GameUserSettings.ini" -Recurse -Depth 5 -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.IsReadOnly) { Set-ItemProperty -Path $_.FullName -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue | Out-Null }
    }

    if (Test-Path $BackupPath) { Remove-Item -Path $BackupPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }

    Write-Host "[+] Reversion completa de Overlord finalizada con exito."
    Write-Host "Reiniciando el entorno del Explorador de Windows..."
    Stop-Process -Name explorer -Force
    exit 0

} Catch {
    Write-Error "[-] Error fatal durante la ejecucion de la reversion: $_"
    exit 1
}