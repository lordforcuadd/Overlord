param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

$BackupManagerPath = Join-Path $PSScriptRoot "backup_manager.psm1"
if (Test-Path $BackupManagerPath) {
    Import-Module $BackupManagerPath -Force
}

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

    Set-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -Type DWord -Value 86400 -Force
    Set-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay" -Type DWord -Value 30 -Force
    Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295 -Force

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
        if ($Adapter.InterfaceDescription -like "*Intel*") {
            Enable-NetAdapterRsc -Name $Adapter.Name -IPv4 -ErrorAction SilentlyContinue
            Enable-NetAdapterRsc -Name $Adapter.Name -IPv6 -ErrorAction SilentlyContinue
            Enable-NetAdapterChecksumOffload -Name $Adapter.Name -ErrorAction SilentlyContinue
        } else {
            Disable-NetAdapterRsc -Name $Adapter.Name -IPv4 -ErrorAction SilentlyContinue
            Disable-NetAdapterRsc -Name $Adapter.Name -IPv6 -ErrorAction SilentlyContinue
        }
    }

    Write-Host "[+] Pila de red optimizada con exito de forma transparente."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Red Saneado: $_"
    exit 1
}