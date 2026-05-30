param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

$BackupManagerPath = Join-Path $PSScriptRoot "backup_manager.psm1"
if (Test-Path $BackupManagerPath) {
    Import-Module $BackupManagerPath -Force
}

Try {
    Write-Host "[*] Configurando inyecciones de energia avanzadas y Core Parking..."

    $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
    $PowerGuid = if ($ActivePlan) { $ActivePlan.InstanceID.Split('\')[1] } else { "381b4222-f694-41f0-9685-ff5bb260df2e" }

    $PowerBackup = "HKLM:\SOFTWARE\Overlord\Backup\Power"
    if (!(Test-Path $PowerBackup)) { New-Item -Path $PowerBackup -Force | Out-Null }
    if ((Get-ItemProperty -Path $PowerBackup -Name "ActivePowerPlan" -ErrorAction SilentlyContinue) -eq $null) {
        Set-ItemProperty -Path $PowerBackup -Name "ActivePowerPlan" -Value $PowerGuid -Force | Out-Null
    }

    if ($IsLaptop) {
        Write-Host "    -> Laptop detectada: Optimizando control termico y limites de energia..."
        powercfg /SETACVALUEINDEX $PowerGuid 54533251-82be-4824-96c1-47b60b740d00 94D3A615-A899-4AC5-AE2B-E4D8F634367F 1 | Out-Null
        powercfg /SETDCVALUEINDEX $PowerGuid 54533251-82be-4824-96c1-47b60b740d00 94D3A615-A899-4AC5-AE2B-E4D8F634367F 1 | Out-Null
    } else {
        Write-Host "    -> Computadora de Escritorio detectada: Deshabilitando Core Parking y ahorros PCIe..."
        
        powercfg /SETACVALUEINDEX $PowerGuid 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a558deb 0 | Out-Null

        $PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
        if (Test-Path $PowerPath) {
            if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
                Backup-OverlordRegistryValue -TargetKey $PowerPath -ValueName "ValueMax" -BackupSubFolder "Power"
                Backup-OverlordRegistryValue -TargetKey $PowerPath -ValueName "ValueMin" -BackupSubFolder "Power"
            }

            Set-ItemProperty -Path $PowerPath -Name "ValueMax" -Type DWord -Value 0 -Force | Out-Null
            Set-ItemProperty -Path $PowerPath -Name "ValueMin" -Type DWord -Value 0 -Force | Out-Null
        }
        
        powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
        if ($LASTEXITCODE -ne 0) {
            powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
            powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
        }
    }

    Write-Host "[+] Esquemas de energia acoplados al Kernel con exito."
    exit 0

} Catch {
    Write-Error "[-] Error critico en Modulo de Energia: $_"
    exit 1
}