param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando inyeccion de Latencia de Perifericos..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    if (-not $IsLaptop) {
        try {
            $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
            $PowerGuid = if ($ActivePlan) { $ActivePlan.InstanceID.Split('\')[1] } else { "381b4222-f694-41f0-9685-ff5bb260df2e" }
            
            powercfg /SETACVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
            powercfg /SETDCVALUEINDEX $PowerGuid 2a737441-1930-4402-8d77-b2bea128a440 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
            powercfg /SETACTIVE $PowerGuid | Out-Null
        } catch {}
    }

    $MsiBackupKey = "HKLM:\SOFTWARE\Overlord\Backup\MSI"
    if (!(Test-Path $MsiBackupKey)) { New-Item -Path $MsiBackupKey -Force | Out-Null }

    $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $true)
    if ($pciKey) {
        foreach ($venId in $pciKey.GetSubKeyNames()) {
            $venKey = $pciKey.OpenSubKey($venId, $true)
            if ($venKey) {
                foreach ($devId in $venKey.GetSubKeyNames()) {
                    $devKey = $venKey.OpenSubKey($devId, $true)
                    if ($devKey) {
                        $class = $devKey.GetValue("Class")
                        if ($class -eq "Display" -or $class -eq "USB") {
                            $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                            if ($paramKey) {
                                $deviceRegID = "PCI_$venId`_$devId`_Device Parameters"
                                $msiPathName = "Interrupt Management\MessageSignaledInterruptProperties"
                                
                                $interruptKey = $paramKey.CreateSubKey($msiPathName, $true)
                                if ($interruptKey) {
                                    $origMsi = $interruptKey.GetValue("MSISupported")
                                    
                                    $backupCheck = Get-ItemProperty -Path $MsiBackupKey -Name $deviceRegID -ErrorAction SilentlyContinue
                                    if ($null -eq $backupCheck) {
                                        $backupVal = if ($null -eq $origMsi) { '_ABSENT_' } else { $origMsi }
                                        Set-ItemProperty -Path $MsiBackupKey -Name $deviceRegID -Value $backupVal -Force | Out-Null
                                    }
                                    
                                    $interruptKey.SetValue("MSISupported", 1, [Microsoft.Win32.RegistryValueKind]::DWord)
                                    if ($interruptKey.GetValue("MSISupported") -ne 1) { throw "Verification failed" }
                                    $interruptKey.Close()
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

    $MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    if (Test-Path $MouPath) {
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $MouPath -ValueName "MouseDataQueueSize" -BackupSubFolder "mouclass"
        }
        Set-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -Type DWord -Value 32 -Force | Out-Null
        if ((Get-ItemProperty -Path $MouPath -Name "MouseDataQueueSize").MouseDataQueueSize -ne 32) { throw "Verification failed" }
    }

    $KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    if (Test-Path $KbdPath) {
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $KbdPath -ValueName "KeyboardDataQueueSize" -BackupSubFolder "kbdclass"
        }
        Set-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -Type DWord -Value 32 -Force | Out-Null
        if ((Get-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize").KeyboardDataQueueSize -ne 32) { throw "Verification failed" }
    }

    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    if (Test-Path $PriorityControlPath) {
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $PriorityControlPath -ValueName "Win32PrioritySeparation" -BackupSubFolder "Performance"
        }
        Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 38 -Force | Out-Null
        if ((Get-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation").Win32PrioritySeparation -ne 38) { throw "Verification failed" }
    }

    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "0" -Force | Out-Null
    
    $zeroBytes = [byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    Set-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -Type Binary -Value $zeroBytes -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -Type Binary -Value $zeroBytes -Force | Out-Null

    if ((Get-ItemProperty -Path $MousePath -Name "MouseSpeed").MouseSpeed -ne "0") { throw "Verification failed" }

    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "58" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "122" -Force | Out-Null

    if ((Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags").Flags -ne "506") { throw "Verification failed" }

    Write-Host "[+] Modulo de latencia de perifericos aplicado de forma limpia."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Perifericos Saneado: $_"
    exit 1
}