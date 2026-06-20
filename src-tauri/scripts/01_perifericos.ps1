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
                        } elseif ($class -eq "MEDIA" -or $class -eq "AudioEndpoint") {
                            $AllowMsi = $true
                        }

                        if ($AllowMsi) {
                            try {
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
                                    
                                    # Configurar prioridad de interrupción alta (DevicePriority = 3)
                                    $affinityPathName = "Interrupt Management\Affinity Policy"
                                    $affinityKey = $paramKey.CreateSubKey($affinityPathName, $true)
                                    if ($affinityKey) {
                                        $origPriority = $affinityKey.GetValue("DevicePriority")
                                        
                                        # Respaldo de prioridad original
                                        $priorityRegID = "PCI_${venId}_${devId}_DevicePriority"
                                        $backupPriorityCheck = Get-ItemProperty -Path $MsiBackupKey -Name $priorityRegID -ErrorAction SilentlyContinue
                                        if ($null -eq $backupPriorityCheck) {
                                            $backupPriorityVal = if ($null -eq $origPriority) { '_ABSENT_' } else { $origPriority }
                                            Set-ItemProperty -Path $MsiBackupKey -Name $priorityRegID -Value $backupPriorityVal -Force | Out-Null
                                        }
                                        
                                        $affinityKey.SetValue("DevicePriority", 3, [Microsoft.Win32.RegistryValueKind]::DWord)
                                        $affinityKey.Close()
                                    }
                                    
                                    $paramKey.Close()
                                }
                            } catch {
                                Write-Warning "No se pudo configurar MSI para el dispositivo PCI $devId (sin permisos): $_"
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

       # Configurar prioridad del planificador (Win32PrioritySeparation = 26)
    # 26 decimal = 0x1A (Quanta Corta, Fija, Foreground Boost 3:1). Evita stutters ante procesos en segundo plano.
    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    if (Test-Path $PriorityControlPath) {
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $PriorityControlPath -ValueName "Win32PrioritySeparation" -BackupSubFolder "Performance"
        }
        Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 26 -Force | Out-Null
        if ((Get-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation").Win32PrioritySeparation -ne 26) { 
            Write-Warning "No se pudo asegurar Win32PrioritySeparation" 
        }
    }

    # Desactivar Suspension Selectiva de USB (Optimizacion de energia de perifericos)
    try {
        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a8713cd-255e-4fc5-a639-12b87a5b3e8a d874b2c9-943b-47dd-9190-25e0e3c95a12 0 2>$null | Out-Null
        $ActivePlan = powercfg /getactivescheme 2>$null
        if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
            $CurrentGuid = $Matches[1]
            & powercfg /setactive $CurrentGuid 2>$null | Out-Null
        }
    } catch {
        Write-Warning "No se pudo desactivar USB Selective Suspend"
    }

    # Desactivar Aceleracion del Raton (Precision del Puntero)
    $MousePath = "HKCU:\Control Panel\Mouse"
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $MousePath -ValueName "MouseSpeed" -BackupSubFolder "Mouse"
        Backup-OverlordRegistryValue -TargetKey $MousePath -ValueName "MouseThreshold1" -BackupSubFolder "Mouse"
        Backup-OverlordRegistryValue -TargetKey $MousePath -ValueName "MouseThreshold2" -BackupSubFolder "Mouse"
    }
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "0" -Force | Out-Null

    if ((Get-ItemProperty -Path $MousePath -Name "MouseSpeed").MouseSpeed -ne "0") { 
        Write-Warning "No se pudo asegurar MouseSpeed lineal" 
    }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Control Panel\Accessibility\StickyKeys" -ValueName "Flags" -BackupSubFolder "Accessibility"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Control Panel\Accessibility\ToggleKeys" -ValueName "Flags" -BackupSubFolder "Accessibility"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "Flags" -BackupSubFolder "Accessibility"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "AutoRepeatDelay" -BackupSubFolder "Accessibility"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "AutoRepeatRate" -BackupSubFolder "Accessibility"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "DelayBeforeAcceptance" -BackupSubFolder "Accessibility"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Control Panel\Accessibility\Keyboard Response" -ValueName "BounceTime" -BackupSubFolder "Accessibility"
    }

    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "58" -Force | Out-Null
    
    $KeyRespPath = "HKCU:\Control Panel\Accessibility\Keyboard Response"
    Set-ItemProperty -Path $KeyRespPath -Name "Flags" -Type String -Value "59" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "AutoRepeatDelay" -Type String -Value "200" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "AutoRepeatRate" -Type String -Value "15" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "DelayBeforeAcceptance" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "BounceTime" -Type String -Value "0" -Force | Out-Null

    if ((Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags").Flags -ne "506") { 
        Write-Warning "No se pudo asegurar los Flags de StickyKeys stock" 
    }

    Write-Host "[+] Modulo de latencia de perifericos aplicado de forma limpia."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Perifericos Saneado: $_"
    exit 1
}