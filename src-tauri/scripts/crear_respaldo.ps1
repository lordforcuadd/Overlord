param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    $AdminCheck = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $AdminCheck) {
        Write-Error "[-] Error: Se requieren privilegios de Administrador elevados."
        exit 1
    }

    Write-Host "[*] Iniciando protocolo de seguridad: Punto de Restauracion..."
    $Description = "Overlord v4.5.0 - Punto Seguro"

    Set-Service -Name VSS -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name VSS -ErrorAction SilentlyContinue
    Set-Service -Name vmicvss -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name vmicvss -ErrorAction SilentlyContinue

    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    Enable-ComputerRestore -Drive "$SysDrive\" -ErrorAction SilentlyContinue | Out-Null

    $SysRestorePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    if (!(Test-Path $SysRestorePath)) { New-Item -Path $SysRestorePath -Force | Out-Null }
    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $SysRestorePath -ValueName "SystemRestorePointCreationFrequency" -BackupSubFolder "Storage"
    }
    Set-ItemProperty -Path $SysRestorePath -Name "SystemRestorePointCreationFrequency" -Type DWord -Value 0 -Force | Out-Null

    Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"

    Write-Host "[+] Punto de restauración creado con exito. El sistema se encuentra asegurado."
    exit 0
} Catch {
    Write-Error "[-] Fallo critico al intentar orquestar el Punto de Restauracion VSS: $_"
    exit 1
}