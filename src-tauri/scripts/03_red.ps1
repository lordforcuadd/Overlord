$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando optimizacion cientifica de la pila de red TCP/IP..."

    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

    if (!(Test-Path $TcpPath)) { New-Item -Path $TcpPath -Force | Out-Null }
    if (!(Test-Path $ProfilePath)) { New-Item -Path $ProfilePath -Force | Out-Null }
    
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $ProfilePath -ValueName "NetworkThrottlingIndex" -BackupSubFolder "Network"
        Backup-OverlordRegistryValue -TargetKey $ProfilePath -ValueName "SystemResponsiveness" -BackupSubFolder "Network"
        Backup-OverlordRegistryValue -TargetKey $TcpPath -ValueName "InitialRto" -BackupSubFolder "Network"
    }

    Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295 -Force | Out-Null
    Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Type DWord -Value 10 -Force | Out-Null
    Set-ItemProperty -Path $TcpPath -Name "InitialRto" -Type DWord -Value 2000 -Force | Out-Null
 
    if ((Get-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness").SystemResponsiveness -ne 10) { throw "Verification failed" }
    if ((Get-ItemProperty -Path $TcpPath -Name "InitialRto").InitialRto -ne 2000) { throw "Verification failed" }
    
    $throttingVal = (Get-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex").NetworkThrottlingIndex
    if ($throttingVal -ne 4294967295 -and $throttingVal -ne -1) { throw "Verification failed" }

    
    $InterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $InterfacesPath) {
        $InterfaceKeys = Get-ChildItem -Path $InterfacesPath -ErrorAction SilentlyContinue
        foreach ($Key in $InterfaceKeys) {
            if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                Backup-OverlordRegistryValue -TargetKey $Key.PSPath -ValueName "TcpAckFrequency" -BackupSubFolder "Network"
                Backup-OverlordRegistryValue -TargetKey $Key.PSPath -ValueName "TcpNoDelay" -BackupSubFolder "Network"
            }
            Set-ItemProperty -Path $Key.PSPath -Name "TcpAckFrequency" -Type DWord -Value 1 -Force | Out-Null
            Set-ItemProperty -Path $Key.PSPath -Name "TcpNoDelay" -Type DWord -Value 1 -Force | Out-Null
        }
    }

    $NetClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $NetClassPath) {
        $EthernetGuids = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
            $_.Virtual -eq $false -and 
            $_.NdisPhysicalMedium -eq 14 
        } | ForEach-Object { "$($_.InterfaceGuid)" }

        $NetAdapters = Get-ChildItem -Path $NetClassPath -ErrorAction SilentlyContinue
        foreach ($Adapter in $NetAdapters) {
            if ($Adapter.PSChildName -match "^\d{4}$") {
                $NetInstanceId = (Get-ItemProperty -Path $Adapter.PSPath -Name "NetCfgInstanceId" -ErrorAction SilentlyContinue).NetCfgInstanceId
                if ($null -ne $NetInstanceId -and ($EthernetGuids -contains $NetInstanceId)) {
                    $PowerKeys = @("*EEE", "EEE", "*GreenEnergy", "GreenEnergy", "*EEELinkAdvertisement", "EEELinkAdvertisement", "*EnergyEfficientEthernet", "EnergyEfficientEthernet")
                    
                    # Desactivar Coalescencia, Moderación de Interrupción y Control de Flujo únicamente en PCs de Escritorio con >8 hilos lógicos
                    $TotalThreads = [int]$env:NUMBER_OF_PROCESSORS
                    if ($TotalThreads -gt 8 -and -not $IsLaptop) {
                        $PowerKeys += "*PacketCoalescing", "PacketCoalescing", "*InterruptModeration", "InterruptModeration", "*FlowControl", "FlowControl"
                    }

                    foreach ($PKey in $PowerKeys) {
                        $Prop = Get-ItemProperty -Path $Adapter.PSPath -Name $PKey -ErrorAction SilentlyContinue
                        if ($null -ne $Prop) {
                            if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                                Backup-OverlordRegistryValue -TargetKey $Adapter.PSPath -ValueName $PKey -BackupSubFolder "Network"
                            }
                            Set-ItemProperty -Path $Adapter.PSPath -Name $PKey -Type String -Value "0" -Force | Out-Null
                        }
                    }
                }
            }
        }
    }

    $Adapters = Get-NetAdapter -ErrorAction SilentlyContinue
    foreach ($Adapter in $Adapters) {
        if ($Adapter.Status -eq "Up" -or $Adapter.HardwareInterface -eq $true) {
            Enable-NetAdapterChecksumOffload -Name $Adapter.Name -ErrorAction SilentlyContinue | Out-Null
            Disable-NetAdapterLso -Name $Adapter.Name -IPv4 -IPv6 -ErrorAction SilentlyContinue | Out-Null
            Disable-NetAdapterRsc -Name $Adapter.Name -IPv4 -IPv6 -ErrorAction SilentlyContinue | Out-Null
            Set-NetAdapterRss -Name $Adapter.Name -Profile Closest -ErrorAction SilentlyContinue | Out-Null
            Write-Host "    -> Aislamiento de latencia inyectado en adaptador: $($Adapter.Name)"
        }
    }

    Write-Host "[+] Pila de red optimizada con exito de forma transparente."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Red Saneado: $_"
    exit 1
}