$ErrorActionPreference = "SilentlyContinue"

$Username = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
if ($Username -match '\\(.+)$') { $Username = $Matches[1] }
if ([string]::IsNullOrWhiteSpace($Username)) { $env:USERNAME }

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
    perifericos    = $false
    telemetria     = $false
    red            = $false
    rendimiento    = $false
    gpu            = $false
    irq            = $false
    almacenamiento = $false
    bloatware      = $false
    energia        = $false
    ifeo           = $false
}

$MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
$KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
$PriPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
if (Test-Path $MouPath) {
    $MouSize = (Get-ItemProperty -Path $MouPath -Name "MouseDataQueueSize").MouseDataQueueSize
    $KbdSize = (Get-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize").KeyboardDataQueueSize
    $PriSep  = (Get-ItemProperty -Path $PriPath -Name "Win32PrioritySeparation").Win32PrioritySeparation
    if ($MouSize -eq 20 -and $KbdSize -eq 20 -and $PriSep -eq 38) {
        $Status.perifericos = $true
    }
}

$DataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (Test-Path $DataPath) {
    $Tele = (Get-ItemProperty -Path $DataPath -Name "AllowTelemetry").AllowTelemetry
    if ($Tele -eq 0) {
        $Status.telemetria = $true
    }
}

$DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
if (Test-Path $DnsPath) {
    $Ttl = (Get-ItemProperty -Path $DnsPath -Name "MaxCacheTtl").MaxCacheTtl
    if ($Ttl -eq 300) {
        $Status.red = $true
    }
}

$MitPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if (Test-Path $MitPath) {
    $Feat = (Get-ItemProperty -Path $MitPath -Name "FeatureSettingsOverride").FeatureSettingsOverride
    if ($Feat -eq 3) {
        $Status.rendimiento = $true
    }
}

$Beh = Get-UserRegistryValue "System\GameConfigStore" "GameDVR_FSEBehaviorMode"
if ($Beh -eq 2) {
    $Status.gpu = $true
}

$SysPPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
if (Test-Path $SysPPath) {
    $Resp = (Get-ItemProperty -Path $SysPPath -Name "SystemResponsiveness").SystemResponsiveness
    if ($Resp -eq 0) {
        $Status.irq = $true
    }
}

$NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
if (Test-Path $NtfsPath) {
    $Last = (Get-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate").NtfsDisableLastAccessUpdate
    if ($Last -eq 1) {
        $Status.almacenamiento = $true
    }
}

$VbsPath = "HKLM:\System\CurrentControlSet\Control\DeviceGuard"
if (Test-Path $VbsPath) {
    $VbsEnabled = (Get-ItemProperty -Path $VbsPath -Name "EnableVirtualizationBasedSecurity").EnableVirtualizationBasedSecurity
    if ($VbsEnabled -eq 0) {
        $Status.bloatware = $true
    }
}

$WubPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (Test-Path $WubPath) {
    $DisableUp = (Get-ItemProperty -Path $WubPath -Name "DisableWindowsUpdateAccess").DisableWindowsUpdateAccess
    if ($DisableUp -eq 1) {
        $Status.energia = $true
    }
}

try {
    $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
    if ($ActivePlan) {
        $Status.energia = $true
    }
} catch {}

$TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe")
foreach ($Game in $TargetGames) {
    $HookPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
    if (Test-Path $HookPath) {
        $CpuP = (Get-ItemProperty -Path $HookPath -Name "CpuPriorityClass").CpuPriorityClass
        if ($CpuP -eq 3) {
            $Status.ifeo = $true
            break
        }
    }
}

ConvertTo-Json $Status -Compress