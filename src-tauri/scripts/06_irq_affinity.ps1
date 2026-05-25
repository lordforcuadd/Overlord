param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Reconfigurando perfiles multimedia y afinidad de Hardware (IRQ)..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\CPU"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    
    # Respaldo de metadatos multimedia basales
    if (Test-Path $ProfilePath) {
        $OrigResp = (Get-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue).SystemResponsiveness
        $OrigThrot = (Get-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
        
        if ($OrigResp -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue) -eq $null) {
            Set-ItemProperty -Path $BackupPath -Name "SystemResponsiveness" -Type DWord -Value $OrigResp -Force
        }
        if ($OrigThrot -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue) -eq $null) {
            Set-ItemProperty -Path $BackupPath -Name "NetworkThrottlingIndex" -Type DWord -Value $OrigThrot -Force
        }
    }

    Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295 -Force

    # Prioridades de ejecución multimedia para videojuegos y File I/O balanceado
    $TasksPath = "$ProfilePath\Tasks\Games"
    if (!(Test-Path $TasksPath)) { New-Item -Path $TasksPath -Force | Out-Null }
    Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8 -Force
    Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 6 -Force
    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "High" -Force
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "High" -Force

    # Distribución del tráfico de red fuera del Núcleo 0 (IRQ Steering) con respaldo
    Write-Host "[*] Aplicando IRQ Steering salvando directivas de red previas..."
    $NetBackupKey = "$BackupPath\NetworkAffinity"
    if (!(Test-Path $NetBackupKey)) { New-Item -Path $NetBackupKey -Force | Out-Null }

    $NetDevices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters\Interrupt Management\Affinity Policy" -ErrorAction SilentlyContinue
    foreach ($Net in $NetDevices) {
        try {
            $DeviceID = ($Net.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
            
            $OrigPolicy = (Get-ItemProperty -Path $Net.PSPath -Name "DevicePolicy" -ErrorAction SilentlyContinue).DevicePolicy
            $OrigOverride = (Get-ItemProperty -Path $Net.PSPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue).AssignmentSetOverride

            if ((Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Policy" -ErrorAction SilentlyContinue) -eq $null) {
                $BckPolicy = if ($OrigPolicy -eq $null) { 999 } else { $OrigPolicy }
                Set-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Policy" -Type DWord -Value $BckPolicy -Force
                if ($OrigOverride) {
                    Set-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Override" -Type Binary -Value $OrigOverride -Force
                }
            }

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