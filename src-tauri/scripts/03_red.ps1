param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando TCP Tweaks para latencia de red..."

    $Interfaces = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($Interface in $Interfaces) {
        $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
        Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -Type DWord -Value 1 -Force
        Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -Type DWord -Value 1 -Force
    }

    ipconfig /flushdns | Out-Null

    Write-Host "[*] (WinScript) Erradicando RSC y LSO de los adaptadores de red (0ms Packet Delay)..."
    try {
        Disable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
        Disable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
        Disable-NetAdapterLso -Name "*" -IPv4 -ErrorAction SilentlyContinue
        Disable-NetAdapterLso -Name "*" -IPv6 -ErrorAction SilentlyContinue
        Disable-NetAdapterChecksumOffload -Name "*" -IpIPv4 -ErrorAction SilentlyContinue
    } catch {}

    Write-Host "[*] Destruyendo reserva de ancho de banda (QoS Limit)..."
    $QosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    if (!(Test-Path $QosPath)) { New-Item -Path $QosPath -Force | Out-Null }
    Set-ItemProperty -Path $QosPath -Name "NonBestEffortLimit" -Type DWord -Value 0 -Force

    Write-Host "[*] Forzando DNS Cache a Tiempo Real (0ms Latencia DNS)..."
    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    Set-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -Type DWord -Value 1 -Force
    Set-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -Type DWord -Value 0 -Force

    Write-Host "[*] Normalizando ECN (Evita Packet Loss en servidores AWS/Azure)..."
    netsh int tcp set global ecncapability=normal | Out-Null
    netsh int tcp set global autotuninglevel=normal | Out-Null

    exit 0
} Catch {
    Write-Error "[-] Error en Optimizacion de Red: $_"
    exit 1
}