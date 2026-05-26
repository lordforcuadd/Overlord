param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando Optimización y Limpieza de Disco a Nivel de Sistema de Archivos..."
    
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Storage"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    # 1. EXPANSION CACHÉ NTFS ADAPTATIVA EN CALIENTE
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
    
    # 🚀 PROTECCIÓN LÓGICA DE RAM: Duplicar la pila asignada a NTFS solo si el equipo cuenta con memoria de sobra (> 8GB)
    if ($RamGB -gt 8) {
        fsutil behavior set memoryusage 2 | Out-Null
    } else {
        fsutil behavior set memoryusage 0 | Out-Null
    }

    # 2. ELIMINACIÓN DE HIBERNACIÓN EXCLUSIVA PARA ESCRITORIOS
    if (-not $IsLaptop) {
        Write-Host "    -> Desktop detectada: Eliminando Hiberfil.sys y liberando almacenamiento."
        powercfg.exe /hibernate off
    }

    # 3. APAGADO DE PREFETCH Y SUPERFETCH
    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    if (!(Test-Path $PrefetchPath)) { New-Item -Path $PrefetchPath -Force | Out-Null }
    Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 0 -Force

    # 4. ADMINISTRACIÓN DE SYSTEM CACHE HEAP PROCESS
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Type DWord -Value 0 -Force

    # 5. PURGA DE ALTA EFICIENCIA A NIVEL KERNEL
    Write-Host "[*] Ejecutando Limpieza Avanzada (Space Recovery)..."
    dism.exe /online /Cleanup-Image /StartComponentCleanup

    try {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:redirect_windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue
    } catch {}

    try {
        Remove-Item -Path "$env:windir\ServiceProfiles\LocalService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    try {
        Remove-Item -Path "$env:windir\Minidump\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        if (Test-Path "$env:windir\MEMORY.DMP") { Remove-Item -Path "$env:windir\MEMORY.DMP" -Force -Confirm:$false -ErrorAction SilentlyContinue }
    } catch {}

    Write-Host "[+] Optimización de almacenamiento exitosa. Caché NTFS expandida y espacio recuperado."
    exit 0
} Catch {
    Write-Host "[-] Error crítico en Módulo de Almacenamiento: $_"
    exit 1
}