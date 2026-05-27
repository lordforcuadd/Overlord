param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Optimizando la pila de red TCP/IP..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Network"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $Interfaces = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($Interface in $Interfaces) {
        $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
        if (Test-Path $TcpPath) {
            $OrigAck = (Get-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue).TcpAckFrequency
            $OrigDelay = (Get-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue).TCPNoDelay

            $InterfaceBackupKey = "$BackupPath\$($Interface.SettingID)"
            if (!(Test-Path $InterfaceBackupKey)) { New-Item -Path $InterfaceBackupKey -Force | Out-Null }

            if ((Get-ItemProperty -Path $InterfaceBackupKey -Name "TcpAckFrequency" -ErrorAction SilentlyContinue) -eq $null) {
                $BckAck = if ($OrigAck -eq $null) { 999 } else { $OrigAck }
                Set-ItemProperty -Path $InterfaceBackupKey -Name "TcpAckFrequency" -Type DWord -Value $BckAck -Force
            }
            if ((Get-ItemProperty -Path $InterfaceBackupKey -Name "TCPNoDelay" -ErrorAction SilentlyContinue) -eq $null) {
                $BckDelay = if ($OrigDelay -eq $null) { 999 } else { $OrigDelay }
                Set-ItemProperty -Path $InterfaceBackupKey -Name "TCPNoDelay" -Type DWord -Value $BckDelay -Force
            }

            Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -Type DWord -Value 1 -Force
            Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -Type DWord -Value 1 -Force
        }
    }

    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    Set-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -Type DWord -Value 300 -Force
    Set-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -Type DWord -Value 30 -Force

    Disable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
    Disable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
    Disable-NetAdapterLso -Name "*" -IPv4 -ErrorAction SilentlyContinue
    Disable-NetAdapterLso -Name "*" -IPv6 -ErrorAction SilentlyContinue
    Disable-NetAdapterChecksumOffload -Name "*" -IpIPv4 -ErrorAction SilentlyContinue

    netsh int tcp set global autotuninglevel=highlyrestricted | Out-Null
    netsh int tcp set global ecncapability=enabled | Out-Null

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Red: $_"
    exit 1
}