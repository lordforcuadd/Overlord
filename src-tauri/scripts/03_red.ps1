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
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $DnsPath -ValueName "MaxCacheTtl" -BackupSubFolder "Network"
        Backup-OverlordRegistryValue -TargetKey $DnsPath -ValueName "MaxNegativeCacheTtl" -BackupSubFolder "Network"
    }

    Set-ItemProperty -Path $DnsPath -Name "MaxCacheTtl" -Type DWord -Value 86400 -Force
    Set-ItemProperty -Path $DnsPath -Name "MaxNegativeCacheTtl" -Type DWord -Value 0 -Force

    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global timestamps=disabled | Out-Null

    $Interfaces = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($Interface in $Interfaces) {
        Enable-NetAdapterRsc -Name "*" -IPv4 -ErrorAction SilentlyContinue
        Enable-NetAdapterRsc -Name "*" -IPv6 -ErrorAction SilentlyContinue
        Enable-NetAdapterChecksumOffload -Name "*" -ErrorAction SilentlyContinue
    }

    Write-Host "[+] Pila de red optimizada con exito de forma transparente."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Red Saneado: $_"
    exit 1
}