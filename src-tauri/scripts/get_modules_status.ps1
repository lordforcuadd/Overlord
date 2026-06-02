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
    if ($MouSize -eq 32 -or $KbdSize -eq 32) {
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
if (Test-Path $DnsPath) {
    $Ttl = Get-ItemPropertyValue -Path $DnsPath -Name "MaxCacheTtl" -ErrorAction SilentlyContinue
    $WaitDelay = Get-ItemPropertyValue -Path $TcpPath -Name "TcpTimedWaitDelay" -ErrorAction SilentlyContinue
    if ($Ttl -eq 86400 -or $WaitDelay -eq 30) {
        $Status['networkOptimized'] = $true
    }
}

$StorePath = "HKCU:\System\GameConfigStore"
$MmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if (Test-Path $StorePath) {
    $GameDVR = Get-ItemPropertyValue -Path $StorePath -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue
    $Fso = Get-ItemPropertyValue -Path $MmPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue
    if ($GameDVR -eq 0 -or $Fso -eq 3) {
        $Status['generalPerformance'] = $true
    }
}

$GpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
$DwmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"
if (Test-Path $GpuPath) {
    $Hags = Get-ItemPropertyValue -Path $GpuPath -Name "HwSchMode" -ErrorAction SilentlyContinue
    $DwmCpu = Get-ItemPropertyValue -Path $DwmPath -Name "CpuPriorityClass" -ErrorAction SilentlyContinue
    if ($Hags -eq 2 -or $DwmCpu -eq 3) {
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
                    if ($null -ne $policy -and $policy -eq 4) {
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

$NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
if (Test-Path $NtfsPath) {
    $Last = Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue
    if ($Last -eq 1 -or $Last -eq 2) {
        $Status['smartStorage'] = $true
    }
}

$VbsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
if (Test-Path $VbsPath) {
    $HvciEnabled = Get-ItemPropertyValue -Path $VbsPath -Name "Enabled" -ErrorAction SilentlyContinue
    if ($HvciEnabled -eq 0) {
        $Status['deepTelemetry'] = $true
    }
}

$PowerSchemePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes"
if (Test-Path $PowerSchemePath) {
    $ActivePlan = Get-ItemPropertyValue -Path $PowerSchemePath -Name "ActivePowerScheme" -ErrorAction SilentlyContinue
    if ($ActivePlan -match "8c5e7fda" -or $ActivePlan -match "e9a42b02" -or $ActivePlan -match "77777777") {
        $Status['powerProfiles'] = $true
    }
}

$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe")
foreach ($Game in $TargetGames) {
    $HookPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
    if (Test-Path $HookPath) {
        $CpuP = Get-ItemPropertyValue -Path $HookPath -Name "CpuPriorityClass" -ErrorAction SilentlyContinue
        if ($CpuP -eq 3) {
            $Status['gameHooks'] = $true
            break
        }
    }
}

ConvertTo-Json $Status -Compress