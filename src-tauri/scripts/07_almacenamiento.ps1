param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando Optimizacion y Limpieza de Disco..."

    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $FastStartPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

    if (!(Test-Path $NtfsPath)) { New-Item -Path $NtfsPath -Force | Out-Null }
    if (!(Test-Path $PrefetchPath)) { New-Item -Path $PrefetchPath -Force | Out-Null }
    if (!(Test-Path $FastStartPath)) { New-Item -Path $FastStartPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "NtfsDisableLastAccessUpdate" -BackupSubFolder "Storage"
        Backup-OverlordRegistryValue -TargetKey $NtfsPath -ValueName "NtfsMemoryUsage" -BackupSubFolder "Storage"
        Backup-OverlordRegistryValue -TargetKey $PrefetchPath -ValueName "EnablePrefetcher" -BackupSubFolder "Storage"
        Backup-OverlordRegistryValue -TargetKey $PrefetchPath -ValueName "EnableSuperfetch" -BackupSubFolder "Storage"
        Backup-OverlordRegistryValue -TargetKey $FastStartPath -ValueName "HiberbootEnabled" -BackupSubFolder "Storage"
    }

    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1 -Force | Out-Null
    Set-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled" -Type DWord -Value 0 -Force | Out-Null
    
    if ((Get-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate").NtfsDisableLastAccessUpdate -ne 1) { throw "Fallo al verificar NtfsDisableLastAccessUpdate" }
    if ((Get-ItemProperty -Path $FastStartPath -Name "HiberbootEnabled").HiberbootEnabled -ne 0) { throw "Fallo al verificar HiberbootEnabled (Inicio Rapido)" }

    fsutil behavior set disablelastaccess 1 | Out-Null
    fsutil behavior set disable8dot3 1 | Out-Null

    $targetMemoryUsage = 0
    if ($RamGB -gt 8) {
        $targetMemoryUsage = 2
    }
    Set-ItemProperty -Path $NtfsPath -Name "NtfsMemoryUsage" -Type DWord -Value $targetMemoryUsage -Force | Out-Null
    fsutil behavior set memoryusage $targetMemoryUsage | Out-Null
    if ((Get-ItemProperty -Path $NtfsPath -Name "NtfsMemoryUsage").NtfsMemoryUsage -ne $targetMemoryUsage) { throw "Fallo al verificar NtfsMemoryUsage" }

    if (-not $IsLaptop) {
        $HibernateRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
        if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
            Backup-OverlordRegistryValue -TargetKey $HibernateRegPath -ValueName "HibernateEnabled" -BackupSubFolder "Storage"
        }
        powercfg.exe /hibernate off | Out-Null
    }


    $targetPrefetch = 3
    
    Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value $targetPrefetch -Force | Out-Null
    Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value $targetPrefetch -Force | Out-Null
    if ((Get-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher").EnablePrefetcher -ne $targetPrefetch) { throw "Fallo al verificar EnablePrefetcher" }
    if ((Get-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch").EnableSuperfetch -ne $targetPrefetch) { throw "Fallo al verificar EnableSuperfetch" }

    $DismProcess = Start-Process -FilePath "dism.exe" -ArgumentList "/online /Cleanup-Image /StartComponentCleanup" -PassThru -NoNewWindow
    # Esperamos hasta 20 minutos sin lanzar excepciones si se agota el tiempo
    $Timeout = 1200
    $Interval = 5
    $Waited = 0
    while (-not $DismProcess.HasExited -and $Waited -lt $Timeout) {
        Start-Sleep -Seconds $Interval
        $Waited += $Interval
    }

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
        Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Almacenamiento: $_"
    exit 1
}