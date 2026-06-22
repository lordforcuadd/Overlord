param(
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)
$ErrorActionPreference = "SilentlyContinue"
$HKCU_Path = $global:HKCU_Path

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
}

$MousePath = "$HKCU_Path\Control Panel\Mouse"
$KeyRespPath = "$HKCU_Path\Control Panel\Accessibility\Keyboard Response"
$PriorityPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
if ((Test-Path $MousePath) -and (Test-Path $PriorityPath)) {
    $Speed = Get-ItemPropertyValue -Path $MousePath -Name "MouseSpeed" -ErrorAction SilentlyContinue
    $Delay = Get-ItemPropertyValue -Path $KeyRespPath -Name "AutoRepeatDelay" -ErrorAction SilentlyContinue
    $Rate = Get-ItemPropertyValue -Path $KeyRespPath -Name "AutoRepeatRate" -ErrorAction SilentlyContinue
    $Priority = Get-ItemPropertyValue -Path $PriorityPath -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue
    if ($Speed -eq "0" -and $Delay -eq "200" -and $Rate -eq "15" -and $Priority -eq 26) {
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
    
    if ($SysResp -eq 10 -and ($Throt -eq 4294967295 -or $Throt -eq -1) -and $NagleOk -and $InitialRtoVal -eq 2000) {
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
    $Hags = Get-ItemPropertyValue -Path $GpuPath -Name "HwSchMode" -ErrorAction SilentlyContinue
    $AllowDVR = Get-ItemPropertyValue -Path $GameBarPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue
    $AppCap = Get-ItemPropertyValue -Path $UserGameDVRPath -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue
    if ($Hags -eq 2 -and $AllowDVR -eq 0 -and $AppCap -eq 0) {
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
                                if ($null -ne $policy -and ($policy -eq 2 -or $policy -eq 3 -or $policy -eq 4)) {
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
        if ($RamGB -ge 16) {
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
if (Test-Path $PowerSchemePath) {
    $ActivePlan = Get-ItemPropertyValue -Path $PowerSchemePath -Name "ActivePowerScheme" -ErrorAction SilentlyContinue
    $powerProps = Get-ItemProperty -Path $PowerBackup -ErrorAction SilentlyContinue
    $CustomPlanGuid = if ($null -ne $powerProps -and $null -ne $powerProps.PSObject.Properties["CustomPowerPlan"]) { $powerProps.CustomPowerPlan } else { $null }
    
    if ($ActivePlan -match "8c5e7fda" -or $ActivePlan -match "e9a42b02" -or ($null -ne $CustomPlanGuid -and $ActivePlan -match $CustomPlanGuid)) {
        $Status['powerProfiles'] = $true
    } elseif ($IsLaptop) {
        $ActivePlan = Get-ItemPropertyValue -Path $PowerSchemePath -Name "ActivePowerScheme" -ErrorAction SilentlyContinue
        $SettingPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$ActivePlan\54533251-82be-4824-96c1-47b60b740d00\94d3a615-a899-4ac5-ae2b-e4d8f634367f"
        if (Test-Path $SettingPath) {
            $AcVal = Get-ItemPropertyValue -Path $SettingPath -Name "ACSettingIndex" -ErrorAction SilentlyContinue
            if ($AcVal -eq 1) {
                $Status['powerProfiles'] = $true
            }
        }
    }
}

$GameHooksBackup = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks"
$LayersPath = "$HKCU_Path\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"

# 1. Comprobar juegos configurados en games_to_optimize.txt si existe
$ProgData = $env:ProgramData
if ([string]::IsNullOrWhiteSpace($ProgData)) { 
    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    $ProgData = Join-Path $SysDrive "ProgramData"
}
$ConfigPath = Join-Path $ProgData "Overlord\games_to_optimize.txt"

if (Test-Path $ConfigPath) {
    $GamesContent = Get-Content -Path $ConfigPath -ErrorAction SilentlyContinue
    if ($GamesContent) {
        $GamesList = $GamesContent -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
        if ($GamesList -and (Test-Path $LayersPath)) {
            $Layers = Get-ItemProperty -Path $LayersPath -ErrorAction SilentlyContinue
            if ($null -ne $Layers) {
                foreach ($Prop in $Layers.PSObject.Properties) {
                    if ($Prop.Name -match "\.exe$" -and $Prop.Value -match "HIGHDPI_SCALING_OVERRIDE_APPLICATION") {
                        $ExeName = Split-Path $Prop.Name -Leaf
                        $CleanExe = $ExeName.ToLower() -replace '\.exe$', ''
                        if ($GamesList -contains $CleanExe) {
                            $Status['gameHooks'] = $true
                            break
                        }
                    }
                }
            }
        }
    }
}

# 2. Fallback al backup si el paso anterior no dio positivo
if ($Status['gameHooks'] -ne $true -and (Test-Path $GameHooksBackup)) {
    $SubKeys = Get-ChildItem -Path $GameHooksBackup -ErrorAction SilentlyContinue
    foreach ($Key in $SubKeys) {
        $PathVal = Get-ItemPropertyValue -Path $Key.PSPath -Name "Path" -ErrorAction SilentlyContinue
        if (![string]::IsNullOrWhiteSpace($PathVal)) {
            $CurrentFlags = Get-ItemPropertyValue -Path $LayersPath -Name $PathVal -ErrorAction SilentlyContinue
            if ($CurrentFlags -match "HIGHDPI_SCALING_OVERRIDE_APPLICATION") {
                $Status['gameHooks'] = $true
                break
            }
        }
    }
}

$MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if (Test-Path $MemPath) {
    $Override = Get-ItemPropertyValue -Path $MemPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue
    if ($Override -eq 3) {
        $Status['disableMitigations'] = $true
    }
}


ConvertTo-Json $Status -Compress