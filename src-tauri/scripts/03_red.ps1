param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Aplicando TCP Tweaks Avanzados y Perfiles Multimedia Inteligentes..."

    # Almacén de persistencia simétrica para red
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Network"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    # 1. OPTIMIZACIÓN DE FRECUENCIA DE ACK Y NAGLE ALGORITHM CON RESPALDO DINÁMICO
    $Interfaces = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($Interface in $Interfaces) {
        $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
        
        if (Test-Path $TcpPath) {
            # Guardar valores previos si existen en el sistema del usuario
            $OrigAck = (Get-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue).TcpAckFrequency
            $OrigDelay = (Get-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue).TCPNoDelay
            
            $BackupInterfaceKey = "$BackupPath\$($Interface.SettingID)"
            if (!(Test-Path $BackupInterfaceKey)) { New-Item -Path $BackupInterfaceKey -Force | Out-Null }
            
            if ($OrigAck -ne $null) { Set-ItemProperty -Path $BackupInterfaceKey -Name "TcpAckFrequency" -Value $OrigAck -Force } else { Set-ItemProperty -Path $BackupInterfaceKey -Name "TcpAckFrequency" -Value 999 -Force }
            if ($OrigDelay -ne $null) { Set-ItemProperty -Path $BackupInterfaceKey -Name "TCPNoDelay" -Value $OrigDelay -Force } else { Set-ItemProperty -Path $BackupInterfaceKey -Name "TCPNoDelay" -Value 999 -Force }
        }

        Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -Type DWord -Value 1 -Force
        Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -Type DWord -Value 1 -Force
    }

    ipconfig /flushdns | Out-Null

    # 2. PROCESAMIENTO REUNIDO Y DESCARGAS DE HARDWARE (Adaptabilidad de Antena Wi-Fi)
    try {
        # 🚀 FILTRO ADAPTATIVO: Solo desactivar RSC si no es una laptop para mitigar el stuttering por CPU de red inalámbrica
        if (!$IsLaptop) {
            Write-Host "[*] Entorno Desktop: Optimizando RSC para procesamiento directo de paquetes..."
            Disable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
            Disable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
        } else {
            Write-Host "[*] Entorno Laptop: Preservando RSC para estabilidad de red Wi-Fi..."
        }
        
        # Desactivar descargas LSO pesadas que provocan retraso de buffer en el adaptador
        Disable-NetAdapterLso -Name "*" -IPv4 -ErrorAction SilentlyContinue
        Disable-NetAdapterLso -Name "*" -IPv6 -ErrorAction SilentlyContinue
        Disable-NetAdapterChecksumOffload -Name "*" -IpIPv4 -ErrorAction SilentlyContinue
    } catch {}

    # 3. ANULACIÓN DE ANCHO DE BANDA RESERVADO POR QOS (Respaldo + Inyección)
    $QosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    if (!(Test-Path $QosPath)) { New-Item -Path $QosPath -Force | Out-Null }
    $OrigQos = (Get-ItemProperty -Path $QosPath -Name "NonBestEffortLimit" -ErrorAction SilentlyContinue).NonBestEffortLimit
    if ($OrigQos -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "NonBestEffortLimit" -ErrorAction SilentlyContinue) -eq $null) {
        Set-ItemProperty -Path $BackupPath -Name "NonBestEffortLimit" -Value $OrigQos -Force
    }
    Set-ItemProperty -Path $QosPath -Name "NonBestEffortLimit" -Type DWord -Value 0 -Force

    # 4. PARÁMETROS DE DNS CACHE A TIEMPO REAL
    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    Set-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -Type DWord -Value 1 -Force
    Set-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -Type DWord -Value 0 -Force

    # 5. AJUSTE DE LA PILA DE RED GLOBAL (Evita pérdida de paquetes)
    netsh int tcp set global ecncapability=enabled | Out-Null
    if ($IsLaptop) {
        # 🚀 AUTO-TUNING EQUILIBRADO: Evita caídas silenciosas de conexión en microcontroladores móviles
        netsh int tcp set global autotuninglevel=normal | Out-Null
    } else {
        netsh int tcp set global autotuninglevel=experimental | Out-Null
    }
    # [SANEADO]: Removida la instrucción descontinuada chimney=disabled por redundancia e inoperancia nativa

    # 6. ENTORNO MULTIMEDIA SIN RESTRICCIONES (Network Throttling Index)
    $SysProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $SysProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295 -Force
    Set-ItemProperty -Path $SysProfilePath -Name "SystemResponsiveness" -Type DWord -Value 0 -Force

    Write-Host "[+] Red optimizada, búferes depurados y latencia de paquetes al mínimo."
    exit 0
} Catch {
    Write-Error "[-] Error en Optimización de Red: $_"
    exit 1
}