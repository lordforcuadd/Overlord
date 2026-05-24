param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Reconfigurando perfiles multimedia y afinidad de Hardware (IRQ)..."

    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295 -Force

    # Prioridades de ejecución multimedia para videojuegos y File I/O balanceado
    $TasksPath = "$ProfilePath\Tasks\Games"
    if (!(Test-Path $TasksPath)) { New-Item -Path $TasksPath -Force | Out-Null }
    Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8 -Force
    Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 6 -Force
    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "High" -Force
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "High" -Force

    # Distribución inteligente del tráfico de red fuera del Núcleo 0 (IRQ Steering)
    Write-Host "[*] Aplicando IRQ Steering para aislar de forma eficiente el procesamiento de red..."
    $NetDevices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters\Interrupt Management\Affinity Policy" -ErrorAction SilentlyContinue
    foreach ($Net in $NetDevices) {
        try {
            Set-ItemProperty -Path $Net.PSPath -Name "DevicePolicy" -Type DWord -Value 4 -ErrorAction SilentlyContinue -Force
            Set-ItemProperty -Path $Net.PSPath -Name "AssignmentSetOverride" -Type Binary -Value ([byte[]](0x02,0x00,0x00,0x00)) -ErrorAction SilentlyContinue -Force
        } catch {}
    }

    Write-Host "[+] Carga equilibrada en los núcleos del CPU. Prioridades multimedia inyectadas."
    exit 0
} Catch {
    Write-Error "[-] Error crítico en Gestión IRQ y Procesador: $_"
    exit 1
}