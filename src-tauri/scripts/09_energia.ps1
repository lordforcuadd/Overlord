param(
    [bool]$IsLaptop = $false
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Configurando inyecciones de energia avanzadas y Core Parking..."

    $PowerBackup = "HKLM:\SOFTWARE\Overlord\Backup\Power"
    if (!(Test-Path $PowerBackup)) { 
        try { New-Item -Path $PowerBackup -Force | Out-Null } catch { Write-Verbose "Fallo al crear PowerBackup: $_" } 
    }



    $CurrentGuid = $null
    $ActivePlan = powercfg /getactivescheme 2>$null
    if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
        $CurrentGuid = $Matches[1]
        try {
            $powerProps = Get-ItemProperty -Path $PowerBackup -ErrorAction SilentlyContinue
            if ($null -eq $powerProps -or $null -eq $powerProps.PSObject.Properties["ActivePowerPlan"]) {
                Set-ItemProperty -Path $PowerBackup -Name "ActivePowerPlan" -Value $CurrentGuid -Force -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {
            Write-Verbose "Fallo al guardar ActivePowerPlan en backup: $_"
        }
    }

    $IsRunningOnLaptop = $IsLaptop
    if (-not $IsRunningOnLaptop) {
        $Win32Bat = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if ($null -ne $Win32Bat -and $Win32Bat.Count -gt 0) {
            $IsRunningOnLaptop = $true
        }
    }

    if ($IsRunningOnLaptop) {
        Write-Host "    -> Laptop detectada: Optimizando control termico y limites de energia..."
        if ($null -ne $CurrentGuid) {
            Backup-OverlordPowerSetting -SchemeGuid $CurrentGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "94d3a615-a899-4ac5-ae2b-e4d8f634367f" -BackupName "Power_${CurrentGuid}_94d3a615-a899-4ac5-ae2b-e4d8f634367f"
            & powercfg /SETACVALUEINDEX $CurrentGuid 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 1 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { Write-Verbose "Fallo al ajustar indice AC en laptop" }
            & powercfg /setactive $CurrentGuid 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { Write-Verbose "Fallo al activar plan en laptop" }
        }
    } else {
        Write-Host "    -> Computadora de Escritorio detectada: Seleccionando plan de Maximo Rendimiento..."

        $UltimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $AllSchemes = powercfg /list
        
        $UltimateActivated = $false
        if ($AllSchemes -match $UltimateGUID) {
            & powercfg /setactive $UltimateGUID 2>$null
            $currentSchemeNow = powercfg /getactivescheme 2>$null
            if ($currentSchemeNow -match $UltimateGUID) {
                $UltimateActivated = $true
            }
        }
        
        if (-not $UltimateActivated) {
            $powerProps = Get-ItemProperty -Path $PowerBackup -ErrorAction SilentlyContinue
            $ExistingCustom = if ($null -ne $powerProps -and $null -ne $powerProps.PSObject.Properties["CustomPowerPlan"]) { $powerProps.CustomPowerPlan } else { $null }
            if ([string]::IsNullOrWhiteSpace($ExistingCustom)) {
                $OverlordMatch = $AllSchemes | Where-Object { $_ -match "Overlord Maximo Rendimiento" }
                if ($OverlordMatch -and $OverlordMatch -match "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") {
                    $ExistingCustom = $Matches[1]
                    Set-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -Value $ExistingCustom -Force | Out-Null
                }
            }
            if ($null -ne $ExistingCustom -and ($AllSchemes -match $ExistingCustom)) {
                & powercfg /setactive $ExistingCustom 2>$null
            } else {
                # Intentar duplicar plan de Alto Rendimiento (High Performance)
                $dupOut = powercfg /duplicatescheme "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" 2>$null
                if ($dupOut -notmatch "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") {
                    # Si no existe Alto Rendimiento, duplicamos el plan Equilibrado (Balanced) que siempre viene de fabrica
                    $dupOut = powercfg /duplicatescheme "381b4222-f694-41f0-9685-ff5bb260df2e" 2>$null
                }

                if ($dupOut -match "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") {
                    $newGuid = $Matches[1]
                    & powercfg /changename $newGuid "Overlord Maximo Rendimiento" 2>$null | Out-Null
                    & powercfg /setactive $newGuid 2>$null | Out-Null
                    Set-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -Value $newGuid -Force | Out-Null
                } else {
                    Write-Warning "No se pudo duplicar un esquema de energia base para Overlord; se mantendra el plan actual del sistema."
                }
            }
        }

        $CurrentActive = powercfg /getactivescheme
        if ($CurrentActive -notmatch $UltimateGUID -and $CurrentActive -notmatch "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c") {
            $powerProps = Get-ItemProperty -Path $PowerBackup -ErrorAction SilentlyContinue
            $CustomGuidCheck = if ($null -ne $powerProps -and $null -ne $powerProps.PSObject.Properties["CustomPowerPlan"]) { $powerProps.CustomPowerPlan } else { $null }
            if ($null -eq $CustomGuidCheck -or $CurrentActive -notmatch $CustomGuidCheck) {
                throw "Fallo al verificar la activacion del esquema de energia de maximo rendimiento"
            }
        }

        Write-Host "    -> Aplicando deshabilitacion de Core Parking y ahorros PCIe sobre el plan activo..."
        
        $ActivePlan = powercfg /getactivescheme 2>$null
        if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
            $DesktopGuid = $Matches[1]
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "501a4d13-42af-4429-9fd1-a8218c268e20" -SettingGuid "ee12f906-d277-404b-b6da-e5fa1a576df5" -BackupName "Power_${DesktopGuid}_ee12f906-d277-404b-b6da-e5fa1a576df5"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "2a737441-1930-4402-8d77-b2bebba308a3" -SettingGuid "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" -BackupName "Power_${DesktopGuid}_48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "0cc5b647-c1df-4637-891a-dec35c318583" -BackupName "Power_${DesktopGuid}_0cc5b647-c1df-4637-891a-dec35c318583"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "ea062031-0e34-4ff1-9b6d-eb1059334028" -BackupName "Power_${DesktopGuid}_ea062031-0e34-4ff1-9b6d-eb1059334028"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "0012ee47-9041-4b5d-9b77-535fba8b1442" -SettingGuid "6738e2c4-e8a5-4a42-b16a-e040e769756e" -BackupName "Power_${DesktopGuid}_6738e2c4-e8a5-4a42-b16a-e040e769756e"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "36687f9e-e3a5-4dbf-b1dc-15eb381c6863" -BackupName "Power_${DesktopGuid}_36687f9e-e3a5-4dbf-b1dc-15eb381c6863"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "be337238-0d82-4146-a960-4f3749d470c7" -BackupName "Power_${DesktopGuid}_be337238-0d82-4146-a960-4f3749d470c7"
        }

        # Nota de rigor: Las llamadas powercfg externas no generan excepciones en PowerShell
        # al fallar (por ejemplo, si el hardware/firmware no soporta EPP o Boost Mode).
        # Verificamos explicitamente $LASTEXITCODE para reportar advertencias informadas sin interrumpir la ejecucion.
        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg fallo para ee12f906-d277-404b-b6da-e5fa1a576df5" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg fallo para 48e6b7a6-50f5-4782-a5d4-53bb8f07e226" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg fallo para 0cc5b647-c1df-4637-891a-dec35c318583" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 100 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg fallo para ea062031-0e34-4ff1-9b6d-eb1059334028" }
        
        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg fallo para 6738e2c4-e8a5-4a42-b16a-e040e769756e" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 0 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg fallo para 36687f9e-e3a5-4dbf-b1dc-15eb381c6863" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 2 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg fallo para be337238-0d82-4146-a960-4f3749d470c7" }

        $ActivePlan = powercfg /getactivescheme 2>$null
        if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
            $CurrentGuid = $Matches[1]
            & powercfg /setactive $CurrentGuid 2>$null
            if ($LASTEXITCODE -ne 0) { Write-Warning "Fallo al reactivar plan de energia: $CurrentGuid" }
        }
    }

    # Inyectar desactivacion de Power Throttling solo en computadoras de escritorio.
    # En laptops se preserva EcoQoS para evitar sobrecalentamiento y drenaje acelerado de bateria.
    if (-not $IsRunningOnLaptop) {
        $ThrottlePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
        if (!(Test-Path $ThrottlePath)) { New-Item -Path $ThrottlePath -Force | Out-Null }
        Backup-OverlordRegistryValue -TargetKey $ThrottlePath -ValueName "PowerThrottlingOff" -BackupSubFolder "Power"
        Set-ItemProperty -Path $ThrottlePath -Name "PowerThrottlingOff" -Type DWord -Value 1 -Force | Out-Null
    }

    Write-Host "[+] Esquemas de energia acoplados al Kernel con exito."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Energia: $_"
    exit 1
}
