param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8,
    [bool]$IsSsd = $false
)
$ErrorActionPreference = "Stop"

Try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }
    Write-Host "[*] Iniciando mantenimiento y optimizaciÃ³n de almacenamiento..."

    if ($IsSsd) {
        Write-Host "[+] Unidad SSD detectada. Optimizando parametros de lectura/escritura NTFS y cache..." -ForegroundColor Green
    }

    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

    if (!(Test-Path $NtfsPath)) { New-Item -Path $NtfsPath -Force | Out-Null }
    if (!(Test-Path $FastStartPath)) { New-Item -Path $FastStartPath -Force | Out-Null }

    Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "NtfsDisableLastAccessUpdate" -BackupSubFolder "Storage"
    Backup-OverlordRegistryValue -TargetKey $FastStartPath -ValueName "HiberbootEnabled" -BackupSubFolder "Storage"
    Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "NtfsDisable8dot3NameCreation" -BackupSubFolder "Storage"
    Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "DisableDeleteNotify" -BackupSubFolder "Storage"
    if ($IsSsd -and $RamGB -ge 16) {
        Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "NtfsMemoryUsage" -BackupSubFolder "Storage"
    }

    # Desactivar actualizacion del ultimo acceso en NTFS para reducir escrituras en disco
    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1 -Force | Out-Null
    
    # Desactivar nombres cortos MS-DOS 8.3
    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisable8dot3NameCreation" -Type DWord -Value 1 -Force | Out-Null

    # Optimizar cachÃ© de metadatos NTFS adaptativamente (solo en SSD rÃ¡pidos)
    if ($IsSsd -and $RamGB -ge 16) {
        Set-ItemProperty -Path $NtfsPath -Name "NtfsMemoryUsage" -Type DWord -Value 2 -Force | Out-Null
    }

    if ($IsSsd) {
        # Asegurar soporte TRIM activo en SSD (DisableDeleteNotify = 0 significa TRIM habilitado)
        Set-ItemProperty -Path $NtfsPath -Name "DisableDeleteNotify" -Type DWord -Value 0 -Force | Out-Null
        if ((Get-ItemPropertyValue -Path $NtfsPath -Name "DisableDeleteNotify" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo al verificar DisableDeleteNotify (TRIM)" }
    }
    
    # Desactivar Inicio Rapido de Windows (previene fugas de memoria y bloqueos de drivers)
    Set-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled" -Type DWord -Value 0 -Force | Out-Null
    
    if ((Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue) -ne 1) { throw "Fallo al verificar NtfsDisableLastAccessUpdate" }
    if ((Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsDisable8dot3NameCreation" -ErrorAction SilentlyContinue) -ne 1) { throw "Fallo al verificar NtfsDisable8dot3NameCreation" }
    if ($IsSsd -and $RamGB -ge 16) {
        if ((Get-ItemPropertyValue -Path $NtfsPath -Name "NtfsMemoryUsage" -ErrorAction SilentlyContinue) -ne 2) { throw "Fallo al verificar NtfsMemoryUsage" }
    }
    if ((Get-ItemPropertyValue -Path $FastStartPath -Name "HiberbootEnabled" -ErrorAction SilentlyContinue) -ne 0) { throw "Fallo al verificar HiberbootEnabled (Inicio Rapido)" }

    if (-not $IsLaptop) {
        $HibernateRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
            Backup-OverlordRegistryValue -TargetKey $HibernateRegPath -ValueName "HibernateEnabled" -BackupSubFolder "Storage"
        powercfg.exe /hibernate off | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "powercfg fallo al desactivar la hibernacion (Codigo: $LASTEXITCODE)" }
    }

    # La compactaciÃ³n de componentes DISM se delega a la Limpieza Profunda manual en Quick Actions para prevenir stutters de fondo.

    try {
        # El objeto COM Microsoft.Update.Installer.IsBusy es local, por lo que verificamos procesos activos
        # de instaladores en caliente (TiWorker, TrustedInstaller) que denotan parches activos.
        $IsUpdating = @(Get-Process -Name "TiWorker", "TrustedInstaller" -ErrorAction SilentlyContinue).Count -gt 0
        $WuauservSvc = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        $IsServiceRunning = $null -ne $WuauservSvc -and $WuauservSvc.Status -eq "Running"

        if (-not $IsUpdating) {
            if ($IsServiceRunning) {
                Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            }
            Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            if ($IsServiceRunning) {
                Start-Service wuauserv -ErrorAction SilentlyContinue
            }
        } else {
            # TiWorker o TrustedInstaller estÃ¡n activos. Borrar solo temporales no bloqueados sin apagar el servicio.
            Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        }
    } catch {
        # Evitamos apagar wuauserv por seguridad. Se borran Ãºnicamente los temporales no bloqueados.
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