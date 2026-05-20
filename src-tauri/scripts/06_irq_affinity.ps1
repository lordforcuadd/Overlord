param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Try {
    Write-Host "[*] Reconfigurando el SystemProfile de Windows..."

    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Type DWord -Value 0
    Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295

    # Recuperada tu línea de SFIO Priority
    $TasksPath = "$ProfilePath\Tasks\Games"
    if (!(Test-Path $TasksPath)) { New-Item -Path $TasksPath -Force | Out-Null }
    Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8
    Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 6
    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "High"
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "High"

    Write-Host "[*] Aplicando IRQ Steering para aislar tráfico de red..."
    
    # (El mito de IRQ8Priority se mantiene borrado, tal como discutimos)

    $NetDevices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters\Interrupt Management\Affinity Policy" -ErrorAction SilentlyContinue
    foreach ($Net in $NetDevices) {
        Set-ItemProperty -Path $Net.PSPath -Name "DevicePolicy" -Type DWord -Value 4 
        Set-ItemProperty -Path $Net.PSPath -Name "AssignmentSetOverride" -Type Binary -Value ([byte[]](0x02,0x00,0x00,0x00)) 
    }

    Write-Host "[+] Hilos del CPU liberados. Prioridad IRQ ajustada."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Gestión IRQ: $_"
    exit 1
}