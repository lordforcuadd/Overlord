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
        Backup-OverlordRegistryValue -TargetKey $MemPath -ValueName "LargeSystemCache" -BackupSubFolder "Storage"
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

    $BootDrive = Get-Disk | Where-Object { $_.IsBoot -eq $true }
    $isHDD = $false
    if ($BootDrive) {
        $PhysicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq $BootDrive.Number }
        if ($PhysicalDisk -and $PhysicalDisk.MediaType -eq "HDD") {
            $isHDD = $true
        }
    }

    $targetPrefetch = 0
    if ($isHDD) {
        $targetPrefetch = 3
    }
    
    Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value $targetPrefetch -Force | Out-Null
    Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value $targetPrefetch -Force | Out-Null
    if ((Get-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher").EnablePrefetcher -ne $targetPrefetch) { throw "Fallo al verificar EnablePrefetcher" }
    if ((Get-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch").EnableSuperfetch -ne $targetPrefetch) { throw "Fallo al verificar EnableSuperfetch" }

    Set-ItemProperty -Path $MemPath -Name "LargeSystemCache" -Type DWord -Value 0 -Force | Out-Null
    if ((Get-ItemProperty -Path $MemPath -Name "LargeSystemCache").LargeSystemCache -ne 0) { throw "Fallo al verificar LargeSystemCache" }

    $DismProcess = Start-Process -FilePath "dism.exe" -ArgumentList "/online /Cleanup-Image /StartComponentCleanup" -PassThru -NoNewWindow
    $DismProcess | Wait-Process -Timeout 1200 -ErrorAction SilentlyContinue
    if (!$DismProcess.HasExited) { $DismProcess | Stop-Process -Force }

    try {
        $UpdateSession = New-Object -ComObject "Microsoft.Update.Session"
        $UpdateInstaller = New-Object -ComObject "Microsoft.Update.Installer"
        if (-not $UpdateInstaller.IsBusy) {
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            Start-Service wuauserv -ErrorAction SilentlyContinue
        }
    } catch {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue
    }

    try {
        Remove-Item -Path "$env:windir\ServiceProfiles\LocalService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    try {
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Almacenamiento: $_"
    exit 1
}