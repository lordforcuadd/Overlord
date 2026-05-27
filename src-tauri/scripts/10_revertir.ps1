param(
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)


Try {
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"

    $MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    $KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    $MouSize = 100
    $KbdSize = 100
    if (Test-Path "$BackupPath\mouclass") { $MouSize = (Get-ItemProperty -Path "$BackupPath\mouclass" -Name "MouseDataQueueSize").MouseDataQueueSize }
    if (Test-Path "$BackupPath\kbdclass") { $KbdSize = (Get-ItemProperty -Path "$BackupPath\kbdclass" -Name "KeyboardDataQueueSize").KeyboardDataQueueSize }
    Set-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -Type DWord -Value $MouSize
    Set-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -Type DWord -Value $KbdSize

    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    $OrigPrioritySep = (Get-ItemProperty -Path $BackupPath -Name "Win32PrioritySeparation").Win32PrioritySeparation
    if ($OrigPrioritySep -ne $null) {
        Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value $OrigPrioritySep
    } else {
        Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 2
    }

    $MsiBackupKey = "$BackupPath\MSI"
    if (Test-Path $MsiBackupKey) {
        $Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters"
        foreach ($Device in $Devices) {
            $Class = (Get-ItemProperty -Path $Device.PSParentPath).Class
            if ($Class -eq "Display" -or $Class -eq "USB") {
                $DeviceID = ($Device.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
                $MsiPath = "$($Device.PSPath)\Interrupt Management\MessageSignaledInterruptProperties"
                $SavedMsi = (Get-ItemProperty -Path $MsiBackupKey -Name $DeviceID).$DeviceID
                if ($SavedMsi -ne $null) {
                    if ($SavedMsi -eq 999) {
                        Remove-Item -Path "$($Device.PSPath)\Interrupt Management" -Recurse
                    } else {
                        Set-ItemProperty -Path $MsiPath -Name "MSISupported" -Type DWord -Value $SavedMsi
                    }
                }
            }
        }
    }

    bcdedit /deletevalue useplatformtick
    bcdedit /deletevalue disabledynamictick

    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "1"
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "6"
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "10"
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve"
    Remove-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve"

    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510"
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "62"
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126"

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Type DWord -Value 1

    $Tasks = @(
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "Microsoft\Windows\Autochk\Proxy"
    )
    foreach ($Task in $Tasks) { Enable-ScheduledTask -TaskName $Task }

    $NetBackup = "$BackupPath\Network"
    if (Test-Path $NetBackup) {
        $Interfaces = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        foreach ($Interface in $Interfaces) {
            $InterfaceBackupKey = "$NetBackup\$($Interface.SettingID)"
            $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
            if (Test-Path $InterfaceBackupKey) {
                $SavedAck = (Get-ItemProperty -Path $InterfaceBackupKey -Name "TcpAckFrequency").TcpAckFrequency
                $SavedDelay = (Get-ItemProperty -Path $InterfaceBackupKey -Name "TCPNoDelay").TCPNoDelay
                if ($SavedAck -eq 999) { Remove-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" } elseif ($SavedAck -ne $null) { Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -Type DWord -Value $SavedAck }
                if ($SavedDelay -eq 999) { Remove-ItemProperty -Path $TcpPath -Name "TCPNoDelay" } elseif ($SavedDelay -ne $null) { Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -Type DWord -Value $SavedDelay }
            }
        }
    }

    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    Remove-ItemProperty -Path $DnsPath -Name "MaxCacheTtl"
    Remove-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl"
    Enable-NetAdapterRsc -Name "*" -IPv4
    Enable-NetAdapterRsc -Name "*" -IPv6
    Enable-NetAdapterLso -Name "*" -IPv4
    Enable-NetAdapterLso -Name "*" -IPv6
    Enable-NetAdapterChecksumOffload -Name "*"
    netsh int tcp set global autotuninglevel=normal
    netsh int tcp set global ecncapability=default

    $PerfBackup = "$BackupPath\Performance"
    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if (Test-Path $PerfBackup) {
        $SavedPaging = (Get-ItemProperty -Path $PerfBackup -Name "DisablePagingExecutive").DisablePagingExecutive
        $SavedSpec = (Get-ItemProperty -Path $PerfBackup -Name "FeatureSettingsOverride").FeatureSettingsOverride
        $SavedMask = (Get-ItemProperty -Path $PerfBackup -Name "FeatureSettingsOverrideMask").FeatureSettingsOverrideMask
        if ($SavedPaging -ne $null) { Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value $SavedPaging }
        if ($SavedSpec -ne $null) { Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverride" -Type DWord -Value $SavedSpec }
        if ($SavedMask -ne $null) { Set-ItemProperty -Path $MemPath -Name "FeatureSettingsOverrideMask" -Type DWord -Value $SavedMask }
    }
    Enable-MMAgent -MemoryCompression
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\FTH" -Name "Enabled" -Type DWord -Value 1

    $GpuBackup = "$BackupPath\GPU"
    $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (Test-Path $GpuBackup) {
        $SavedHags = (Get-ItemProperty -Path $GpuBackup -Name "HwSchMode").HwSchMode
        if ($SavedHags -ne $null) { Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Type DWord -Value $SavedHags }
    }
    $FsoPath = "HKCU:\System\GameConfigStore"
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 0
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 0
    Set-ItemProperty -Path $FsoPath -Name "GameDVR_FSEBehavior" -Type DWord -Value 0
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Policies\Microsoft\Windows\GameDVR" -Recurse
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1

    $HdcpBackupKey = "$GpuBackup\HDCP"
    if (Test-Path $HdcpBackupKey) {
        $DisplayClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
        $Adapters = Get-ChildItem -Path $DisplayClass | Where-Object { $_.PSChildName -match '^\d{4}$' }
        foreach ($Adapter in $Adapters) {
            $AdapterID = $Adapter.PSChildName
            $SavedHdcp = (Get-ItemProperty -Path $HdcpBackupKey -Name $AdapterID).$AdapterID
            if ($SavedHdcp -ne $null) {
                if ($SavedHdcp -eq 999) { Remove-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" } else { Set-ItemProperty -Path $Adapter.PSPath -Name "RMHdcpKeyLocalZero" -Type DWord -Value $SavedHdcp }
            }
        }
    }

    $CpuBackup = "$BackupPath\CPU"
    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    if (Test-Path $CpuBackup) {
        $SavedResp = (Get-ItemProperty -Path $CpuBackup -Name "SystemResponsiveness").SystemResponsiveness
        $SavedThrot = (Get-ItemProperty -Path $CpuBackup -Name "NetworkThrottlingIndex").NetworkThrottlingIndex
        if ($SavedResp -ne $null) { Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Type DWord -Value $SavedResp }
        if ($SavedThrot -ne $null) { Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value $SavedThrot }
    }
    $TasksPath = "$ProfilePath\Tasks\Games"
    Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8
    Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 2
    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "Medium"
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "Normal"

    $NetBackupKey = "$CpuBackup\NetworkAffinity"
    if (Test-Path $NetBackupKey) {
        $NetDevices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters"
        foreach ($NDevice in $NetDevices) {
            $NClass = (Get-ItemProperty -Path $NDevice.PSParentPath).Class
            if ($NClass -eq "Net") {
                $DeviceID = ($NDevice.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
                $AffinityPath = "$($NDevice.PSPath)\Interrupt Management\Affinity Policy"
                $SavedPolicy = (Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Policy")."${DeviceID}_Policy"
                $SavedOverride = (Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Override")."${DeviceID}_Override"
                if ($SavedPolicy -ne $null) {
                    if ($SavedPolicy -eq 999) { Remove-Item -Path $AffinityPath -Recurse } else { Set-ItemProperty -Path $AffinityPath -Name "DevicePolicy" -Type DWord -Value $SavedPolicy }
                    if ($SavedOverride) { Set-ItemProperty -Path $AffinityPath -Name "AssignmentSetOverride" -Type Binary -Value $SavedOverride } else { Remove-ItemProperty -Path $AffinityPath -Name "AssignmentSetOverride" }
                }
            }
        }
    }

    $StorageBackup = "$BackupPath\Storage"
    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    if (Test-Path $StorageBackup) {
        $SavedLastAccess = (Get-ItemProperty -Path $StorageBackup -Name "NtfsDisableLastAccessUpdate").NtfsDisableLastAccessUpdate
        $SavedMemoryUsage = (Get-ItemProperty -Path $StorageBackup -Name "NtfsMemoryUsage").NtfsMemoryUsage
        if ($SavedLastAccess -ne $null) { Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value $SavedLastAccess }
        if ($SavedMemoryUsage -ne $null) { Set-ItemProperty -Path $NtfsPath -Name "NtfsMemoryUsage" -Type DWord -Value $SavedMemoryUsage }
    }
    fsutil behavior set disable8dot3 0
    powercfg.exe /hibernate on
    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 3
    Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 3

    $TelemetryBackup = "$BackupPath\Telemetry"
    $VbsPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard"
    $HvciPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (Test-Path $TelemetryBackup) {
        $SavedVbs = (Get-ItemProperty -Path $TelemetryBackup -Name "EnableVirtualizationBasedSecurity").EnableVirtualizationBasedSecurity
        $SavedHvci = (Get-ItemProperty -Path $TelemetryBackup -Name "Hvci_Enabled").Hvci_Enabled
        if ($SavedVbs -ne $null) { Set-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value $SavedVbs }
        if ($SavedHvci -ne $null) { Set-ItemProperty -Path $HvciPath -Name "Enabled" -Type DWord -Value $SavedHvci }
    }
    Set-Service "DiagTrack" -StartupType Automatic
    Start-Service "DiagTrack"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 1
    Get-NetFirewallRule -DisplayName "Overlord_Block_*" | Remove-NetFirewallRule

    $LoggersPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger"
    $Loggers = @("AutoLogger-Diagtrack-Listener", "SQMLogger", "DiagLog", "AitEventLog", "Circular Kernel Context Logger", "ReadyBoot", "SetupPlatformTel", "WdiContextLog")
    foreach ($Logger in $Loggers) {
        if (Test-Path "$LoggersPath\$Logger") { Set-ItemProperty -Path "$LoggersPath\$Logger" -Name "Start" -Type DWord -Value 1 }
    }

    $PowerBackup = "$BackupPath\Power"
    $PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    if (Test-Path $PowerBackup) {
        $SavedMax = (Get-ItemProperty -Path $PowerBackup -Name "ValueMax").ValueMax
        $SavedMin = (Get-ItemProperty -Path $PowerBackup -Name "ValueMin").ValueMin
        if ($SavedMax -ne $null) { Set-ItemProperty -Path $PowerPath -Name "ValueMax" -Type DWord -Value $SavedMax }
        if ($SavedMin -ne $null) { Set-ItemProperty -Path $PowerPath -Name "ValueMin" -Type DWord -Value $SavedMin }
    }
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e

    $GameHooksBackup = "$BackupPath\GameHooks"
    if (Test-Path $GameHooksBackup) {
        $HookedGames = Get-ItemProperty -Path $GameHooksBackup
        foreach ($Prop in $HookedGames.PSObject.Properties) {
            if ($Prop.Name -match "_CpuPriority$") {
                $GName = $Prop.Name -replace "_CpuPriority$", ""
                Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$GName" -Recurse
            }
        }
    }

    Remove-Item -Path "HKLM:\SOFTWARE\Overlord" -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Process -Name explorer -Force
    exit 0
} Catch {
    Write-Error "[-] Error critico durante la reversion de fabrica: $_"
    exit 1
}