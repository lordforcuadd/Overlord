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
    # Sincronizado: Verdadero si se redujeron los buffers de cola a 20 (fábrica es 100)
    if ($MouSize -eq 20 -and $KbdSize -eq 20) {
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
if (Test-Path $DnsPath) {
    $Ttl = (Get-ItemProperty -Path $DnsPath -Name "MaxCacheTtl").MaxCacheTtl
   
    if ($null -ne $Ttl -and $Ttl -le 300) {
        $Status.networkOptimized = $true
    }
}


$MitPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if (Test-Path $MitPath) {
    $Feat = (Get-ItemProperty -Path $MitPath -Name "FeatureSettingsOverride").FeatureSettingsOverride
    if ($Feat -eq 3) {
        $Status.generalPerformance = $true
    }
}


$GpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
$DwmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"
if (Test-Path $GpuPath) {
    $Hags = (Get-ItemProperty -Path $GpuPath -Name "HwSchMode").HwSchMode
    $DwmPriority = (Get-ItemProperty -Path $DwmPath -Name "CpuPriorityClass").CpuPriorityClass
    
    if ($Hags -eq 1 -and $DwmPriority -eq 2) {
        $Status.gpuDisplay = $true
    }
}


$NetAffinityPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Interrupt Management\Affinity Policy"
if (Test-Path $NetAffinityPath) {
    
    $Status.irqAffinity = $true
}


$NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
if (Test-Path $NtfsPath) {
    $Last = (Get-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate").NtfsDisableLastAccessUpdate
    if ($Last -eq 1) {
        $Status.smartStorage = $true
    }
}


$VbsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
if (Test-Path $VbsPath) {
    $HvciEnabled = (Get-ItemProperty -Path $VbsPath -Name "Enabled").Enabled
    
    if ($HvciEnabled -eq 0) {
        $Status.deepTelemetry = $true
    }
}


try {
    
    $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
    
    if ($ActivePlan.ElementID -match "834a059d-6d97-4705-8a70-9a374252d76a" -or $ActivePlan.ElementName -contains "High Performance") {
        $Status.powerProfiles = $true
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