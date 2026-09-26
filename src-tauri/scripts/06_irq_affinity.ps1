param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8,
    [bool]$IsHybrid = $false,
    [bool]$IsX3d = $false
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Optimizando politicas de interrupcion de red (IRQ) y baja latencia DPC..."

    if ($IsLaptop) {
        Write-Host "[+] Laptop detectada. Saltando optimizaciones de interrupcion de red para proteger la autonomia y gestion de energia." -ForegroundColor Green
    } else {

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\CPU"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    # Para asegurar máxima compatibilidad con cualquier topología (Intel Hybrid, AMD X3D, 4-cores)
    # dejamos que el sistema operativo balancee de forma nativa (IrqPolicyMachineDefault)
    $DevicePolicyValue = 0 # IrqPolicyMachineDefault
    [uint64]$NetBitmask = 0

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
                                            Write-Warning "El SO bloqueó DevicePolicy para el dispositivo PCI: $devId"
                                        }
                                    }
                                }
                            } catch {
                                Write-Warning "El SO bloqueó la configuración de afinidad IRQ de red para el dispositivo PCI $devId (sin permisos): $_"
                            } finally {
                                if ($null -ne $affinityKey) { $affinityKey.Close(); $affinityKey = $null }
                                if ($null -ne $paramKey) { $paramKey.Close(); $paramKey = $null }
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
    }

    if (-not $IsLaptop) {
        Write-Host "    -> Desactivando Interrupt Moderation en adaptadores de red de escritorio para baja latencia..."
        if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
            $NetAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
            foreach ($Adapter in $NetAdapters) {
                if ($Adapter.Status -eq "Up" -or $Adapter.HardwareInterface -eq $true) {
                    try {
                        $AdapterBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Network\Adapters_State\$($Adapter.InterfaceGuid)"
                        if (!(Test-Path $AdapterBackupPath)) { New-Item -Path $AdapterBackupPath -Force -ErrorAction SilentlyContinue | Out-Null }
                        
                        $AdvProps = Get-NetAdapterAdvancedProperty -Name $Adapter.Name -ErrorAction SilentlyContinue
                        if ($null -ne $AdvProps) {
                            $IntMod = $AdvProps | Where-Object { $_.RegistryKeyword -match "^\*?InterruptModeration$" -or $_.DisplayName -match "Interrupt Moderation|Moderaci[oó]n de interrupciones" } | Select-Object -First 1
                            if ($null -ne $IntMod) {
                                $props = Get-ItemProperty -Path $AdapterBackupPath -ErrorAction SilentlyContinue
                                if ($null -eq $props -or $null -eq $props.PSObject.Properties["InterruptModerationVal"]) {
                                    $valToSave = if ($null -ne $IntMod.RegistryValue) { $IntMod.RegistryValue.ToString() } else { $IntMod.DisplayValue }
                                    Set-ItemProperty -Path $AdapterBackupPath -Name "InterruptModerationVal" -Value $valToSave -Type String -Force -ErrorAction SilentlyContinue | Out-Null
                                    $keyToSave = if ($IntMod.RegistryKeyword) { $IntMod.RegistryKeyword } else { $IntMod.DisplayName }
                                    Set-ItemProperty -Path $AdapterBackupPath -Name "InterruptModerationKey" -Value $keyToSave -Type String -Force -ErrorAction SilentlyContinue | Out-Null
                                }
                                if ($IntMod.RegistryKeyword) {
                                    Set-NetAdapterAdvancedProperty -Name $Adapter.Name -RegistryKeyword $IntMod.RegistryKeyword -RegistryValue "0" -ErrorAction SilentlyContinue | Out-Null
                                } else {
                                    Set-NetAdapterAdvancedProperty -Name $Adapter.Name -DisplayName $IntMod.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue | Out-Null
                                }
                            }
                        }
                    } catch {
                        Write-Verbose "[$($Adapter.Name)] Interrupt Moderation no soportado: $_"
                    }
                }
            }
        }
    }

    Write-Host "[+] Gestion de politicas de interrupcion (IRQ) completada con exito."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Gestion IRQ y Procesador: $_"
    exit 1
}
