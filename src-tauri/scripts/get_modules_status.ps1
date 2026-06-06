$ErrorActionPreference = "SilentlyContinue"

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
}

$MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
$KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
if (Test-Path $MouPath) {
    $MouSize = Get-ItemPropertyValue -Path $MouPath -Name "MouseDataQueueSize" -ErrorAction SilentlyContinue
    $KbdSize = Get-ItemPropertyValue -Path $KbdPath -Name "KeyboardDataQueueSize" -ErrorAction SilentlyContinue
    if (($null -ne $MouSize -and $MouSize -le 64) -or ($null -ne $KbdSize -and $KbdSize -le 64)) {
        $Status['peripheralLatency'] = $true
    }
}

$DataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (Test-Path $DataPath) {
    $Tele = Get-ItemPropertyValue -Path $DataPath -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    if ($Tele -eq 0) {
        $Status['debloat'] = $true
    }
}

$DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
$TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
$ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
if (Test-Path $DnsPath) {
    $Ttl = Get-ItemPropertyValue -Path $DnsPath -Name "MaxCacheTtl" -ErrorAction SilentlyContinue
    $WaitDelay = Get-ItemPropertyValue -Path $TcpPath -Name "TcpTimedWaitDelay" -ErrorAction SilentlyContinue
    $SysResp = Get-ItemPropertyValue -Path $ProfilePath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue
    if ($Ttl -eq 86400 -or $WaitDelay -eq 30 -or $SysResp -eq 10) {
        $Status['networkOptimized'] = $true
    }
}

$StorePath = "HKCU:\System\GameConfigStore"
if (Test-Path $StorePath) {
    $GameDVR = Get-ItemPropertyValue -Path $StorePath -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue
    if ($GameDVR -eq 0) {
        $Status['generalPerformance'] = $true
    }
}

$GpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
if (Test-Path $GpuPath) {
    $Hags = Get-ItemPropertyValue -Path $GpuPath -Name "HwSchMode" -ErrorAction SilentlyContinue
    if ($Hags -eq 2) {
        $Status['gpuDisplay'] = $true
    }
}

$pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI")
if ($pciKey) {
    foreach ($venId in $pciKey.GetSubKeyNames()) {
        $venKey = $pciKey.OpenSubKey($venId)
        if ($venKey) {
            foreach ($devId in $venKey.GetSubKeyNames()) {
                $devParamKey = $venKey.OpenSubKey("$devId\Device Parameters\Interrupt Management\Affinity Policy")
                if ($devParamKey) {
                    $policy = $devParamKey.GetValue("DevicePolicy")
                    if ($null -ne $policy -and ($policy -eq 3 -or $policy -eq 4)) {
                        $Status['irqAffinity'] = $true
                        break
                    }
                }
            }
        }
        if ($Status['irqAffinity']) { break }
    }
    $pciKey.Close()
}

$CpuBackup = "HKLM:\SOFTWARE\Overlord\Backup\CPU"
$IsSystemLaptop = $IsLaptop

if ($IsSystemLaptop -and (Test-Path $CpuBackup)) {
    $Status['irqAffinity'] = $true
}

$NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
if (Test-Path $NtfsPath) {
    $Last = Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue
    if ($Last -eq 1 -or $Last -eq 2 -or $Last -eq 3 -or $Last -eq 2147483649 -or $Last -eq 2147483650 -or $Last -eq 2147483651) {
        $Status['smartStorage'] = $true
    }
}

$DiagTrackSvc = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
if ($null -ne $DiagTrackSvc -and $DiagTrackSvc.StartType -eq "Disabled") {
    $Status['deepTelemetry'] = $true
}

$PowerSchemePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes"
if (Test-Path $PowerSchemePath) {
    $ActivePlan = Get-ItemPropertyValue -Path $PowerSchemePath -Name "ActivePowerScheme" -ErrorAction SilentlyContinue
    $CustomPlanGuid = (Get-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -ErrorAction SilentlyContinue).CustomPowerPlan
    
    if ($ActivePlan -match "8c5e7fda" -or $ActivePlan -match "e9a42b02" -or $ActivePlan -match "77777777" -or ($null -ne $CustomPlanGuid -and $ActivePlan -match $CustomPlanGuid)) {
        $Status['powerProfiles'] = $true
    } elseif ($IsSystemLaptop -and (Test-Path $PowerBackup)) {
        $Status['powerProfiles'] = $true
    }
}

$GameHooksBackup = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks"
if (Test-Path $GameHooksBackup) {
    $SubKeys = Get-ChildItem -Path $GameHooksBackup -ErrorAction SilentlyContinue
    foreach ($Key in $SubKeys) {
        $PathVal = Get-ItemPropertyValue -Path $Key.PSPath -Name "Path" -ErrorAction SilentlyContinue
        if (![string]::IsNullOrWhiteSpace($PathVal)) {
            $LayersPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
            $CurrentFlags = Get-ItemPropertyValue -Path $LayersPath -Name $PathVal -ErrorAction SilentlyContinue
            if ($CurrentFlags -match "HIGHDPI_SCALING_OVERRIDE_APPLICATION") {
                $Status['gameHooks'] = $true
                break
            }
        }
    }
}

ConvertTo-Json $Status -Compress