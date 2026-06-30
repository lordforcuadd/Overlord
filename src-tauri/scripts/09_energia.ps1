param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Configurando inyecciones de energia avanzadas y Core Parking..."

    $PowerBackup = "HKLM:\SOFTWARE\Overlord\Backup\Power"
    if (!(Test-Path $PowerBackup)) { 
        try { New-Item -Path $PowerBackup -Force | Out-Null } catch {} 
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
        } catch {}
    }

    $IsRunningOnLaptop = $IsLaptop

    if ($IsRunningOnLaptop) {
        Write-Host "    -> Laptop detectada: Optimizando control termico y limites de energia..."
        if ($null -ne $CurrentGuid) {
            Backup-OverlordPowerSetting -SchemeGuid $CurrentGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "94d3a615-a899-4ac5-ae2b-e4d8f634367f" -BackupName "Power_${CurrentGuid}_94d3a615-a899-4ac5-ae2b-e4d8f634367f"
            try { & powercfg /SETACVALUEINDEX $CurrentGuid 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 1 2>$null } catch {}
            try { & powercfg /setactive $CurrentGuid 2>$null } catch {}
        }
    } else {
        Write-Host "    -> Computadora de Escritorio detectada: Seleccionando plan de Maximo Rendimiento..."

        $UltimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $AllSchemes = powercfg /list
        
        if ($AllSchemes -match $UltimateGUID) {
            & powercfg /setactive $UltimateGUID 2>$null
        } else {
            $powerProps = Get-ItemProperty -Path $PowerBackup -ErrorAction SilentlyContinue
            $ExistingCustom = if ($null -ne $powerProps -and $null -ne $powerProps.PSObject.Properties["CustomPowerPlan"]) { $powerProps.CustomPowerPlan } else { $null }
            if ($null -ne $ExistingCustom -and ($AllSchemes -match $ExistingCustom)) {
                & powercfg /setactive $ExistingCustom 2>$null
            } else {
                # Intentar duplicar plan de Alto Rendimiento (High Performance)
                $dupOut = powercfg /duplicatescheme "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" 2>$null
                if ($dupOut -notmatch "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") {
                    # Si no existe Alto Rendimiento, duplicamos el plan Equilibrado (Balanced) que siempre viene de fábrica
                    $dupOut = powercfg /duplicatescheme "381b4222-f694-41f0-9685-ff5bb260df2e" 2>$null
                }

                if ($dupOut -match "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") {
                    $newGuid = $Matches[1]
                    & powercfg /changename $newGuid "Overlord Maximo Rendimiento" 2>$null
                    & powercfg /setactive $newGuid 2>$null
                    Set-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -Value $newGuid -Force -ErrorAction SilentlyContinue | Out-Null
                } else {
                    # Último recurso: activar plan Equilibrado de fábrica
                    & powercfg /setactive "381b4222-f694-41f0-9685-ff5bb260df2e" 2>$null
                }
            }
        }

        $CurrentActive = powercfg /getactivescheme
        if ($CurrentActive -notmatch $UltimateGUID -and $CurrentActive -notmatch "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -and $CurrentActive -notmatch "381b4222-f694-41f0-9685-ff5bb260df2e") {
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
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "2a737441-1930-4402-8d77-b2bea128a440" -SettingGuid "d4e00550-747f-4ddb-bf3e-9b6c97a522a4" -BackupName "Power_${DesktopGuid}_d4e00550-747f-4ddb-bf3e-9b6c97a522a4"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "0cc5b647-c1df-4637-891a-dec35c318583" -BackupName "Power_${DesktopGuid}_0cc5b647-c1df-4637-891a-dec35c318583"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "ea0653f5-eab4-474c-8a0f-1ba102244432" -BackupName "Power_${DesktopGuid}_ea0653f5-eab4-474c-8a0f-1ba102244432"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "0012ee47-9041-4b5d-9b77-535fba8b1442" -SettingGuid "6733a230-cd1a-4929-94d4-540b4ddecbeb" -BackupName "Power_${DesktopGuid}_6733a230-cd1a-4929-94d4-540b4ddecbeb"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "3668a66e-6856-4221-b530-747f2d53e4c6" -BackupName "Power_${DesktopGuid}_3668a66e-6856-4221-b530-747f2d53e4c6"
            Backup-OverlordPowerSetting -SchemeGuid $DesktopGuid -SubGroupGuid "54533251-82be-4824-96c1-47b60b740d00" -SettingGuid "be337238-0d82-4146-a960-4f3749d470c7" -BackupName "Power_${DesktopGuid}_be337238-0d82-4146-a960-4f3749d470c7"
        }

        # Nota de rigor: Las llamadas powercfg externas no generan excepciones en PowerShell
        # al fallar (por ejemplo, si el hardware/firmware no soporta EPP o Boost Mode).
        # Verificamos explícitamente $LASTEXITCODE para reportar advertencias informadas sin interrumpir la ejecución.
        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg /setacvalueindex falló para ee12f906-d277-404b-b6da-e5fa1a576df5: código $LASTEXITCODE" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea128a440 d4e00550-747f-4ddb-bf3e-9b6c97a522a4 0 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg /setacvalueindex falló para d4e00550-747f-4ddb-bf3e-9b6c97a522a4: código $LASTEXITCODE" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg /setacvalueindex falló para 0cc5b647-c1df-4637-891a-dec35c318583: código $LASTEXITCODE" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 ea0653f5-eab4-474c-8a0f-1ba102244432 100 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg /setacvalueindex falló para ea0653f5-eab4-474c-8a0f-1ba102244432: código $LASTEXITCODE" }
        
        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 6733a230-cd1a-4929-94d4-540b4ddecbeb 0 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg /setacvalueindex falló para 6733a230-cd1a-4929-94d4-540b4ddecbeb: código $LASTEXITCODE" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 3668a66e-6856-4221-b530-747f2d53e4c6 0 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg /setacvalueindex falló para 3668a66e-6856-4221-b530-747f2d53e4c6: código $LASTEXITCODE" }

        & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 2 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "powercfg /setacvalueindex falló para be337238-0d82-4146-a960-4f3749d470c7: código $LASTEXITCODE" }

        # Inyectar desactivación global de Power Throttling
        $ThrottlePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
        if (!(Test-Path $ThrottlePath)) { New-Item -Path $ThrottlePath -Force | Out-Null }
        Backup-OverlordRegistryValue -TargetKey $ThrottlePath -ValueName "PowerThrottlingOff" -BackupSubFolder "Power"
        Set-ItemProperty -Path $ThrottlePath -Name "PowerThrottlingOff" -Type DWord -Value 1 -Force | Out-Null

        $ActivePlan = powercfg /getactivescheme 2>$null
        if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
            $CurrentGuid = $Matches[1]
            try { & powercfg /setactive $CurrentGuid 2>$null } catch {}
        }
    }

    Write-Host "[+] Esquemas de energia acoplados al Kernel con exito."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Energia: $_"
    exit 1
}