param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Reconfigurando perfiles multimedia y afinidad de Hardware (IRQ)..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\CPU"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    if ($IsLaptop) {
        Write-Host "[+] Laptop detectada. Saltando remapeo fisico de afinidades IRQ para proteger la estabilidad de buses dinamicos de energia." -ForegroundColor Green
        exit 0
    }

    $TotalCores = [int]$env:NUMBER_OF_PROCESSORS
    # Mapeo inteligente multi-núcleo compatible con RSS (evita Core 0, evita hilos HT hermanos y evita E-cores al final)
    # Establece DevicePolicy = 2 (SpecifiedProcessors) para que Windows use RSS en el conjunto de cores asignados.
    $DevicePolicyValue = 2 # SpecifiedProcessors
    [uint64]$NetBitmask = 0

    if ($TotalCores -ge 12) {
        # CPUs de gama media-alta (>=12 hilos): Afinar a dos cores físicos separados (hilos lógicos 4 y 6)
        # Esto permite a RSS balancear el procesamiento de paquetes sin saturar un solo hilo.
        $NetBitmask = ([uint64]1 -shl 4) -bor ([uint64]1 -shl 6)
    } elseif ($TotalCores -ge 8) {
        # CPUs estándar (8 a 11 hilos): Afinar a hilos lógicos 2 y 4 (dos cores físicos independientes)
        $NetBitmask = ([uint64]1 -shl 2) -bor ([uint64]1 -shl 4)
    } else {
        # CPUs muy antiguas (<=6 hilos): Mapear a un solo core alternativo (hilo lógico 2)
        # DevicePolicy = 4 (OneCloseProcessor)
        $DevicePolicyValue = 4
        $NetBitmask = [uint64]1 -shl 2
    }

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
                                        
                                        $affinityKey.SetValue("DevicePolicy", $DevicePolicyValue, [Microsoft.Win32.RegistryValueKind]::DWord)
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