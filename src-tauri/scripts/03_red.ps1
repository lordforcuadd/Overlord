param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando TCP Tweaks Avanzados y Perfiles Multimedia..."

    # Creación del almacén secundario para red
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Network"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    # 1. OPTIMIZACIÓN FRECUENCIA DE ACK Y NAGLE ALGORITHM
    $Interfaces = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($Interface in $Interfaces) {
        $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
        Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -Type DWord -Value 1 -Force
        Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -Type DWord -Value 1 -Force
    }

    ipconfig /flushdns | Out-Null

    # 2. PROCESAMIENTO REUNIDO Y DESCARGAS DE HARDWARE (0ms Packet Delay)
    Write-Host "[*] Erradicando RSC y LSO de los adaptadores de red..."
    try {
        Disable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
        Disable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
        Disable-NetAdapterLso -Name "*" -IPv4 -ErrorAction SilentlyContinue
        Disable-NetAdapterLso -Name "*" -IPv6 -ErrorAction SilentlyContinue
        Disable-NetAdapterChecksumOffload -Name "*" -IpIPv4 -ErrorAction SilentlyContinue
    } catch {}

    # 3. DESTRUCCIÓN DE ANCHO DE BANDA RESERVADO POR QOS
    Write-Host "[*] Destruyendo reserva de ancho de banda (QoS Limit)..."
    $QosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    if (!(Test-Path $QosPath)) { New-Item -Path $QosPath -Force | Out-Null }
    Set-ItemProperty -Path $QosPath -Name "NonBestEffortLimit" -Type DWord -Value 0 -Force

    # 4. PARÁMETROS CRÍTICOS DE DNS CACHE A TIEMPO REAL
    Write-Host "[*] Forzando DNS Cache a Tiempo Real (0ms Latencia DNS)..."
    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    Set-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -Type DWord -Value 1 -Force
    Set-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -Type DWord -Value 0 -Force

    # 5. AJUSTE DE LA PILA DE RED GLOBAL (Evita pérdida de paquetes en ráfagas)
    Write-Host "[*] Configurando TCP Window Auto-Tuning a modo experimental avanzado..."
    netsh int tcp set global ecncapability=enabled | Out-Null
    netsh int tcp set global autotuninglevel=experimental | Out-Null
    netsh int tcp set global chimney=disabled | Out-Null

    # 6. ANULACIÓN DE REDUNDANCIA Y ESTRANGULAMIENTO MULTIMEDIA (Network Throttling Index)
    Write-Host "[*] Removiendo indexación de estrangulamiento de red en SystemProfile..."
    $SysProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $SysProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295 -Force
    Set-ItemProperty -Path $SysProfilePath -Name "SystemResponsiveness" -Type DWord -Value 0 -Force

    exit 0
} Catch {
    Write-Error "[-] Error en Optimización de Red: $_"
    exit 1
}