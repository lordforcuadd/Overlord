param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Try {
    Write-Host "[*] Aplicando TCP Tweaks para latencia de red..."

    $Interfaces = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($Interface in $Interfaces) {
        $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
        Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency" -Type DWord -Value 1
        Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay" -Type DWord -Value 1
    }

    ipconfig /flushdns | Out-Null

    Write-Host "[*] Desactivando ECN para evitar picos de Ping en routers..."
        netsh int tcp set global ecncapability=disabled | Out-Null
        netsh int tcp set global autotuninglevel=normal | Out-Null

    Write-Host "[+] Algoritmo de Nagle deshabilitado y ECN ajustado. Ping optimizado."
    exit 0
} Catch {
    Write-Error "[-] Error en Optimizacion de Red: $_"
    exit 1
}