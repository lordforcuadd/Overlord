param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando Optimización y Limpieza de Disco a Nivel de Sistema de Archivos..."
    
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\Storage"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    # 1. OPTIMIZACIÓN EN CALIENTE NTFS Y EXPANSIÓN DE CACHE DE METADATOS
    Write-Host "[*] Elevando asignación de caché NTFS y resguardando estado base..."
    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    
    if (Test-Path $NtfsPath) {
        $OrigLastAccess = (Get-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
        if ($OrigLastAccess -ne $null -and (Get-ItemProperty -Path $BackupPath -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue) -eq $null) {
            Set-ItemProperty -Path $BackupPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value $OrigLastAccess -Force
        }
    }
    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1 -Force
    
    fsutil behavior set disablelastaccess 1 | Out-Null
    fsutil behavior set disable8dot3 1 | Out-Null
    fsutil behavior set memoryusage 2 | Out-Null # Duplica la pila del pool paginado asignado a NTFS caché

    # 2. ELIMINACIÓN TOTAL DEL ARCHIVO DE HIBERNACIÓN EN ESCRITORIOS (Salva ciclos de escritura SSD)
    if (-not $IsLaptop) {
        Write-Host "    -> Desktop detectada: Eliminando Hiberfil.sys y liberando almacenamiento."
        powercfg.exe /hibernate off
    }

    # 3. CONTROL DE PREFETCH Y SUPERFETCH CACHÉ LOGICAL
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

    Write-Host "[+] Optimización de almacenamiento exitosa. Caché NTFS expandida y espacio recuperado."
    exit 0
} Catch {
    Write-Host "[-] Error crítico en Módulo de Almacenamiento: $_"
    exit 1
}