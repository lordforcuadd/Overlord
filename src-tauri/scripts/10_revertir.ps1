param(
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    $MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    $KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    
    if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Restore-OverlordRegistryValue -TargetKey $MouPath -ValueName "MouseDataQueueSize" -BackupSubFolder "mouclass" -ErrorAction SilentlyContinue
        Restore-OverlordRegistryValue -TargetKey $KbdPath -ValueName "KeyboardDataQueueSize" -BackupSubFolder "kbdclass" -ErrorAction SilentlyContinue
        
        $ServicesList = @("DiagTrack", "dmwappushservice", "Fax", "RetailDemo", "MapsBroker", "PhoneSvc", "Spooler")
        foreach ($Svc in $ServicesList) {
            Restore-OverlordRegistryValue -TargetKey "HKLM:\SYSTEM\CurrentControlSet\Services\$Svc" -ValueName "Start" -BackupSubFolder "Services" -ErrorAction SilentlyContinue
        }
    } else {
        Set-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -Type DWord -Value 100 -Force | Out-Null
        Set-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -Type DWord -Value 100 -Force | Out-Null
    }

    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    $PerfBackup = "$BackupPath\Performance"
    if (Test-Path $PerfBackup) {
        $OrigPrioritySep = (Get-ItemProperty -Path $PerfBackup -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue).Win32PrioritySeparation
        if ($OrigPrioritySep -ne $null -and $OrigPrioritySep -notmatch '_ABSENT_') {
            Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value $OrigPrioritySep -Force | Out-Null
        } else {
            Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 2 -Force | Out-Null
        }
    } else {
        Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 2 -Force | Out-Null
    }

    $MsiBackupKey = "$BackupPath\MSI"
    if (Test-Path $MsiBackupKey) {
        $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $true)
        if ($pciKey) {
            foreach ($venId in $pciKey.GetSubKeyNames()) {
                $venKey = $pciKey.OpenSubKey($venId, $true)
                if ($venKey) {
                    foreach ($devId in $venKey.GetSubKeyNames()) {
                        $devKey = $venKey.OpenSubKey($devId, $true)
                        if ($devKey) {
                            $class = $devKey.GetValue("Class")
                            if ($class -eq "Display" -or $class -eq "USB") {
                                $deviceRegID = "PCI_$venId`_$devId`_Device Parameters"
                                $savedMsi = (Get-ItemProperty -Path $MsiBackupKey -Name $deviceRegID -ErrorAction SilentlyContinue).$deviceRegID
                                
                                if ($null -ne $savedMsi) {
                                    if ($savedMsi -eq '_ABSENT_') {
                                        $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                                        if ($paramKey) {
                                            $paramKey.DeleteSubKeyTree("Interrupt Management", $false)
                                            $paramKey.Close()
                                        }
                                    } else {
                                        $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                                        if ($paramKey) {
                                            $interruptKey = $paramKey.CreateSubKey("Interrupt Management\MessageSignaledInterruptProperties", $true)
                                            if ($interruptKey) {
                                                $interruptKey.SetValue("MSISupported", $savedMsi, [Microsoft.Win32.RegistryValueKind]::DWord)
                                                $interruptKey.Close()
                                            }
                                            $paramKey.Close()
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
    }

    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "1" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "6" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "10" -Force | Out-Null
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -ErrorAction SilentlyContinue | Out-Null

    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "62" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126" -Force | Out-Null

    $TelemetryBackup = "$BackupPath\Telemetry"
    if (Test-Path $TelemetryBackup) {
        $OrigTele = (Get-ItemProperty -Path $TelemetryBackup -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry
        if ($OrigTele -ne $null -and $OrigTele -notmatch '_ABSENT_') {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value $OrigTele -Force | Out-Null
        } else {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 3 -Force | Out-Null
        }
    } else {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 3 -Force | Out-Null
    }

    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Type DWord -Value 1 -Force | Out-Null

    Remove-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue | Out-Null

    $ServicesList = @("DiagTrack", "dmwappushservice", "Spooler")
    foreach ($Svc in $ServicesList) {
        Start-Service -Name $Svc -ErrorAction SilentlyContinue
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

    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $NetworkBackup = "$BackupPath\Network"

    Remove-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -ErrorAction SilentlyContinue | Out-Null

    if (Test-Path $NetworkBackup) {
        $SavedWaitDelay = (Get-ItemProperty -Path $NetworkBackup -Name "TcpTimedWaitDelay" -ErrorAction SilentlyContinue).TcpTimedWaitDelay
        if ($SavedWaitDelay -eq '_ABSENT_') { Remove-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay" -ErrorAction SilentlyContinue | Out-Null } elseif ($SavedWaitDelay -ne $null) { Set-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay" -Type DWord -Value $SavedWaitDelay -Force | Out-Null }

        $SavedThrot = (Get-ItemProperty -Path $NetworkBackup -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
        if ($SavedThrot -eq '_ABSENT_') { Remove-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue | Out-Null } elseif ($SavedThrot -ne $null) { Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value $SavedThrot -Force | Out-Null }
    }

    Enable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue | Out-Null
    Enable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue | Out-Null
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh interface ipv6 teredo set state default | Out-Null
    netsh interface ipv6 isatap set state default | Out-Null

    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\FTH" -Name "Enabled" -Type DWord -Value 1 -Force | Out-Null

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if (Test-Path $PerfBackup) {
        $SavedClearPage = (Get-ItemProperty -Path $PerfBackup -Name "ClearPageFileAtShutdown" -ErrorAction SilentlyContinue).ClearPageFileAtShutdown
        if ($SavedClearPage -eq '_ABSENT_') { Remove-ItemProperty -Path $MemPath -Name "ClearPageFileAtShutdown" -ErrorAction SilentlyContinue | Out-Null } elseif ($SavedClearPage -ne $null) { Set-ItemProperty -Path $MemPath -Name "ClearPageFileAtShutdown" -Type DWord -Value $SavedClearPage -Force | Out-Null }
    }
    Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

    $GpuBackup = "$BackupPath\GPU"
    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $DwmMpoPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    $DwmOptionsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"

    if (Test-Path $GpuBackup) {
        $SavedHags = (Get-ItemProperty -Path $GpuBackup -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
        if ($SavedHags -ne $null -and $SavedHags -ne '_ABSENT_') { Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value $SavedHags -Force | Out-Null }

        $SavedMpo = (Get-ItemProperty -Path $GpuBackup -Name "OverlayTestMode" -ErrorAction SilentlyContinue).OverlayTestMode
        if ($SavedMpo -eq '_ABSENT_') { Remove-ItemProperty -Path $DwmMpoPath -Name "OverlayTestMode" -ErrorAction SilentlyContinue | Out-Null } elseif ($SavedMpo -ne $null) { Set-ItemProperty -Path $DwmMpoPath -Name "OverlayTestMode" -Type DWord -Value $SavedMpo -Force | Out-Null }

        $SavedDwmPriority = (Get-ItemProperty -Path $GpuBackup -Name "CpuPriorityClass" -ErrorAction SilentlyContinue).CpuPriorityClass
        if ($SavedDwmPriority -eq '_ABSENT_') { Remove-ItemProperty -Path $DwmOptionsPath -Name "CpuPriorityClass" -ErrorAction SilentlyContinue | Out-Null } elseif ($SavedDwmPriority -ne $null) { Set-ItemProperty -Path $DwmOptionsPath -Name "CpuPriorityClass" -Type DWord -Value $SavedDwmPriority -Force | Out-Null }
    }
    
    $FsoPath = "HKCU:\System\GameConfigStore"
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior" -Type DWord -Value 0 -Force | Out-Null
    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1 -Force | Out-Null

    $TasksPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8 -Force | Out-Null
    Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 2 -Force | Out-Null
    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "Medium" -Force | Out-Null
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "Normal" -Force | Out-Null

    $CpuBackup = "$BackupPath\CPU"
    $NetBackupKey = "$CpuBackup\NetworkAffinity"
    if (Test-Path $NetBackupKey) {
        $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $true)
        if ($pciKey) {
            foreach ($venId in $pciKey.GetSubKeyNames()) {
                $venKey = $pciKey.OpenSubKey($venId, $true)
                if ($venKey) {
                    foreach ($devId in $venKey.GetSubKeyNames()) {
                        $devKey = $venKey.OpenSubKey($devId, $true)
                        if ($devKey) {
                            $class = $devKey.GetValue("Class")
                            if ($class -eq "Net" -or $class -eq "MEDIA") {
                                $deviceRegID = "PCI_$venId`_$devId`_Device Parameters"
                                
                                if ($class -eq "Net") {
                                    $savedPolicy = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Policy" -ErrorAction SilentlyContinue)."${deviceRegID}_Policy"
                                    $savedOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Override" -ErrorAction SilentlyContinue)."${deviceRegID}_Override"
                                } else {
                                    $savedPolicy = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_AudioPolicy" -ErrorAction SilentlyContinue)."${deviceRegID}_AudioPolicy"
                                    $savedOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_AudioOverride" -ErrorAction SilentlyContinue)."${deviceRegID}_AudioOverride"
                                }
                                
                                if ($null -ne $savedPolicy) {
                                    $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                                    if ($paramKey) {
                                        if ($savedPolicy -eq '_ABSENT_') {
                                            $paramKey.DeleteSubKeyTree("Interrupt Management", $false)
                                        } else {
                                            $affinityKey = $paramKey.CreateSubKey("Interrupt Management\Affinity Policy", $true)
                                            if ($affinityKey) {
                                                $affinityKey.SetValue("DevicePolicy", $savedPolicy, [Microsoft.Win32.RegistryValueKind]::DWord)
                                                if ($null -ne $savedOverride -and $savedOverride -notmatch '_ABSENT_') {
                                                    $affinityKey.SetValue("AssignmentSetOverride", $savedOverride, [Microsoft.Win32.RegistryValueKind]::Binary)
                                                } else {
                                                    $affinityKey.DeleteValue("AssignmentSetOverride", $false)
                                                }
                                                $affinityKey.Close()
                                            }
                                        }
                                        $paramKey.Close()
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
    }

    $StorageBackup = "$BackupPath\Storage"
    $FileSystemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    if (Test-Path $StorageBackup) {
        $SavedLastAccess = (Get-ItemProperty -Path $StorageBackup -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
        $SavedMemoryUsage = (Get-ItemProperty -Path $StorageBackup -Name "NtfsMemoryUsage" -ErrorAction SilentlyContinue).NtfsMemoryUsage
        $SavedHibernate = (Get-ItemProperty -Path $StorageBackup -Name "HibernateEnabled" -ErrorAction SilentlyContinue).HibernateEnabled
        $SavedHiberboot = (Get-ItemProperty -Path $StorageBackup -Name "HiberbootEnabled" -ErrorAction SilentlyContinue).HiberbootEnabled
        
        if ($SavedLastAccess -ne $null -and $SavedLastAccess -ne '_ABSENT_') { Set-ItemProperty -Path $FileSystemPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value $SavedLastAccess -Force | Out-Null }
        if ($SavedMemoryUsage -ne $null -and $SavedMemoryUsage -ne '_ABSENT_') { Set-ItemProperty -Path $FileSystemPath -Name "NtfsMemoryUsage" -Type DWord -Value $SavedMemoryUsage -Force | Out-Null }
        if ($SavedHiberboot -eq '_ABSENT_') { Remove-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled" -ErrorAction SilentlyContinue | Out-Null } elseif ($SavedHiberboot -ne $null) { Set-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled" -Type DWord -Value $SavedHiberboot -Force | Out-Null }
        
        if ($SavedHibernate -ne $null -and $SavedHibernate -notmatch '_ABSENT_') {
            if ($SavedHibernate -eq 0) { powercfg.exe /hibernate off | Out-Null } else { powercfg.exe /hibernate on | Out-Null }
        } elseif (-not $IsLaptop) {
            powercfg.exe /hibernate on | Out-Null
        }
    } else {
        fsutil behavior set disable8dot3 0 | Out-Null
        if (-not $IsLaptop) { powercfg.exe /hibernate on | Out-Null }
    }
    
    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    if (Test-Path $StorageBackup) {
        $SavedPrefetch = (Get-ItemProperty -Path $StorageBackup -Name "EnablePrefetcher" -ErrorAction SilentlyContinue).EnablePrefetcher
        $SavedSuperfetch = (Get-ItemProperty -Path $StorageBackup -Name "EnableSuperfetch" -ErrorAction SilentlyContinue).EnableSuperfetch
        
        if ($SavedPrefetch -ne $null -and $SavedPrefetch -notmatch '_ABSENT_') { 
            Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value $SavedPrefetch -Force | Out-Null
        } else { 
            Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 3 -Force | Out-Null
        }
        
        if ($SavedSuperfetch -ne $null -and $SavedSuperfetch -notmatch '_ABSENT_') { 
            Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value $SavedSuperfetch -Force | Out-Null
        } else { 
            Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 3 -Force | Out-Null
        }
    } else {
        Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 3 -Force | Out-Null
        Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 3 -Force | Out-Null
    }

    $PowerBackup = "$BackupPath\Power"
    if (Test-Path $PowerBackup) {
        $customActivePlan = (Get-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -ErrorAction SilentlyContinue).CustomPowerPlan
        if ($null -ne $customActivePlan -and $customActivePlan -notmatch '_ABSENT_') {
            powercfg /delete $customActivePlan | Out-Null
        }
        
        $SavedActiveGuid = (Get-ItemProperty -Path $PowerBackup -Name "ActivePowerPlan" -ErrorAction SilentlyContinue).ActivePowerPlan
        $SavedUsbSuspend = (Get-ItemProperty -Path $PowerBackup -Name "DisableSelectiveSuspend" -ErrorAction SilentlyContinue).DisableSelectiveSuspend
        $UsbHubPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USB"
        
        if ($SavedUsbSuspend -eq '_ABSENT_') { Remove-ItemProperty -Path $UsbHubPath -Name "DisableSelectiveSuspend" -ErrorAction SilentlyContinue | Out-Null } elseif ($SavedUsbSuspend -ne $null) { Set-ItemProperty -Path $UsbHubPath -Name "DisableSelectiveSuspend" -Type DWord -Value $SavedUsbSuspend -Force | Out-Null }

        if ($SavedActiveGuid -and $SavedActiveGuid -notmatch '_ABSENT_') {
            powercfg /SETACVALUEINDEX $SavedActiveGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 | Out-Null
            powercfg /SETDCVALUEINDEX $SavedActiveGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 | Out-Null
            powercfg.exe /setactive $SavedActiveGuid | Out-Null
        } else {
            powercfg.exe /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
        }
    } else {
        powercfg.exe /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
    }

    $VbsPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard"
    $HvciPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (Test-Path $TelemetryBackup) {
        $SavedVbs = (Get-ItemProperty -Path $TelemetryBackup -Name "EnableVirtualizationBasedSecurity" -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
        $SavedHvci = (Get-ItemProperty -Path $TelemetryBackup -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
        if ($SavedVbs -ne $null -and $SavedVbs -ne '_ABSENT_') { Set-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value $SavedVbs -Force | Out-Null }
        if ($SavedHvci -ne $null -and $SavedHvci -ne '_ABSENT_') { Set-ItemProperty -Path $HvciPath -Name "Enabled" -Type DWord -Value $SavedHvci -Force | Out-Null }
    }
    
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 1 -Force | Out-Null
    Get-NetFirewallRule -DisplayName "Overlord_Block_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue | Out-Null

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @("AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog", "SetupPlatformTel", "WdiContextLog")
    foreach ($Logger in $Loggers) {
        if (Test-Path "$LoggersPath\$Logger") { Set-ItemProperty -Path "$LoggersPath\$Logger" -Name "Start" -Type DWord -Value 1 -ErrorAction SilentlyContinue | Out-Null }
    }

    $PowerSettingsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    if (Test-Path $PowerBackup) {
        $SavedMax = (Get-ItemProperty -Path $PowerBackup -Name "ValueMax" -ErrorAction SilentlyContinue).ValueMax
        $SavedMin = (Get-ItemProperty -Path $PowerBackup -Name "ValueMin" -ErrorAction SilentlyContinue).ValueMin
        if ($SavedMax -ne $null -and $SavedMax -ne '_ABSENT_') { Set-ItemProperty -Path $PowerSettingsPath -Name "ValueMax" -Type DWord -Value $SavedMax -Force | Out-Null }
        if ($SavedMin -ne $null -and $SavedMin -ne '_ABSENT_') { Set-ItemProperty -Path $PowerSettingsPath -Name "ValueMin" -Type DWord -Value $SavedMin -Force | Out-Null }
    }

    $GameHooksBackup = "$BackupPath\GameHooks"
    if (Test-Path $GameHooksBackup) {
        $HookedGames = Get-ItemProperty -Path $GameHooksBackup -ErrorAction SilentlyContinue
        foreach ($Prop in $HookedGames.PSObject.Properties) {
            if ($Prop.Name -match "_CpuPriority$") {
                $GName = $Prop.Name -replace "_CpuPriority$", ""
                Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$GName" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    Remove-Item -Path "HKLM:\SOFTWARE\Overlord" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    
    Write-Host "Reiniciando explorador de Windows..."
    Stop-Process -Name explorer -Force
    exit 0
} Catch {
    Write-Error "[-] Error critico durante la reversion de fabrica: $_"
    exit 1
}