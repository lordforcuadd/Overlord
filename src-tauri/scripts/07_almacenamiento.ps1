param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando Optimizacion y Limpieza de Disco..."
    
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Storage"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    if (Test-Path $NtfsPath) {
        $OrigLastAccess = (Get-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
        $OrigMemoryUsage = (Get-ItemProperty -Path $NtfsPath -Name "NtfsMemoryUsage" -ErrorAction SilentlyContinue).NtfsMemoryUsage
        
        if ($OrigLastAccess -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue) -eq $null) {
            Set-ItemProperty -Path $BackupPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value $OrigLastAccess -Force
        }
        if ($OrigMemoryUsage -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "NtfsMemoryUsage" -ErrorAction SilentlyContinue) -eq $null) {
            Set-ItemProperty -Path $BackupPath -Name "NtfsMemoryUsage" -Type DWord -Value $OrigMemoryUsage -Force
        }
    }
    
    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1 -Force
    fsutil behavior set disablelastaccess 1 | Out-Null
    fsutil behavior set disable8dot3 1 | Out-Null
    
    if ($RamGB -gt 8) {
        fsutil behavior set memoryusage 2 | Out-Null
    } else {
        fsutil behavior set memoryusage 0 | Out-Null
    }

    if (-not $IsLaptop) {
        powercfg.exe /hibernate off
    }

    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    if (!(Test-Path $PrefetchPath)) { New-Item -Path $PrefetchPath -Force | Out-Null }

    $isDisk = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "HDD" }
    if ($isDisk) {
        Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 3 -Force
        Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 3 -Force
    } else {
        Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 0 -Force
        Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 0 -Force
    }

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Type DWord -Value 0 -Force

    dism.exe /online /Cleanup-Image /StartComponentCleanup

    try {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue
    } catch {}

    try {
        Remove-Item -Path "$env:windir\ServiceProfiles\LocalService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    try {
        Remove-Item -Path "$env:windir\Minidump\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        if (Test-Path "$env:windir\MEMORY.DMP") { Remove-Item -Path "$env:windir\MEMORY.DMP" -Force -Confirm:$false -ErrorAction SilentlyContinue }
    } catch {}

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Almacenamiento: $_"
    exit 1
}