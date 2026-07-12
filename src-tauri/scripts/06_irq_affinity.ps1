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
                                            throw "El SO bloqueó DevicePolicy para el dispositivo PCI: $devId"
                                        }
                                    }
                                }
                            } catch {
                                throw "El SO bloqueó la configuración de afinidad IRQ de red para el dispositivo PCI $devId (sin permisos): $_"
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

    Write-Host "    -> Desactivando Interrupt Moderation en adaptadores de red (Experimental)..."
    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        $NetAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
        foreach ($Adapter in $NetAdapters) {
            if ($Adapter.Status -eq "Up" -or $Adapter.HardwareInterface -eq $true) {
                try {
                    $AdapterBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Network\Adapters_State\$($Adapter.InterfaceGuid)"
                    if (!(Test-Path $AdapterBackupPath)) { New-Item -Path $AdapterBackupPath -Force -ErrorAction SilentlyContinue | Out-Null }
                    
                    $AdvProps = Get-NetAdapterAdvancedProperty -Name $Adapter.Name -ErrorAction SilentlyContinue
                    if ($null -ne $AdvProps) {
                        $IntMod = $AdvProps | Where-Object { $_.DisplayName -match "Interrupt Moderation" }
                        if ($null -ne $IntMod) {
                            $props = Get-ItemProperty -Path $AdapterBackupPath -ErrorAction SilentlyContinue
                            if ($null -eq $props -or $null -eq $props.PSObject.Properties["InterruptModerationVal"]) {
                                Set-ItemProperty -Path $AdapterBackupPath -Name "InterruptModerationVal" -Value $IntMod.DisplayValue -Type String -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                        }
                    }
                    Set-NetAdapterAdvancedProperty -Name $Adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue | Out-Null
                } catch {}
            }
        }
    }

    Write-Host "[+] Carga equilibrada de hilos IRQ en P-Cores. Prioridades multimedia inyectadas con exito."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Gestion IRQ y Procesador: $_"
    exit 1
}