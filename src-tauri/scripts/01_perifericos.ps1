param(
    [bool]$IsLaptop = $false
)

$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando inyeccion de Latencia de Perifericos..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $MsiBackupKey = "HKLM:\SOFTWARE\Overlord\Backup\MSI"
    if (!(Test-Path $MsiBackupKey)) { New-Item -Path $MsiBackupKey -Force | Out-Null }

    $pciKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Enum\PCI", $false)
    if ($pciKey) {
        foreach ($venId in $pciKey.GetSubKeyNames()) {
            $venKey = $pciKey.OpenSubKey($venId, $false)
            if ($venKey) {
                foreach ($devId in $venKey.GetSubKeyNames()) {
                    $devKey = $venKey.OpenSubKey($devId, $false)
                    if ($devKey) {
                        $class = $devKey.GetValue("Class")
                        
                        
                        $AllowMsi = $false
                        if ($class -eq "Display") {
                            $AllowMsi = $true
                        } elseif ($class -eq "USB" -and -not $IsLaptop) {
                            $AllowMsi = $true
                        }

                        if ($AllowMsi) {
                            $paramKey = $devKey.OpenSubKey("Device Parameters", $true)
                            if ($paramKey) {
                                $deviceRegID = "PCI_${venId}_${devId}_Device Parameters"
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
                                    
                                    if ($interruptKey.GetValue("MSISupported") -ne 1) { 
                                        Write-Warning "No se pudo asegurar MSISupported para el dispositivo PCI: $devId" 
                                    }
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

    
    $QueueSize = 64

    $MouPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    if (Test-Path $MouPath) {
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $MouPath -ValueName "MouseDataQueueSize" -BackupSubFolder "mouclass"
        }
        Set-ItemProperty -Path $MouPath -Name "MouseDataQueueSize" -Type DWord -Value $QueueSize -Force | Out-Null
        if ((Get-ItemProperty -Path $MouPath -Name "MouseDataQueueSize").MouseDataQueueSize -ne $QueueSize) { 
            Write-Warning "No se pudo asegurar MouseDataQueueSize" 
        }
    }

    $KbdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    if (Test-Path $KbdPath) {
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $KbdPath -ValueName "KeyboardDataQueueSize" -BackupSubFolder "kbdclass"
        }
        Set-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize" -Type DWord -Value $QueueSize -Force | Out-Null
        if ((Get-ItemProperty -Path $KbdPath -Name "KeyboardDataQueueSize").KeyboardDataQueueSize -ne $QueueSize) { 
            Write-Warning "No se pudo asegurar KeyboardDataQueueSize" 
        }
    }

    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    if (Test-Path $PriorityControlPath) {
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $PriorityControlPath -ValueName "Win32PrioritySeparation" -BackupSubFolder "Performance"
        }
        Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 38 -Force | Out-Null
        if ((Get-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation").Win32PrioritySeparation -ne 38) { 
            Write-Warning "No se pudo asegurar Win32PrioritySeparation" 
        }
    }

    $MousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "0" -Force | Out-Null
    
    $zeroBytes = [byte[]]::new(40)
    Set-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve" -Type Binary -Value $zeroBytes -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "SmoothMouseYCurve" -Type Binary -Value $zeroBytes -Force | Out-Null

    if ((Get-ItemProperty -Path $MousePath -Name "MouseSpeed").MouseSpeed -ne "0") { 
        Write-Warning "No se pudo asegurar MouseSpeed lineal" 
    }

    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "58" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "122" -Force | Out-Null

    if ((Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags").Flags -ne "506") { 
        Write-Warning "No se pudo asegurar los Flags de StickyKeys stock" 
    }

    Write-Host "[+] Modulo de latencia de perifericos aplicado de forma limpia."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Perifericos Saneado: $_"
    exit 1
}