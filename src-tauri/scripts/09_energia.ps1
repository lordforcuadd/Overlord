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

    $ActivePlan = powercfg /getactivescheme 2>$null
    if ($ActivePlan -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
        $CurrentGuid = $Matches[1]
        try {
            if ((Get-ItemProperty -Path $PowerBackup -Name "ActivePowerPlan" -ErrorAction SilentlyContinue) -eq $null) {
                Set-ItemProperty -Path $PowerBackup -Name "ActivePowerPlan" -Value $CurrentGuid -Force -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {}
    }

    $RawLaptop = "$IsLaptop"
    $IsRunningOnLaptop = $false
    if ($RawLaptop -eq "true" -or $RawLaptop -eq "$true" -or $IsLaptop -eq $true) {
        $IsRunningOnLaptop = $true
    }

    if ($IsRunningOnLaptop) {
        Write-Host "    -> Laptop detectada: Optimizando control termico y limites de energia..."
        try { & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 94D3A615-A899-4AC5-AE2B-E4D8F634367F 1 2>$null } catch {}
        try { & powercfg /SETDCVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 94D3A615-A899-4AC5-AE2B-E4D8F634367F 1 2>$null } catch {}
    } else {
        Write-Host "    -> Computadora de Escritorio detectada: Deshabilitando Core Parking y ahorros PCIe..."
        
        try { & powercfg /SETACVALUEINDEX SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 2>$null } catch {}
        try { & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bea128a440 d4e00550-747f-4ddb-bf3e-9b6c97a522a4 0 2>$null } catch {}

        try { & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100 2>$null } catch {}
        try { & powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 ea0653f5-eab4-474c-8a0f-1ba102244432 100 2>$null } catch {}

        $UltimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $AllSchemes = powercfg /list
        
        if ($AllSchemes -match $UltimateGUID) {
            & powercfg /setactive $UltimateGUID 2>$null
        } else {
            $ExistingCustom = (Get-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -ErrorAction SilentlyContinue).CustomPowerPlan
            if ($null -ne $ExistingCustom -and ($AllSchemes -match $ExistingCustom)) {
                & powercfg /setactive $ExistingCustom 2>$null
            } else {
                $dupOut = powercfg /duplicatescheme "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" 2>$null
                if ($dupOut -match "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") {
                    $newGuid = $Matches[1]
                    & powercfg /changename $newGuid "Overlord Maximo Rendimiento" 2>$null
                    & powercfg /setactive $newGuid 2>$null
                    Set-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -Value $newGuid -Force -ErrorAction SilentlyContinue | Out-Null
                } else {
                    & powercfg /setactive "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" 2>$null
                }
            }
        }

        $CurrentActive = powercfg /getactivescheme
        if ($CurrentActive -notmatch $UltimateGUID -and $CurrentActive -notmatch "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c") {
            $CustomGuidCheck = (Get-ItemProperty -Path $PowerBackup -Name "CustomPowerPlan" -ErrorAction SilentlyContinue).CustomPowerPlan
            if ($null -eq $CustomGuidCheck -or $CurrentActive -notmatch $CustomGuidCheck) {
                throw "Fallo al verificar la activacion del esquema de energia de maximo rendimiento"
            }
        }
    }

    Write-Host "[+] Esquemas de energia acoplados al Kernel con exito."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Energia: $_"
    exit 1
}