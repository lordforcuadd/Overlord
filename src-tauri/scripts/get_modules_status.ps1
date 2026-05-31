$ErrorActionPreference = "SilentlyContinue"

$Username = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
if ($Username -match '\\(.+)$') { $Username = $Matches[1] }
if ([string]::IsNullOrWhiteSpace($Username)) { $Username = $env:USERNAME }

$UserSID = (Get-CimInstance -ClassName Win32_UserAccount | Where-Object { $_.Name -eq $Username }).SID
if ([string]::IsNullOrWhiteSpace($UserSID)) {
    $Explorer = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1
    if ($Explorer) {
        $Owner = Invoke-CimMethod -InputObject $Explorer -MethodName GetOwner
        $UserSID = (Get-CimInstance -ClassName Win32_UserAccount | Where-Object { $_.Name -eq $Owner.User }).SID
    }
}

$Targets = @()
if (-not [string]::IsNullOrWhiteSpace($UserSID)) { $Targets += "Registry::HKEY_USERS\$UserSID" }
$Targets += "HKCU:"

function Get-UserRegistryValue($subPath, $name) {
    foreach ($base in $Targets) {
        $fullPath = Join-Path $base $subPath
        if (Test-Path $fullPath) {
            $val = (Get-ItemProperty -Path $fullPath -Name $name -ErrorAction SilentlyContinue).$name
            if ($null -ne $val) { return $val }
        }
    }
    return $null
}

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
    $MouSize = (Get-ItemProperty -Path $MouPath -Name "MouseDataQueueSize").MouseDataQueueSize
    $KbdSize = (Get-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize").KeyboardDataQueueSize
    if ($MouSize -eq 32 -and $KbdSize -eq 32) {
        $Status.peripheralLatency = $true
    }
}

$DataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (Test-Path $DataPath) {
    $Tele = (Get-ItemProperty -Path $DataPath -Name "AllowTelemetry").AllowTelemetry
    if ($Tele -eq 0) {
        $Status.debloat = $true
    }
}

$DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
$TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
$ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
if (Test-Path $DnsPath) {
    $Ttl = (Get-ItemProperty -Path $DnsPath -Name "MaxCacheTtl").MaxCacheTtl
    $WaitDelay = (Get-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay" -ErrorAction SilentlyContinue).TcpTimedWaitDelay
    $Throt = (Get-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
    if ($null -ne $Ttl -and $Ttl -eq 86400 -and $WaitDelay -eq 30 -and ($Throt -eq 4294967295 -or $Throt -eq -1)) {
        $Status.networkOptimized = $true
    }
}

$StorePath = "HKCU:\System\GameConfigStore"
if (Test-Path $StorePath) {
    $GameDVR = (Get-ItemProperty -Path $StorePath -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue).GameDVR_Enabled
    if ($GameDVR -eq 0) {
        $Status.generalPerformance = $true
    }
}

$GpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
$DwmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"
$DwmMpoPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
if (Test-Path $GpuPath) {
    $Hags = (Get-ItemProperty -Path $GpuPath -Name "HwSchMode").HwSchMode
    $DwmPriority = (Get-ItemProperty -Path $DwmPath -Name "CpuPriorityClass").CpuPriorityClass
    $Mpo = (Get-ItemProperty -Path $DwmMpoPath -Name "OverlayTestMode" -ErrorAction SilentlyContinue).OverlayTestMode
    if ($Hags -eq 2 -and $DwmPriority -eq 3 -and $Mpo -eq 5) {
        $Status.gpuDisplay = $true
    }
}

$Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters" -ErrorAction SilentlyContinue
foreach ($Device in $Devices) {
    $AffinityPath = "$($Device.PSPath)\Interrupt Management\Affinity Policy"
    if (Test-Path $AffinityPath) {
        $Policy = (Get-ItemProperty -Path $AffinityPath -Name "DevicePolicy" -ErrorAction SilentlyContinue).DevicePolicy
        if ($Policy -eq 4) {
            $Status.irqAffinity = $true
            break
        }
    }
}

$NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
$FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
if (Test-Path $NtfsPath) {
    $Last = (Get-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate").NtfsDisableLastAccessUpdate
    $Hiberboot = (Get-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled" -ErrorAction SilentlyContinue).HiberbootEnabled
    if ($Last -eq 1 -and $Hiberboot -eq 0) {
        $Status.smartStorage = $true
    }
}

$VbsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
if (Test-Path $VbsPath) {
    $HvciEnabled = (Get-ItemProperty -Path $VbsPath -Name "Enabled").Enabled
    $SecureBoot = (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue)
    if ($HvciEnabled -eq 0 -and $SecureBoot -eq $false) {
        $Status.deepTelemetry = $true
    }
}

try {
    $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
    
    $ChassisType = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -Name "SystemChassisType" -ErrorAction SilentlyContinue).SystemChassisType
    $IsLaptopDevice = $ChassisType -in @(8, 9, 10, 11, 12, 14)
    
    $UsbSelectiveSuspendOk = $true
    if (-not $IsLaptopDevice) {
        $UsbHubPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USB"
        $SelectiveSuspend = (Get-ItemProperty -Path $UsbHubPath -Name "DisableSelectiveSuspend" -ErrorAction SilentlyContinue).DisableSelectiveSuspend
        if ($SelectiveSuspend -ne 1) {
            $UsbSelectiveSuspendOk = $false
        }
    }

    if ($ActivePlan.InstanceID -match "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -or $ActivePlan.InstanceID -match "e9a42b02-d5df-448d-aa00-03f14749eb61" -or $ActivePlan.ElementName -contains "High Performance" -or $ActivePlan.ElementName -contains "Ultimate Performance") {
        if ($UsbSelectiveSuspendOk) {
            $Status.powerProfiles = $true
        }
    }
} catch {}

$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe")
foreach ($Game in $TargetGames) {
    $HookPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
    if (Test-Path $HookPath) {
        $CpuP = (Get-ItemProperty -Path $HookPath -Name "CpuPriorityClass").CpuPriorityClass
        if ($CpuP -eq 3) {
            $Status.gameHooks = $true
            break
        }
    }
}

ConvertTo-Json $Status -Compress