param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando Optimización y Limpieza de Disco a Nivel de Sistema de Archivos..."

    # 1. OPTIMIZACIÓN EN CALIENTE NTFS Y EXPANSIÓN DE CACHE DE METADATOS
    Write-Host "[*] Elevando asignación de caché NTFS y bloqueando marcas de marcas de tiempo..."
    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
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
    Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 0 -Force

    # 4. ADMINISTRACIÓN DE SYSTEM CACHE HEAP PROCESS
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Type DWord -Value 0 -Force

    # 5. PURGA DE ALTA EFICIENCIA A NIVEL KERNEL (WinScript Space Recovery Core)
    Write-Host "[*] Ejecutando Limpieza Avanzada (Space Recovery)..."

    # A. Reducción de almacén de componentes WinSxS obsoletos
    dism.exe /online /Cleanup-Image /StartComponentCleanup

    # B. Purgado controlado del directorio de descargas temporales de Windows Update
    try {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue
    } catch {}

    # C. Limpieza profunda del almacén de Delivery Optimization
    try {
        Remove-Item -Path "$env:windir\ServiceProfiles\LocalService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    # D. Eliminación radical de volcados de memoria por errores e hilos colgados
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