param(
    [bool]$IsLaptop = $false
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando optimizacion cientifica de la pila de red TCP/IP..."

    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

    if (!(Test-Path $TcpPath)) { New-Item -Path $TcpPath -Force | Out-Null }
    if (!(Test-Path $ProfilePath)) { New-Item -Path $ProfilePath -Force | Out-Null }
    
    Backup-OverlordRegistryValue -TargetKey $ProfilePath -ValueName "NetworkThrottlingIndex" -BackupSubFolder "Network"
    Backup-OverlordRegistryValue -TargetKey $ProfilePath -ValueName "SystemResponsiveness" -BackupSubFolder "Network"
    Backup-OverlordRegistryValue -TargetKey $TcpPath -ValueName "InitialRto" -BackupSubFolder "Network"

    Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value ([uint32]4294967295) -Force | Out-Null
    Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Type DWord -Value 10 -Force | Out-Null
    Set-ItemProperty -Path $TcpPath -Name "InitialRto" -Type DWord -Value 2000 -Force | Out-Null
 
    if ((Get-ItemPropertyValue -Path $ProfilePath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue) -ne 10) { throw "Verification failed" }
    if ((Get-ItemPropertyValue -Path $TcpPath -Name "InitialRto" -ErrorAction SilentlyContinue) -ne 2000) { throw "Verification failed" }
    
    $throttingVal = Get-ItemPropertyValue -Path $ProfilePath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue
    if ($null -eq $throttingVal -or [uint32]$throttingVal -ne [uint32]4294967295) { throw "Verification failed" }

    
    $InterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $InterfacesPath) {
        $InterfaceKeys = Get-ChildItem -Path $InterfacesPath -ErrorAction SilentlyContinue
        foreach ($Key in $InterfaceKeys) {
            try {
                Backup-OverlordRegistryValue -TargetKey $Key.PSPath -ValueName "TcpAckFrequency" -BackupSubFolder "Network\Interfaces\$($Key.PSChildName)"
                Backup-OverlordRegistryValue -TargetKey $Key.PSPath -ValueName "TcpNoDelay" -BackupSubFolder "Network\Interfaces\$($Key.PSChildName)"
                Set-ItemProperty -Path $Key.PSPath -Name "TcpAckFrequency" -Type DWord -Value 1 -Force | Out-Null
                Set-ItemProperty -Path $Key.PSPath -Name "TcpNoDelay" -Type DWord -Value 1 -Force | Out-Null
            } catch {
                throw "No se pudo configurar TcpAckFrequency/TcpNoDelay para la interfaz $($Key.PSChildName): $_"
            }
        }
    }

    $NetClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $NetClassPath) {
        $RunningOnBattery = $false
        if ($IsLaptop) {
            $BatteryStatus = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue
            if ($null -ne $BatteryStatus -and $BatteryStatus.PowerOnline -eq $false) {
                $RunningOnBattery = $true
            }
        }

        # Obtener adaptadores fÃ­sicos activos (Ethernet y Wi-Fi)
        $ActiveGuids = @()
        $EthernetGuids = @()
        if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
            $ActiveGuids = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
                $_.Virtual -eq $false
            } | ForEach-Object { "$($_.InterfaceGuid)" }

            $EthernetGuids = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
                $_.Virtual -eq $false -and 
                $_.NdisPhysicalMedium -eq 14 
            } | ForEach-Object { "$($_.InterfaceGuid)" }
        }

        $NetAdapters = Get-ChildItem -Path $NetClassPath -ErrorAction SilentlyContinue
        foreach ($Adapter in $NetAdapters) {
            if ($Adapter.PSChildName -match "^\d{4}$") {
                $NetInstanceId = Get-ItemPropertyValue -Path $Adapter.PSPath -Name "NetCfgInstanceId" -ErrorAction SilentlyContinue
                if ($null -ne $NetInstanceId) {
                    # 1. Aplicar optimizaciones clÃ¡sicas de energÃ­a (EEE, Green Energy) solo a Ethernet
                    if ($EthernetGuids -contains $NetInstanceId) {
                        $PowerKeys = @("*EEE", "EEE", "*GreenEnergy", "GreenEnergy", "*EEELinkAdvertisement", "EEELinkAdvertisement", "*EnergyEfficientEthernet", "EnergyEfficientEthernet")
                        
                        # Desactivar Coalescencia, ModeraciÃ³n de InterrupciÃ³n y Control de Flujo Ãºnicamente en PCs de Escritorio con >8 hilos lÃ³gicos
                        $TotalThreads = [int]$env:NUMBER_OF_PROCESSORS
                        if (-not $IsLaptop -or $TotalThreads -gt 8) {
                            $PowerKeys += "*PacketCoalescing", "PacketCoalescing", "*InterruptModeration", "InterruptModeration", "*FlowControl", "FlowControl"
                        }

                        $adapterProps = Get-ItemProperty -Path $Adapter.PSPath -ErrorAction SilentlyContinue
                        foreach ($PKey in $PowerKeys) {
                            if ($null -ne $adapterProps -and $null -ne $adapterProps.PSObject.Properties[$PKey]) {
                                Backup-OverlordRegistryValue -TargetKey $Adapter.PSPath -ValueName $PKey -BackupSubFolder "Network\Adapters\$($Adapter.PSChildName)"
                                if ($PKey -eq "*PacketCoalescing" -or $PKey -eq "PacketCoalescing") {
                                    if (-not $IsLaptop) {
                                        Set-ItemProperty -Path $Adapter.PSPath -Name $PKey -Type String -Value "0" -Force | Out-Null
                                    }
                                } else {
                                    Set-ItemProperty -Path $Adapter.PSPath -Name $PKey -Type String -Value "0" -Force | Out-Null
                                }
                                $checkVal = Get-ItemPropertyValue -Path $Adapter.PSPath -Name $PKey -ErrorAction SilentlyContinue
                                if ($checkVal -ne "0" -and -not ($IsLaptop -and ($PKey -eq "*PacketCoalescing" -or $PKey -eq "PacketCoalescing"))) {
                                    throw "Fallo de validacion: No se pudo establecer $PKey en 0 para el adaptador $($Adapter.PSChildName)"
                                }
                            }
                        }
                    }

                    # Optimizaciones de Power Management se aplican ahora mediante Cmdlets en el bloque inferior
                }
            }
        }
    }

    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        $Adapters = Get-NetAdapter -ErrorAction SilentlyContinue
        foreach ($Adapter in $Adapters) {
            if ($Adapter.Status -eq "Up" -or $Adapter.HardwareInterface -eq $true) {
                # Evitar optimizaciones de descarga y latencia agresivas en adaptadores Wi-Fi
                $IsWiFi = $Adapter.PhysicalMediaType -match "802.11" -or $Adapter.MediaType -match "Wireless" -or $Adapter.Name -match "Wi-Fi|Wireless|wlan"
                if ($IsWiFi) {
                    Write-Host "    -> Saltando optimizaciones de bajo nivel para adaptador Wi-Fi ($($Adapter.Name)) para preservar estabilidad de enlace inalambrico."
                    continue
                }
                
                try {
                    # Backup del estado original de LSO, RSC y RSS para este adaptador
                    $AdapterBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Network\Adapters_State\$($Adapter.InterfaceGuid)"
                    if (!(Test-Path $AdapterBackupPath)) { 
                        try { New-Item -Path $AdapterBackupPath -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
                    }

                    if (Test-Path $AdapterBackupPath) {
                        $backupProps = Get-ItemProperty -Path $AdapterBackupPath -ErrorAction SilentlyContinue
                        $Lso = Get-NetAdapterLso -Name $Adapter.Name -ErrorAction SilentlyContinue
                        if ($null -ne $Lso) {
                            if ($null -eq $backupProps -or $null -eq $backupProps.PSObject.Properties["LsoIPv4"]) {
                                Set-ItemProperty -Path $AdapterBackupPath -Name "LsoIPv4" -Value (if ($Lso.IPv4Enabled) { 1 } else { 0 }) -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                                Set-ItemProperty -Path $AdapterBackupPath -Name "LsoIPv6" -Value (if ($Lso.IPv6Enabled) { 1 } else { 0 }) -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                        }

                        $Rsc = Get-NetAdapterRsc -Name $Adapter.Name -ErrorAction SilentlyContinue
                        if ($null -ne $Rsc) {
                            if ($null -eq $backupProps -or $null -eq $backupProps.PSObject.Properties["RscIPv4"]) {
                                Set-ItemProperty -Path $AdapterBackupPath -Name "RscIPv4" -Value (if ($Rsc.IPv4Enabled) { 1 } else { 0 }) -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                                Set-ItemProperty -Path $AdapterBackupPath -Name "RscIPv6" -Value (if ($Rsc.IPv6Enabled) { 1 } else { 0 }) -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                        }

                        $Rss = Get-NetAdapterRss -Name $Adapter.Name -ErrorAction SilentlyContinue
                        if ($null -ne $Rss) {
                            if ($null -eq $backupProps -or $null -eq $backupProps.PSObject.Properties["RssProfile"]) {
                                Set-ItemProperty -Path $AdapterBackupPath -Name "RssProfile" -Value $Rss.Profile.ToString() -Type String -Force -ErrorAction SilentlyContinue | Out-Null
                                Set-ItemProperty -Path $AdapterBackupPath -Name "RssEnabled" -Value (if ($Rss.Enabled) { 1 } else { 0 }) -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                        }

                        $Chk = Get-NetAdapterChecksumOffload -Name $Adapter.Name -ErrorAction SilentlyContinue
                        if ($null -ne $Chk) {
                            $props = Get-ItemProperty -Path $AdapterBackupPath -ErrorAction SilentlyContinue
                            if ($null -eq $props -or $null -eq $props.PSObject.Properties["ChecksumIpIPv4"]) {
                                if ($null -ne $Chk -and $null -ne $Chk.PSObject.Properties["IpIPv4Enabled"]) { Set-ItemProperty -Path $AdapterBackupPath -Name "ChecksumIpIPv4" -Value $Chk.IpIPv4Enabled.ToString() -Type String -Force -ErrorAction SilentlyContinue | Out-Null }
                                if ($null -ne $Chk -and $null -ne $Chk.PSObject.Properties["TcpIPv4Enabled"]) { Set-ItemProperty -Path $AdapterBackupPath -Name "ChecksumTcpIPv4" -Value $Chk.TcpIPv4Enabled.ToString() -Type String -Force -ErrorAction SilentlyContinue | Out-Null }
                                if ($null -ne $Chk -and $null -ne $Chk.PSObject.Properties["TcpIPv6Enabled"]) { Set-ItemProperty -Path $AdapterBackupPath -Name "ChecksumTcpIPv6" -Value $Chk.TcpIPv6Enabled.ToString() -Type String -Force -ErrorAction SilentlyContinue | Out-Null }
                                if ($null -ne $Chk -and $null -ne $Chk.PSObject.Properties["UdpIPv4Enabled"]) { Set-ItemProperty -Path $AdapterBackupPath -Name "ChecksumUdpIPv4" -Value $Chk.UdpIPv4Enabled.ToString() -Type String -Force -ErrorAction SilentlyContinue | Out-Null }
                                if ($null -ne $Chk -and $null -ne $Chk.PSObject.Properties["UdpIPv6Enabled"]) { Set-ItemProperty -Path $AdapterBackupPath -Name "ChecksumUdpIPv6" -Value $Chk.UdpIPv6Enabled.ToString() -Type String -Force -ErrorAction SilentlyContinue | Out-Null }
                            }
                        }

                        $PwrMgmt = Get-NetAdapterPowerManagement -Name $Adapter.Name -ErrorAction SilentlyContinue
                        if ($null -ne $PwrMgmt) {
                            $props = Get-ItemProperty -Path $AdapterBackupPath -ErrorAction SilentlyContinue
                            if ($null -eq $props -or $null -eq $props.PSObject.Properties["AllowComputerToTurnOffDevice"]) {
                                Set-ItemProperty -Path $AdapterBackupPath -Name "AllowComputerToTurnOffDevice" -Value (if ($PwrMgmt.AllowComputerToTurnOffDevice -match "Enabled|True|1") { 1 } else { 0 }) -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                        }
                    }

                    Enable-NetAdapterChecksumOffload -Name $Adapter.Name -ErrorAction SilentlyContinue | Out-Null
                    Disable-NetAdapterLso -Name $Adapter.Name -IPv4 -IPv6 -ErrorAction SilentlyContinue | Out-Null
                    Disable-NetAdapterRsc -Name $Adapter.Name -IPv4 -IPv6 -ErrorAction SilentlyContinue | Out-Null
                    Set-NetAdapterRss -Name $Adapter.Name -Profile Closest -ErrorAction SilentlyContinue | Out-Null
                    Set-NetAdapterPowerManagement -Name $Adapter.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction SilentlyContinue | Out-Null
                    
                    Write-Host "    -> Aislamiento de latencia inyectado en adaptador: $($Adapter.Name)"
                } catch {
                    throw "No se pudieron aplicar las optimizaciones de red para el adaptador $($Adapter.Name): $_"
                }
            }
        }
    }

    Write-Host "[+] Pila de red optimizada con exito de forma transparente."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Red Saneado: $_"
    exit 1
}
