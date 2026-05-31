param(
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)

$ErrorActionPreference = "SilentlyContinue"

$BackupManagerPath = Join-Path $PSScriptRoot "backup_manager.psm1"
if (Test-Path $BackupManagerPath) {
    Import-Module $BackupManagerPath -Force
}

Try {
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"

    $MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    $KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    
    if (Get-Command Restore-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Restore-OverlordRegistryValue -TargetKey $MouPath -ValueName "MouseDataQueueSize" -BackupSubFolder "mouclass"
        Restore-OverlordRegistryValue -TargetKey $KbdPath -ValueName "KeyboardDataQueueSize" -BackupSubFolder "kbdclass"
    } else {
        Set-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -Type DWord -Value 100
        Set-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -Type DWord -Value 100
    }

    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    $PerfBackup = "$BackupPath\Performance"
    if (Test-Path $PerfBackup) {
        $OrigPrioritySep = (Get-ItemProperty -Path $PerfBackup -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue).Win32PrioritySeparation
        if ($OrigPrioritySep -ne $null -and $OrigPrioritySep -notmatch '_ABSENT_') {
            Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value $OrigPrioritySep
        } else {
            Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 2
        }
    } else {
        Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 2
    }

    $MsiBackupKey = "$BackupPath\MSI"
    if (Test-Path $MsiBackupKey) {
        $Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters" -ErrorAction SilentlyContinue
        foreach ($Device in $Devices) {
            $Class = (Get-ItemProperty -Path $Device.PSParentPath -ErrorAction SilentlyContinue).Class
            if ($Class -eq "Display" -or $Class -eq "USB") {
                $DeviceID = ($Device.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
                $MsiPath = "$($Device.PSPath)\Interrupt Management\MessageSignaledInterruptProperties"
                $SavedMsi = (Get-ItemProperty -Path $MsiBackupKey -Name $DeviceID -ErrorAction SilentlyContinue).$DeviceID
                
                if ($SavedMsi -ne $null) {
                    if ($SavedMsi -eq '_ABSENT_') {
                        Remove-Item -Path "$($Device.PSPath)\Interrupt Management" -Recurse -Force -ErrorAction SilentlyContinue
                    } else {
                        if (!(Test-Path $MsiPath)) { New-Item -Path $MsiPath -Force | Out-Null }
                        Set-ItemProperty -Path $MsiPath -Name "MSISupported" -Type DWord -Value $SavedMsi
                    }
                }
            }
        }
    }

    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "1"
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "6"
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "10"
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510"
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "62"
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126"

    $TelemetryBackup = "$BackupPath\Telemetry"
    if (Test-Path $TelemetryBackup) {
        $OrigTele = (Get-ItemProperty -Path $TelemetryBackup -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry
        if ($OrigTele -ne $null -and $OrigTele -notmatch '_ABSENT_') {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value $OrigTele
        } else {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 3
        }
    } else {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 3
    }

    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Type DWord -Value 1

    Remove-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue

    $Tasks = @(
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "Microsoft\Windows\Autochk\Proxy"
    )
    foreach ($Task in $Tasks) { Enable-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue }

    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $NetworkBackup = "$BackupPath\Network"

    Remove-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -ErrorAction SilentlyContinue

    if (Test-Path $NetworkBackup) {
        $SavedWaitDelay = (Get-ItemProperty -Path $NetworkBackup -Name "TcpTimedWaitDelay" -ErrorAction SilentlyContinue).TcpTimedWaitDelay
        if ($SavedWaitDelay -eq '_ABSENT_') { Remove-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay" } elseif ($SavedWaitDelay -ne $null) { Set-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay" -Type DWord -Value $SavedWaitDelay }

        $SavedThrot = (Get-ItemProperty -Path $NetworkBackup -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
        if ($SavedThrot -eq '_ABSENT_') { Remove-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" } elseif ($SavedThrot -ne $null) { Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value $SavedThrot }
    }

    Enable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
    Enable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh interface ipv6 teredo set state default | Out-Null
    netsh interface ipv6 isatap set state default | Out-Null

    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\FTH" -Name "Enabled" -Type DWord -Value 1

    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if (Test-Path $PerfBackup) {
        $SavedClearPage = (Get-ItemProperty -Path $PerfBackup -Name "ClearPageFileAtShutdown" -ErrorAction SilentlyContinue).ClearPageFileAtShutdown
        if ($SavedClearPage -eq '_ABSENT_') { Remove-ItemProperty -Path $MemPath -Name "ClearPageFileAtShutdown" } elseif ($SavedClearPage -ne $null) { Set-ItemProperty -Path $MemPath -Name "ClearPageFileAtShutdown" -Type DWord -Value $SavedClearPage }
    }
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe" -Recurse -Force -ErrorAction SilentlyContinue

    $GpuBackup = "$BackupPath\GPU"
    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $DwmMpoPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"

    if (Test-Path $GpuBackup) {
        $SavedHags = (Get-ItemProperty -Path $GpuBackup -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
        if ($SavedHags -ne $null -and $SavedHags -ne '_ABSENT_') { Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value $SavedHags }

        $SavedMpo = (Get-ItemProperty -Path $GpuBackup -Name "OverlayTestMode" -ErrorAction SilentlyContinue).OverlayTestMode
        if ($SavedMpo -eq '_ABSENT_') { Remove-ItemProperty -Path $DwmMpoPath -Name "OverlayTestMode" } elseif ($SavedMpo -ne $null) { Set-ItemProperty -Path $DwmMpoPath -Name "OverlayTestMode" -Type DWord -Value $SavedMpo }
    }
    
    $FsoPath = "HKCU:\System\GameConfigStore"
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 0
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 0
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior" -Type DWord -Value 0
    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Recurse -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1

    $TasksPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8
    Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 2
    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "Medium"
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "Normal"

    $CpuBackup = "$BackupPath\CPU"
    $NetBackupKey = "$CpuBackup\NetworkAffinity"
    if (Test-Path $NetBackupKey) {
        $NetDevices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters" -ErrorAction SilentlyContinue
        foreach ($NDevice in $NetDevices) {
            $NClass = (Get-ItemProperty -Path $NDevice.PSParentPath -ErrorAction SilentlyContinue).Class
            if ($NClass -eq "Net" -or $NClass -eq "MEDIA") {
                $DeviceID = ($NDevice.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
                $AffinityPath = "$($NDevice.PSPath)\Interrupt Management\Affinity Policy"
                
                if ($NClass -eq "Net") {
                    $SavedPolicy = (Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Policy" -ErrorAction SilentlyContinue)."${DeviceID}_Policy"
                    $SavedOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Override" -ErrorAction SilentlyContinue)."${DeviceID}_Override"
                } else {
                    $SavedPolicy = (Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_AudioPolicy" -ErrorAction SilentlyContinue)."${DeviceID}_AudioPolicy"
                    $SavedOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_AudioOverride" -ErrorAction SilentlyContinue)."${DeviceID}_AudioOverride"
                }
                
                if ($SavedPolicy -ne $null) {
                    if ($SavedPolicy -eq '_ABSENT_') { 
                        Remove-Item -Path $AffinityPath -Recurse -Force -ErrorAction SilentlyContinue
                    } else { 
                        Set-ItemProperty -Path $AffinityPath -Name "DevicePolicy" -Type DWord -Value $SavedPolicy 
                    }
                    
                    if ($SavedOverride -and $SavedOverride -notmatch '_ABSENT_') { 
                        Set-ItemProperty -Path $AffinityPath -Name "AssignmentSetOverride" -Type Binary -Value $SavedOverride 
                    } else { 
                        Remove-ItemProperty -Path $AffinityPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                    }
                }
            }
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
        
        if ($SavedLastAccess -ne $null -and $SavedLastAccess -ne '_ABSENT_') { Set-ItemProperty -Path $FileSystemPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value $SavedLastAccess }
        if ($SavedMemoryUsage -ne $null -and $SavedMemoryUsage -ne '_ABSENT_') { Set-ItemProperty -Path $FileSystemPath -Name "NtfsMemoryUsage" -Type DWord -Value $SavedMemoryUsage }
        if ($SavedHiberboot -eq '_ABSENT_') { Remove-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled" } elseif ($SavedHiberboot -ne $null) { Set-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled" -Type DWord -Value $SavedHiberboot }
        
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
            Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value $SavedPrefetch 
        } else { 
            Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 3 
        }
        
        if ($SavedSuperfetch -ne $null -and $SavedSuperfetch -notmatch '_ABSENT_') { 
            Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value $SavedSuperfetch 
        } else { 
            Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 3 
        }
    } else {
        Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 3
        Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 3
    }

    $PowerBackup = "$BackupPath\Power"
    if (Test-Path $PowerBackup) {
        $SavedActiveGuid = (Get-ItemProperty -Path $PowerBackup -Name "ActivePowerPlan" -ErrorAction SilentlyContinue).ActivePowerPlan
        $SavedUsbSuspend = (Get-ItemProperty -Path $PowerBackup -Name "DisableSelectiveSuspend" -ErrorAction SilentlyContinue).DisableSelectiveSuspend
        $UsbHubPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USB"
        
        if ($SavedUsbSuspend -eq '_ABSENT_') { Remove-ItemProperty -Path $UsbHubPath -Name "DisableSelectiveSuspend" } elseif ($SavedUsbSuspend -ne $null) { Set-ItemProperty -Path $UsbHubPath -Name "DisableSelectiveSuspend" -Type DWord -Value $SavedUsbSuspend }

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
        if ($SavedVbs -ne $null -and $SavedVbs -ne '_ABSENT_') { Set-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value $SavedVbs }
        if ($SavedHvci -ne $null -and $SavedHvci -ne '_ABSENT_') { Set-ItemProperty -Path $HvciPath -Name "Enabled" -Type DWord -Value $SavedHvci }
    }
    
    Set-Service "DiagTrack" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service "DiagTrack" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 1
    Get-NetFirewallRule -DisplayName "Overlord_Block_*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @("AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog", "SetupPlatformTel", "WdiContextLog")
    foreach ($Logger in $Loggers) {
        if (Test-Path "$LoggersPath\$Logger") { Set-ItemProperty -Path "$LoggersPath\$Logger" -Name "Start" -Type DWord -Value 1 -ErrorAction SilentlyContinue }
    }

    $PowerSettingsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    if (Test-Path $PowerBackup) {
        $SavedMax = (Get-ItemProperty -Path $PowerBackup -Name "ValueMax" -ErrorAction SilentlyContinue).ValueMax
        $SavedMin = (Get-ItemProperty -Path $PowerBackup -Name "ValueMin" -ErrorAction SilentlyContinue).ValueMin
        if ($SavedMax -ne $null -and $SavedMax -ne '_ABSENT_') { Set-ItemProperty -Path $PowerSettingsPath -Name "ValueMax" -Type DWord -Value $SavedMax }
        if ($SavedMin -ne $null -and $SavedMin -ne '_ABSENT_') { Set-ItemProperty -Path $PowerSettingsPath -Name "ValueMin" -Type DWord -Value $SavedMin }
    }

    $GameHooksBackup = "$BackupPath\GameHooks"
    if (Test-Path $GameHooksBackup) {
        $HookedGames = Get-ItemProperty -Path $GameHooksBackup -ErrorAction SilentlyContinue
        foreach ($Prop in $HookedGames.PSObject.Properties) {
            if ($Prop.Name -match "_CpuPriority$") {
                $GName = $Prop.Name -replace "_CpuPriority$", ""
                Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$GName" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Remove-Item -Path "HKLM:\SOFTWARE\Overlord" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "Reiniciando explorador de Windows..."
    Stop-Process -Name explorer -Force
    exit 0
} Catch {
    Write-Error "[-] Error critico durante la reversion de fabrica: $_"
    exit 1
}