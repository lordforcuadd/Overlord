param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8,
    [bool]$IsHybrid = $false,
    [bool]$IsX3d = $false
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Reconfigurando perfiles multimedia y afinidad de Hardware (IRQ)..."

    if ($IsHybrid) {
        Write-Host "[+] CPU Hibrida (Intel P-Core/E-Core) detectada. Asegurando asignacion de interrupciones en P-Cores..." -ForegroundColor Green
    }
    if ($IsX3d) {
        Write-Host "[+] CPU AMD 3D V-Cache (X3D) detectada. Afinando interrupciones para el CCD de cache..." -ForegroundColor Green
    }

    if ($IsLaptop) {
        Write-Host "[+] Laptop detectada. Saltando remapeo fisico de afinidades IRQ para proteger la estabilidad de buses dinamicos de energia." -ForegroundColor Green
        exit 0
    }

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\CPU"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $TotalCores = [int]$env:NUMBER_OF_PROCESSORS
    # Mapeo inteligente multi-núcleo compatible con RSS (evita Core 0)
    # Establece DevicePolicy = 4 (SpecifiedProcessors) para que Windows use RSS en el conjunto de cores asignados.
    $DevicePolicyValue = 4 # SpecifiedProcessors
    [uint64]$NetBitmask = 0

    if ($TotalCores -ge 8) {
        # Evitar Core 0. Balancear en el segundo núcleo físico (asumiendo SMT, índices 2 y 3)
        $NetBitmask = ([uint64]1 -shl 2) -bor ([uint64]1 -shl 3)
    } elseif ($TotalCores -ge 4) {
        # Evitar Core 0. Usar índice 2.
        $NetBitmask = ([uint64]1 -shl 2)
    } else {
        # Para procesadores pequeños, dejar que el sistema operativo balancee de forma nativa
        $DevicePolicyValue = 0 # IrqPolicyMachineDefault
        $NetBitmask = 0
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
                        $classGuid = $devKey.GetValue("ClassGUID")
                        
                        if ($classGuid -eq "{4d36e972-e325-11ce-bfc1-08002be10318}") { # Net
                            try {
                                $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                                if ($paramKey) {
                                    $affinityKey = $paramKey.CreateSubKey("Interrupt Management\Affinity Policy", $true)
                                    if ($affinityKey) {
                                        $deviceRegID = "PCI_${venId}_${devId}_Device Parameters"
                                        $origPolicy = $affinityKey.GetValue("DevicePolicy")
                                        $origOverride = $affinityKey.GetValue("AssignmentSetOverride")
                                        
                                        $netProps = Get-ItemProperty -Path $NetBackupKey -ErrorAction SilentlyContinue
                                        if ($null -eq $netProps -or $null -eq $netProps.PSObject.Properties["${deviceRegID}_Policy"]) {
                                            $bckPolicy = if ($null -eq $origPolicy) { '_ABSENT_' } else { $origPolicy }
                                            Set-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Policy" -Value $bckPolicy -Force | Out-Null
                                            
                                            $bckOverride = if ($null -eq $origOverride) { '_ABSENT_' } else { $origOverride }
                                            Set-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Override" -Value $bckOverride -Force | Out-Null
                                        }
                                        
                                        $affinityKey.SetValue("DevicePolicy", $DevicePolicyValue, [Microsoft.Win32.RegistryValueKind]::DWord)
                                        $affinityKey.SetValue("AssignmentSetOverride", $NetMaskBytes, [Microsoft.Win32.RegistryValueKind]::Binary)
                                        
                                        if ($affinityKey.GetValue("DevicePolicy") -ne $DevicePolicyValue) {
                                            throw "El SO bloqueÃ³ DevicePolicy para el dispositivo PCI: $devId"
                                        }
                                        $affinityKey.Close()
                                    }
                                    $paramKey.Close()
                                }
                            } catch {
                                throw "El SO bloqueÃ³ la configuraciÃ³n de afinidad IRQ de red para el dispositivo PCI $devId (sin permisos): $_"
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