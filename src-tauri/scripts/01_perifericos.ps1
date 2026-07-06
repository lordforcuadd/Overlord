param(
    [bool]$IsLaptop = $false
)

$ErrorActionPreference = "Stop"

Try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }
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
                        $classGuid = $devKey.GetValue("ClassGUID")
                        
                        $AllowMsi = $false
                        if ($classGuid -eq "{4d36e968-e325-11ce-bfc1-08002be10318}") { # Display
                            $AllowMsi = $true
                        } elseif ($classGuid -eq "{36fc9e60-c465-11cf-8056-444553540000}" -and -not $IsLaptop) { # USB
                            $AllowMsi = $true
                        } elseif ($classGuid -eq "{4d36e97c-e325-11ce-bfc1-08002be10318}" -or $classGuid -eq "{c166523b-fe0c-4a94-a586-f1a8096b7efe}") { # MEDIA / AudioEndpoint
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
                                        
                                        $msiProps = Get-ItemProperty -Path $MsiBackupKey -ErrorAction SilentlyContinue
                                        if ($null -eq $msiProps -or $null -eq $msiProps.PSObject.Properties[$deviceRegID]) {
                                            $backupVal = if ($null -eq $origMsi) { '_ABSENT_' } else { $origMsi }
                                            Set-ItemProperty -Path $MsiBackupKey -Name $deviceRegID -Value $backupVal -Force | Out-Null
                                        }
                                        
                                        $interruptKey.SetValue("MSISupported", 1, [Microsoft.Win32.RegistryValueKind]::DWord)
                                        
                                        if ($interruptKey.GetValue("MSISupported") -ne 1) { 
                                            throw "El SO bloqueÃ³ MSISupported para el dispositivo PCI: $devId" 
                                        }
                                        $interruptKey.Close()
                                    }
                                    
                                    # Configurar prioridad de interrupciÃ³n alta (DevicePriority = 3)
                                    $affinityPathName = "Interrupt Management\Affinity Policy"
                                    $affinityKey = $paramKey.CreateSubKey($affinityPathName, $true)
                                    if ($affinityKey) {
                                        $origPriority = $affinityKey.GetValue("DevicePriority")
                                        
                                        # Respaldo de prioridad original
                                        $priorityRegID = "PCI_${venId}_${devId}_DevicePriority"
                                        $priorityProps = Get-ItemProperty -Path $MsiBackupKey -ErrorAction SilentlyContinue
                                        if ($null -eq $priorityProps -or $null -eq $priorityProps.PSObject.Properties[$priorityRegID]) {
                                            $backupPriorityVal = if ($null -eq $origPriority) { '_ABSENT_' } else { $origPriority }
                                            Set-ItemProperty -Path $MsiBackupKey -Name $priorityRegID -Value $backupPriorityVal -Force | Out-Null
                                        }
                                        
                                        $affinityKey.SetValue("DevicePriority", 3, [Microsoft.Win32.RegistryValueKind]::DWord)
                                        $affinityKey.Close()
                                    }
                                    
                                    $paramKey.Close()
                                }
                            } catch {
                                throw "El SO bloqueÃ³ MSI para el dispositivo PCI $devId (sin permisos): $_"
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
        Backup-OverlordRegistryValue -TargetKey $PriorityControlPath -ValueName "Win32PrioritySeparation" -BackupSubFolder "Performance"
        Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Type DWord -Value 26 -Force | Out-Null
        if ((Get-ItemProperty -Path $PriorityControlPath -ErrorAction SilentlyContinue).Win32PrioritySeparation -ne 26) { 
            throw "El SO bloqueÃ³ Win32PrioritySeparation" 
        }
    }

    # Desactivar Suspension Selectiva de USB (Optimizacion de energia de perifericos)
    try {
        $ActivePlan = powercfg /getactivescheme 2>$null
        if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
            $CurrentGuid = $Matches[1]
            Backup-OverlordPowerSetting -SchemeGuid $CurrentGuid -SubGroupGuid "2a8713cd-255e-4fc5-a639-12b87a5b3e8a" -SettingGuid "d874b2c9-943b-47dd-9190-25e0e3c95a12" -BackupName "Power_${CurrentGuid}_d874b2c9-943b-47dd-9190-25e0e3c95a12"
        }
        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a8713cd-255e-4fc5-a639-12b87a5b3e8a d874b2c9-943b-47dd-9190-25e0e3c95a12 0 2>$null | Out-Null
        if ($CurrentGuid) {
            & powercfg /setactive $CurrentGuid 2>$null | Out-Null
        }
    } catch {
        throw "El SO bloqueÃ³ la desactivaciÃ³n de USB Selective Suspend"
    }

    # Desactivar Aceleracion del Raton (Precision del Puntero)
    $MousePath = "$HKCU_Path\Control Panel\Mouse"
    Backup-OverlordRegistryValue -TargetKey $MousePath -ValueName "MouseSpeed" -BackupSubFolder "Mouse"
    Backup-OverlordRegistryValue -TargetKey $MousePath -ValueName "MouseThreshold1" -BackupSubFolder "Mouse"
    Backup-OverlordRegistryValue -TargetKey $MousePath -ValueName "MouseThreshold2" -BackupSubFolder "Mouse"
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Type String -Value "0" -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $MousePath -Name "MouseSpeed" -ErrorAction SilentlyContinue) -ne "0") { 
        throw "El SO bloqueÃ³ MouseSpeed lineal" 
    }

    $StickyPath = "$HKCU_Path\Control Panel\Accessibility\StickyKeys"
    $TogglePath = "$HKCU_Path\Control Panel\Accessibility\ToggleKeys"
    $KeyRespPath = "$HKCU_Path\Control Panel\Accessibility\Keyboard Response"

    if (!(Test-Path $StickyPath)) { New-Item -Path $StickyPath -Force | Out-Null }
    if (!(Test-Path $TogglePath)) { New-Item -Path $TogglePath -Force | Out-Null }
    if (!(Test-Path $KeyRespPath)) { New-Item -Path $KeyRespPath -Force | Out-Null }

    Backup-OverlordRegistryValue -TargetKey $StickyPath -ValueName "Flags" -BackupSubFolder "Accessibility"
    Backup-OverlordRegistryValue -TargetKey $TogglePath -ValueName "Flags" -BackupSubFolder "Accessibility"
    Backup-OverlordRegistryValue -TargetKey $KeyRespPath -ValueName "Flags" -BackupSubFolder "Accessibility"
    Backup-OverlordRegistryValue -TargetKey $KeyRespPath -ValueName "AutoRepeatDelay" -BackupSubFolder "Accessibility"
    Backup-OverlordRegistryValue -TargetKey $KeyRespPath -ValueName "AutoRepeatRate" -BackupSubFolder "Accessibility"
    Backup-OverlordRegistryValue -TargetKey $KeyRespPath -ValueName "DelayBeforeAcceptance" -BackupSubFolder "Accessibility"
    Backup-OverlordRegistryValue -TargetKey $KeyRespPath -ValueName "BounceTime" -BackupSubFolder "Accessibility"

    Set-ItemProperty -Path $StickyPath -Name "Flags" -Type String -Value "506" -Force | Out-Null
    Set-ItemProperty -Path $TogglePath -Name "Flags" -Type String -Value "58" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "Flags" -Type String -Value "59" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "AutoRepeatDelay" -Type String -Value "200" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "AutoRepeatRate" -Type String -Value "15" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "DelayBeforeAcceptance" -Type String -Value "0" -Force | Out-Null
    Set-ItemProperty -Path $KeyRespPath -Name "BounceTime" -Type String -Value "0" -Force | Out-Null

    if ((Get-ItemPropertyValue -Path $StickyPath -Name "Flags" -ErrorAction SilentlyContinue) -ne "506") { 
        throw "El SO bloqueÃ³ los Flags de StickyKeys stock" 
    }

    Write-Host "[+] Modulo de latencia de perifericos aplicado de forma limpia."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Perifericos Saneado: $_"
    exit 1
}