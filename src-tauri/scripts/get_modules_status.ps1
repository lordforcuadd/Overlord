param(
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8,
    [bool]$IsSsd = $false
)
$ErrorActionPreference = "SilentlyContinue"
$WIN32_PRIORITY_SEP = 26
$HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }

$Status = @{
    peripheralLatency  = $false
    debloat            = $false
    networkOptimized   = $false
    generalPerformance = $false
    gpuDisplay         = $false
    irqAffinity        = $false
    smartStorage       = $false
    deepTelemetry      = $false
    powerProfiles      = $false
    gameHooks          = $false
    disableMitigations = $false
    defenderExclusions = $false
}

$MousePath = "$HKCU_Path\Control Panel\Mouse"
$KeyRespPath = "$HKCU_Path\Control Panel\Accessibility\Keyboard Response"
$PriorityPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
if ((Test-Path $MousePath) -and (Test-Path $PriorityPath)) {
    $Speed = Get-ItemPropertyValue -Path $MousePath -Name "MouseSpeed" -ErrorAction SilentlyContinue
    $Delay = Get-ItemPropertyValue -Path $KeyRespPath -Name "AutoRepeatDelay" -ErrorAction SilentlyContinue
    $Rate = Get-ItemPropertyValue -Path $KeyRespPath -Name "AutoRepeatRate" -ErrorAction SilentlyContinue
    $Priority = Get-ItemPropertyValue -Path $PriorityPath -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue
    if ($Speed -eq "0" -and $Delay -eq "200" -and $Rate -eq "15" -and $Priority -eq $WIN32_PRIORITY_SEP) {
        $Status['peripheralLatency'] = $true
    }
}

$ServicesToCheck = @("AJRouter", "WpcMonSvc", "TrkWks", "RemoteRegistry")
$ServicesOk = $true
foreach ($SvcName in $ServicesToCheck) {
    $Svc = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
    if ($null -ne $Svc -and $Svc.StartType -ne "Disabled") {
        $ServicesOk = $false
    }
}
$BgAppPath = "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
$EdgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$BgAppDisabled = $true
if (Test-Path $BgAppPath) {
    $BgAppVal = Get-ItemPropertyValue -Path $BgAppPath -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
    if ($BgAppVal -ne 1) { $BgAppDisabled = $false }
} else {
    $BgAppDisabled = $false
}
$EdgePoliciesOk = $true
if (Test-Path $EdgePolicyPath) {
    $SbVal = Get-ItemPropertyValue -Path $EdgePolicyPath -Name "StartupBoostEnabled" -ErrorAction SilentlyContinue
    $BmVal = Get-ItemPropertyValue -Path $EdgePolicyPath -Name "BackgroundModeEnabled" -ErrorAction SilentlyContinue
    if ($SbVal -ne 0 -or $BmVal -ne 0) { $EdgePoliciesOk = $false }
} else {
    $EdgePoliciesOk = $false
}

$DataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (Test-Path $DataPath) {
    $Tele = Get-ItemPropertyValue -Path $DataPath -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    if ($Tele -eq 0 -and $ServicesOk -and $BgAppDisabled -and $EdgePoliciesOk) {
        $Status['debloat'] = $true
    }
}

$ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
if (Test-Path $ProfilePath) {
    $SysResp = Get-ItemPropertyValue -Path $ProfilePath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue
    $Throt = Get-ItemPropertyValue -Path $ProfilePath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue
    
    $NagleOk = $false
    $InterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $InterfacesPath) {
        $InterfaceKeys = Get-ChildItem -Path $InterfacesPath -ErrorAction SilentlyContinue
        foreach ($Key in $InterfaceKeys) {
            $Ack = Get-ItemPropertyValue -Path $Key.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
            $NoDelay = Get-ItemPropertyValue -Path $Key.PSPath -Name "TcpNoDelay" -ErrorAction SilentlyContinue
            if ($Ack -eq 1 -and $NoDelay -eq 1) {
                $NagleOk = $true
                break
            }
        }
    }
    
    $InitialRtoVal = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "InitialRto" -ErrorAction SilentlyContinue
    
    $CoalescingOk = $true
    $TotalThreads = [int]$env:NUMBER_OF_PROCESSORS
    if (-not $IsLaptop -or $TotalThreads -gt 8) {
        if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
            $ActiveGuids = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
                $_.Status -eq "Up" -and $_.Virtual -eq $false -and $_.NdisPhysicalMedium -eq 14 
            } | ForEach-Object { "$($_.InterfaceGuid)" }
            
            if ($ActiveGuids.Count -gt 0) {
                $NetClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
                if (Test-Path $NetClassPath) {
                    $NetAdapters = Get-ChildItem -Path $NetClassPath -ErrorAction SilentlyContinue
                    foreach ($Adapter in $NetAdapters) {
                        if ($Adapter.PSChildName -match "^\d{4}$") {
                            $Props = Get-ItemProperty -Path $Adapter.PSPath -ErrorAction SilentlyContinue
                            if ($null -ne $Props -and $ActiveGuids -contains $Props.NetCfgInstanceId) {
                                if ($null -ne $Props."*PacketCoalescing" -and $Props."*PacketCoalescing" -ne "0") { $CoalescingOk = $false }
                                if ($null -ne $Props.PacketCoalescing -and $Props.PacketCoalescing -ne "0") { $CoalescingOk = $false }
                            }
                        }
                    }
                }
            }
        }
    }

    $PnpOk = $true
    $RunningOnBattery = $false
    if ($IsLaptop) {
        $BatteryStatus = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue
        if ($null -ne $BatteryStatus -and $BatteryStatus.PowerOnline -eq $false) {
            $RunningOnBattery = $true
        }
    }
    
    if (-not $RunningOnBattery) {
        if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
            $ActiveGuids = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
                $_.Virtual -eq $false
            } | ForEach-Object { "$($_.InterfaceGuid)" }
            
            if ($ActiveGuids.Count -gt 0) {
                $NetClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
                if (Test-Path $NetClassPath) {
                    $NetAdapters = Get-ChildItem -Path $NetClassPath -ErrorAction SilentlyContinue
                    foreach ($Adapter in $NetAdapters) {
                        if ($Adapter.PSChildName -match "^\d{4}$") {
                            $Props = Get-ItemProperty -Path $Adapter.PSPath -ErrorAction SilentlyContinue
                            if ($null -ne $Props -and $ActiveGuids -contains $Props.NetCfgInstanceId) {
                                $PnpVal = Get-ItemPropertyValue -Path $Adapter.PSPath -Name "PnPCapabilities" -ErrorAction SilentlyContinue
                                if ($null -eq $PnpVal -or $PnpVal -ne 24) {
                                    $PnpOk = $false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    if ($SysResp -eq 10 -and ($Throt -eq 4294967295 -or $Throt -eq -1) -and $NagleOk -and $InitialRtoVal -eq 2000 -and $CoalescingOk -and $PnpOk) {
        $Status['networkOptimized'] = $true
    }
}

$StorePath = "$HKCU_Path\System\GameConfigStore"
if (Test-Path $StorePath) {
    $GameDVR = Get-ItemPropertyValue -Path $StorePath -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue
    $GamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    $SchedCat = Get-ItemPropertyValue -Path $GamesPath -Name "Scheduling Category" -ErrorAction SilentlyContinue
    $PriorityVal = Get-ItemPropertyValue -Path $GamesPath -Name "Priority" -ErrorAction SilentlyContinue
    if ($GameDVR -eq 0 -and $SchedCat -eq "High" -and $PriorityVal -eq 6) {
        $Status['generalPerformance'] = $true
    }
}

$GpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
$GameBarPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
$UserGameDVRPath = "$HKCU_Path\Software\Microsoft\Windows\CurrentVersion\GameDVR"
if (Test-Path $GpuPath) {
    $AllowDVR = Get-ItemPropertyValue -Path $GameBarPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue
    $AppCap = Get-ItemPropertyValue -Path $UserGameDVRPath -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue
    
    $BuildNum = [int](Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuildNumber" -ErrorAction SilentlyContinue)
    $WddmSupported = $false
    if ($BuildNum -ge 19041) {
        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
            $Controllers = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
            foreach ($Controller in $Controllers) {
                $DriverVer = $Controller.DriverVersion
                if ($DriverVer -and $DriverVer -match "^(\d+)\.") {
                    if ([int]$Matches[1] -ge 27) {
                        $WddmSupported = $true
                        break
                    }
                }
            }
        } else {
            $WddmSupported = $true
        }
    }

    $HagsOk = $true
    if ($WddmSupported) {
        $Hags = Get-ItemPropertyValue -Path $GpuPath -Name "HwSchMode" -ErrorAction SilentlyContinue
        if ($Hags -ne 2) { $HagsOk = $false }
    }

    if ($HagsOk -and $AllowDVR -eq 0 -and $AppCap -eq 0) {
        $Status['gpuDisplay'] = $true
    }
}

if (-not $IsLaptop) {
    $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $false)
    if ($pciKey) {
        foreach ($venId in $pciKey.GetSubKeyNames()) {
            $venKey = $pciKey.OpenSubKey($venId, $false)
            if ($venKey) {
                foreach ($devId in $venKey.GetSubKeyNames()) {
                    $devKey = $venKey.OpenSubKey($devId, $false)
                    if ($devKey) {
                        $classGuid = $devKey.GetValue("ClassGUID")
                        if ($classGuid -eq "{4d36e972-e325-11ce-bfc1-08002be10318}") { # Net
                            $devParamKey = $devKey.OpenSubKey("Device Parameters\Interrupt Management\Affinity Policy", $false)
                            if ($devParamKey) {
                                $policy = $devParamKey.GetValue("DevicePolicy")
                                if ($null -ne $policy -and ($policy -eq 4 -or $policy -eq 2)) {
                                    $Status['irqAffinity'] = $true
                                }
                                $devParamKey.Close()
                            }
                        }
                        $devKey.Close()
                    }
                    if ($Status['irqAffinity']) { break }
                }
                $venKey.Close()
            }
            if ($Status['irqAffinity']) { break }
        }
        $pciKey.Close()
    }
} else {
    $Status['irqAffinity'] = $false
}



$NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
$FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
if (Test-Path $NtfsPath) {
    $Last = Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue
    $FastStart = Get-ItemPropertyValue -Path $FastStartPath -Name "HiberbootEnabled" -ErrorAction SilentlyContinue
    $Ntfs8dot3 = Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsDisable8dot3NameCreation" -ErrorAction SilentlyContinue
    $NtfsMem = Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsMemoryUsage" -ErrorAction SilentlyContinue
    
    $StorageOk = $false
    if (($Last -eq 1 -or $Last -eq 2 -or $Last -eq 3 -or $Last -eq 2147483649 -or $Last -eq 2147483650 -or $Last -eq 2147483651) -and $FastStart -eq 0 -and $Ntfs8dot3 -eq 1) {
        if ($IsSsd -and $RamGB -ge 16) {
            if ($NtfsMem -eq 2) { $StorageOk = $true }
        } else {
            $StorageOk = $true
        }
    }
    
    if ($StorageOk) {
        $Status['smartStorage'] = $true
    }
}

$DiagTrackSvc = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
$WerSvc = Get-Service -Name "WerSvc" -ErrorAction SilentlyContinue
$WerPolicy = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -ErrorAction SilentlyContinue
if (($null -ne $DiagTrackSvc -and $DiagTrackSvc.StartType -eq "Disabled") -and ($null -ne $WerSvc -and ($WerSvc.StartType -eq "Manual" -or $WerSvc.StartType -eq "Disabled")) -and $WerPolicy -eq 1) {
    $Status['deepTelemetry'] = $true
}

$PowerBackup = "HKLM:\SOFTWARE\Overlord\Backup\Power"
$PowerSchemePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes"
$PowerThrottlingPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
$ThrottleVal = Get-ItemPropertyValue -Path $PowerThrottlingPath -Name "PowerThrottlingOff" -ErrorAction SilentlyContinue

if (Test-Path $PowerSchemePath) {
    $ActivePlan = Get-ItemPropertyValue -Path $PowerSchemePath -Name "ActivePowerScheme" -ErrorAction SilentlyContinue
    $powerProps = Get-ItemProperty -Path $PowerBackup -ErrorAction SilentlyContinue
    $CustomPlanGuid = if ($null -ne $powerProps -and $null -ne $powerProps.PSObject.Properties["CustomPowerPlan"]) { $powerProps.CustomPowerPlan } else { $null }
    
    if (($ActivePlan -match "8c5e7fda" -or $ActivePlan -match "e9a42b02" -or ($null -ne $CustomPlanGuid -and $ActivePlan -match $CustomPlanGuid)) -and $ThrottleVal -eq 1) {
        $Status['powerProfiles'] = $true
    } elseif ($IsLaptop) {
        $ActivePlan = Get-ItemPropertyValue -Path $PowerSchemePath -Name "ActivePowerScheme" -ErrorAction SilentlyContinue
        $SettingPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$ActivePlan\54533251-82be-4824-96c1-47b60b740d00\94d3a615-a899-4ac5-ae2b-e4d8f634367f"
        if (Test-Path $SettingPath) {
            $AcVal = Get-ItemPropertyValue -Path $SettingPath -Name "ACSettingIndex" -ErrorAction SilentlyContinue
            if ($AcVal -eq 1 -and $ThrottleVal -eq 1) {
                $Status['powerProfiles'] = $true
            }
        }
    }
}

$LayersPath = "$HKCU_Path\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"

# Verificar estado activo de GameHooks leyendo directamente los flags reales en el registro
if (Test-Path $LayersPath) {
    $LayersProps = Get-ItemProperty -Path $LayersPath -ErrorAction SilentlyContinue
    if ($null -ne $LayersProps) {
        foreach ($Prop in $LayersProps.PSObject.Properties) {
            # Si hay un .exe con override de DPI o fullscreen optimizations deshabilitado, 
            # asumimos que el módulo gameHooks (o al menos un juego de su catálogo) está activo.
            if ($Prop.Name -match "\.exe$" -and ($Prop.Value -match "HIGHDPI_SCALING_OVERRIDE_APPLICATION" -or $Prop.Value -match "DISABLEDXMAXIMIZEDWINDOWEDMODE")) {
                $Status['gameHooks'] = $true
                break
            }
        }
    }
}

$MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if (Test-Path $MemPath) {
    $Override = Get-ItemPropertyValue -Path $MemPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue
    if ($Override -eq 8259) {
        $Status['disableMitigations'] = $true
    }
}

$DefenderExclusionsOk = $false
$BkpProps = Get-ItemProperty -Path "HKLM:\SOFTWARE\Overlord\Backup\DefenderExclusions" -ErrorAction SilentlyContinue
if ($null -ne $BkpProps -and $null -ne $BkpProps.AddedExclusions) {
    $PathsToCheck = $BkpProps.AddedExclusions -split ";" | Where-Object { $_ -ne "" }
    if ($PathsToCheck.Count -gt 0) {
        $CurrentExclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath -ErrorAction SilentlyContinue
        $CurrentExclusionsSet = @{}
        if ($CurrentExclusions) {
            foreach ($Path in $CurrentExclusions) {
                $CurrentExclusionsSet[[System.IO.Path]::GetFullPath($Path).TrimEnd('\').ToLower()] = $true
            }
        }
        
        $AllFound = $true
        foreach ($Path in $PathsToCheck) {
            $ResolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\').ToLower()
            if (-not $CurrentExclusionsSet.ContainsKey($ResolvedPath)) {
                $AllFound = $false
                break
            }
        }
        $DefenderExclusionsOk = $AllFound
    }
}
$Status['defenderExclusions'] = $DefenderExclusionsOk

ConvertTo-Json $Status -Compress
