param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando optimizacion cientifica de la pila de red TCP/IP..."

    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    if (!(Test-Path $TcpPath)) { New-Item -Path $TcpPath -Force | Out-Null }
    if (!(Test-Path $ProfilePath)) { New-Item -Path $ProfilePath -Force | Out-Null }
    
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $DnsPath -ValueName "MaxCacheTtl" -BackupSubFolder "Network"
        Backup-OverlordRegistryValue -TargetKey $DnsPath -ValueName "MaxNegativeCacheTtl" -BackupSubFolder "Network"
        Backup-OverlordRegistryValue -TargetKey $TcpPath -ValueName "TcpTimedWaitDelay" -BackupSubFolder "Network"
        Backup-OverlordRegistryValue -TargetKey $ProfilePath -ValueName "NetworkThrottlingIndex" -BackupSubFolder "Network"
    }

    Set-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -Type DWord -Value 86400 -Force | Out-Null
    Set-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay" -Type DWord -Value 30 -Force | Out-Null
    Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295 -Force | Out-Null

    if ((Get-ItemProperty -Path $DnsPath -Name "MaxCacheTtl").MaxCacheTtl -ne 86400) { throw "Verification failed" }
    if ((Get-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl").MaxNegativeCacheTtl -ne 0) { throw "Verification failed" }
    if ((Get-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay").TcpTimedWaitDelay -ne 30) { throw "Verification failed" }
    
    $throttingVal = (Get-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex").NetworkThrottlingIndex
    if ($throttingVal -ne 4294967295 -and $throttingVal -ne -1) { throw "Verification failed" }

    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global timestamps=disabled | Out-Null

    $HasNativeIPv6 = $false
    try {
        $IPv6Test = Test-Connection -ComputerName "ipv6.google.com" -Count 1 -ErrorAction SilentlyContinue
        if ($null -ne $IPv6Test) { $HasNativeIPv6 = $true }
    } catch {}

    if (-not $HasNativeIPv6) {
        netsh interface ipv6 teredo set state disabled | Out-Null
        netsh interface ipv6 isatap set state disabled | Out-Null
    }

    $Adapters = Get-NetAdapter -ErrorAction SilentlyContinue
    foreach ($Adapter in $Adapters) {
        if ($Adapter.Status -eq "Up" -or $Adapter.HardwareInterface -eq $true) {
            Enable-NetAdapterChecksumOffload -Name $Adapter.Name -ErrorAction SilentlyContinue | Out-Null
            Write-Host "    -> Aislamiento de latencia inyectado en adaptador: $($Adapter.Name)"
        }
    }

    Write-Host "[+] Pila de red optimizada con exito de forma transparente."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Red Saneado: $_"
    exit 1
}