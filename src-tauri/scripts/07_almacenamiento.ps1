param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando Optimizacion y Limpieza de Disco..."

    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

    if (!(Test-Path $NtfsPath)) { New-Item -Path $NtfsPath -Force | Out-Null }
    if (!(Test-Path $FastStartPath)) { New-Item -Path $FastStartPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "NtfsDisableLastAccessUpdate" -BackupSubFolder "Storage"
        Backup-OverlordRegistryValue -TargetKey $FastStartPath -ValueName "HiberbootEnabled" -BackupSubFolder "Storage"
        Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "NtfsDisable8dot3NameCreation" -BackupSubFolder "Storage"
        if ($RamGB -ge 16) {
            Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "NtfsMemoryUsage" -BackupSubFolder "Storage"
        }
    }

    # Desactivar actualizacion del ultimo acceso en NTFS para reducir escrituras en disco
    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1 -Force | Out-Null
    
    # Desactivar nombres cortos MS-DOS 8.3
    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisable8dot3NameCreation" -Type DWord -Value 1 -Force | Out-Null

    # Optimizar caché de metadatos NTFS adaptativamente
    if ($RamGB -ge 16) {
        Set-ItemProperty -Path $NtfsPath -Name "NtfsMemoryUsage" -Type DWord -Value 2 -Force | Out-Null
    }
    
    # Desactivar Inicio Rapido de Windows (previene fugas de memoria y bloqueos de drivers)
    Set-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled" -Type DWord -Value 0 -Force | Out-Null
    
    if ((Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue) -ne 1) { throw "Fallo al verificar NtfsDisableLastAccessUpdate" }
    if ((Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsDisable8dot3NameCreation" -ErrorAction SilentlyContinue) -ne 1) { throw "Fallo al verificar NtfsDisable8dot3NameCreation" }
    if ($RamGB -ge 16) {
        if ((Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsMemoryUsage" -ErrorAction SilentlyContinue) -ne 2) { throw "Fallo al verificar NtfsMemoryUsage" }
    }
    if ((Get-ItemPropertyValue -Path $FastStartPath -Name "HiberbootEnabled" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo al verificar HiberbootEnabled (Inicio Rapido)" }

    if (-not $IsLaptop) {
        $HibernateRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $HibernateRegPath -ValueName "HibernateEnabled" -BackupSubFolder "Storage"
        }
        powercfg.exe /hibernate off | Out-Null
    }

    # Lanzar la compactacion de componentes de forma asincrona en segundo plano para no bloquear al optimizador
    Start-Process -FilePath "dism.exe" -ArgumentList "/online /Cleanup-Image /StartComponentCleanup" -NoNewWindow -ErrorAction SilentlyContinue | Out-Null

    try {
        $UpdateSession = New-Object -ComObject "Microsoft.Update.Session"
        $UpdateInstaller = New-Object -ComObject "Microsoft.Update.Installer"
        if (-not $UpdateInstaller.IsBusy) {
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            Start-Service wuauserv -ErrorAction SilentlyContinue
        }
    } catch {
        # Si falla el objeto COM, evitamos apagar wuauserv por seguridad para no interrumpir parches en caliente.
        # Se borran únicamente los temporales no bloqueados por el sistema.
        Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    }

    try {
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Almacenamiento: $_"
    exit 1
}