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
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "GPU Priority" -BackupSubFolder "CPU"
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "Priority" -BackupSubFolder "CPU"
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "Scheduling Category" -BackupSubFolder "CPU"
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "SFIO Priority" -BackupSubFolder "CPU"
    }

    Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8 -Force | Out-Null
    Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 6 -Force | Out-Null
    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "High" -Force | Out-Null
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "High" -Force | Out-Null

    if ((Get-ItemProperty -Path $TasksPath -Name "GPU Priority")."GPU Priority" -ne 8) { throw "Verification failed" }
    if ((Get-ItemProperty -Path $TasksPath -Name "Priority").Priority -ne 6) { throw "Verification failed" }
    if ((Get-ItemProperty -Path $TasksPath -Name "Scheduling Category")."Scheduling Category" -ne "High") { throw "Verification failed" }
    if ((Get-ItemProperty -Path $TasksPath -Name "SFIO Priority")."SFIO Priority" -ne "High") { throw "Verification failed" }

    $NetBackupKey = "HKLM:\SOFTWARE\Overlord\Backup\CPU\NetworkAffinity"
    if (!(Test-Path $NetBackupKey)) { New-Item -Path $NetBackupKey -Force | Out-Null }

    $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $true)
    if ($pciKey) {
        foreach ($venId in $pciKey.GetSubKeyNames()) {
            $venKey = $pciKey.OpenSubKey($venId, $true)
            if ($venKey) {
                foreach ($devId in $venKey.GetSubKeyNames()) {
                    $devKey = $venKey.OpenSubKey($devId, $true)
                    if ($devKey) {
                        $class = $devKey.GetValue("Class")
                        
                        if ($class -eq "Net") {
                            $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                            if ($paramKey) {
                                $affinityKey = $paramKey.CreateSubKey("Interrupt Management\Affinity Policy", $true)
                                if ($affinityKey) {
                                    $deviceRegID = "PCI_$venId`_$devId`_Device Parameters"
                                    
                                    $origPolicy = $affinityKey.GetValue("DevicePolicy")
                                    $origOverride = $affinityKey.GetValue("AssignmentSetOverride")
                                    
                                    if ((Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Policy" -ErrorAction SilentlyContinue) -eq $null) {
                                        $bckPolicy = if ($null -eq $origPolicy) { '_ABSENT_' } else { $origPolicy }
                                        Set-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Policy" -Value $bckPolicy -Force | Out-Null
                                        
                                        $bckOverride = if ($null -eq $origOverride) { '_ABSENT_' } else { $origOverride }
                                        Set-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_Override" -Value $bckOverride -Force | Out-Null
                                    }
                                    
                                    $affinityKey.SetValue("DevicePolicy", 4, [Microsoft.Win32.RegistryValueKind]::DWord)
                                    $maskBytes = [System.BitConverter]::GetBytes([int]4)
                                    $affinityKey.SetValue("AssignmentSetOverride", $maskBytes, [Microsoft.Win32.RegistryValueKind]::Binary)
                                    
                                    if ($affinityKey.GetValue("DevicePolicy") -ne 4) { throw "Verification failed" }
                                    $affinityKey.Close()
                                }
                                $paramKey.Close()
                            }
                        }
                        
                        if ($class -eq "MEDIA") {
                            $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                            if ($paramKey) {
                                $affinityKey = $paramKey.CreateSubKey("Interrupt Management\Affinity Policy", $true)
                                if ($affinityKey) {
                                    $deviceRegID = "PCI_$venId`_$devId`_Device Parameters"
                                    
                                    $origAudioPolicy = $affinityKey.GetValue("DevicePolicy")
                                    $origAudioOverride = $affinityKey.GetValue("AssignmentSetOverride")
                                    
                                    if ((Get-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_AudioPolicy" -ErrorAction SilentlyContinue) -eq $null) {
                                        $bckAudioPolicy = if ($null -eq $origAudioPolicy) { '_ABSENT_' } else { $origAudioPolicy }
                                        Set-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_AudioPolicy" -Value $bckAudioPolicy -Force | Out-Null
                                        
                                        $bckAudioOverride = if ($null -eq $origAudioOverride) { '_ABSENT_' } else { $origAudioOverride }
                                        Set-ItemProperty -Path $NetBackupKey -Name "${deviceRegID}_AudioOverride" -Value $bckAudioOverride -Force | Out-Null
                                    }
                                    
                                    $affinityKey.SetValue("DevicePolicy", 4, [Microsoft.Win32.RegistryValueKind]::DWord)
                                    $audioMaskBytes = [System.BitConverter]::GetBytes([int]2)
                                    $affinityKey.SetValue("AssignmentSetOverride", $audioMaskBytes, [Microsoft.Win32.RegistryValueKind]::Binary)
                                    
                                    if ($affinityKey.GetValue("DevicePolicy") -ne 4) { throw "Verification failed" }
                                    $affinityKey.Close()
                                }
                                $paramKey.Close()
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

    Write-Host "[+] Carga equilibrada en los núcleos del CPU. Prioridades multimedia inyectadas."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Gestion IRQ y Procesador: $_"
    exit 1
}