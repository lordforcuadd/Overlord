param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Reconfigurando perfiles multimedia y afinidad de Hardware (IRQ)..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\CPU"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $TasksPath = "$ProfilePath\Tasks\Games"
    if (!(Test-Path $TasksPath)) { New-Item -Path $TasksPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "Scheduling Category" -BackupSubFolder "CPU"
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "SFIO Priority" -BackupSubFolder "CPU"
    }

    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "High" -Force | Out-Null
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "High" -Force | Out-Null

    if ((Get-ItemProperty -Path $TasksPath -Name "Scheduling Category")."Scheduling Category" -ne "High") { Write-Warning "No se pudo asegurar Scheduling Category" }
    if ((Get-ItemProperty -Path $TasksPath -Name "SFIO Priority")."SFIO Priority" -ne "High") { Write-Warning "No se pudo asegurar SFIO Priority" }

    if ($IsLaptop) {
        Write-Host "[+] Laptop detectada. Saltando remapeo fisico de afinidades IRQ para proteger la estabilidad de buses dinamicos de energia." -ForegroundColor Green
        exit 0
    }

    $TotalCores = [int]$env:NUMBER_OF_PROCESSORS
    # Mapeo inteligente de afinidad para evitar E-Cores (que ocupan los hilos finales en arquitecturas híbridas Intel)
    $NetCoreIndex = 2 # Fallback seguro (hilo 2, tercer core si no hay HT, o segundo core con HT)
    if ($TotalCores -ge 16) {
        $NetCoreIndex = 4 # Hilo 4 (P-Core seguro en CPUs de 16+ hilos)
    } elseif ($TotalCores -ge 8) {
        $NetCoreIndex = 2 # Hilo 2 (P-Core seguro en CPUs de 8+ hilos)
    } else {
        $NetCoreIndex = 1 # Para CPUs muy antiguas de 2 o 4 hilos
    }

    [uint64]$NetBitmask = [uint64]1 -shl $NetCoreIndex

    $NetMaskBytes = [System.BitConverter]::GetBytes($NetBitmask)

    $NetBackupKey = "HKLM:\SOFTWARE\Overlord\Backup\CPU\NetworkAffinity"
    if (!(Test-Path $NetBackupKey)) { New-Item -Path $NetBackupKey -Force | Out-Null }

    $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $false)
    if ($pciKey) {
        foreach ($venId in $pciKey.GetSubKeyNames()) {
            $venKey = $pciKey.OpenSubKey($venId, $false)
            if ($venKey) {
                foreach ($devId in $venKey.GetSubKeyNames()) {
                    $devKey = $venKey.OpenSubKey($devId, $false)
                    if ($devKey) {
                        $class = $devKey.GetValue("Class")
                        
                        if ($class -eq "Net") {
                            try {
                                $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                                if ($paramKey) {
                                    $affinityKey = $paramKey.CreateSubKey("Interrupt Management\Affinity Policy", $true)
                                    if ($affinityKey) {
                                        $deviceRegID = "PCI_${venId}_${devId}_Device Parameters"
                                        $origPolicy = $affinityKey.GetValue("DevicePolicy")
                                        $origOverride = $affinityKey.GetValue("AssignmentSetOverride")
                                        
                                        if ((Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Policy" -ErrorAction SilentlyContinue) -eq $null) {
                                            $bckPolicy = if ($null -eq $origPolicy) { '_ABSENT_' } else { $origPolicy }
                                            Set-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Policy" -Value $bckPolicy -Force | Out-Null
                                            
                                            $bckOverride = if ($null -eq $origOverride) { '_ABSENT_' } else { $origOverride }
                                            Set-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Override" -Value $bckOverride -Force | Out-Null
                                        }
                                        
                                        $affinityKey.SetValue("DevicePolicy", 4, [Microsoft.Win32.RegistryValueKind]::DWord)
                                        $affinityKey.SetValue("AssignmentSetOverride", $NetMaskBytes, [Microsoft.Win32.RegistryValueKind]::Binary)
                                        $affinityKey.Close()
                                    }
                                    $paramKey.Close()
                                }
                            } catch {
                                Write-Warning "No se pudo configurar la afinidad de red para el dispositivo PCI $devId (sin permisos): $_"
                            }
                        }
                        

                        $devKey.Close()
                    }
                }
                $venKey.Close()
            }
        }
        $pciKey.Close()
    }

    Write-Host "[+] Carga equilibrada de hilos IRQ en P-Cores. Prioridades multimedia inyectadas con exito."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Gestion IRQ y Procesador: $_"
    exit 1
}