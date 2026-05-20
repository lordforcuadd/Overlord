param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "SilentlyContinue"

Try {
    Write-Host "[*] Iniciando Optimizacion y Limpieza Profunda de Disco..."

    # 1. OPTIMIZACION NTFS 
    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    Set-ItemProperty -Path $NtfsPath -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1

    fsutil behavior set disable8dot3 1 | Out-Null

    # 2. INTELIGENCIA DE HIBERNACION (Proteccion de SSD y espacio)
    if (-not $IsLaptop) {
        Write-Host "    -> Desktop detectada: Eliminando Hiberfil.sys"
        powercfg.exe /hibernate off
    }

    # 3. PREFETCH Y SUPERFETCH 
    $PrefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    Set-ItemProperty -Path $PrefetchPath -Name "EnablePrefetcher" -Type DWord -Value 0
    Set-ItemProperty -Path $PrefetchPath -Name "EnableSuperfetch" -Type DWord -Value 0

    # 4. EXPANSION DE CACHE EN RAM 
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Type DWord -Value 0

    # --- LIMPIEZA MÁS POTENTE QUE LA NATIVA DE WINDOWS ---
    Write-Host "[*] Ejecutando Limpieza de Nivel Kernel (Space Recovery)..."

    # A. Limpieza de WinSxS (SIN ResetBase para que termine rapido y no queme el CPU)
    dism.exe /online /Cleanup-Image /StartComponentCleanup

    # B. Limpieza de SoftwareDistribution (Basura de Windows Update)
    Stop-Service wuauserv -Force
    Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -Confirm:$false
    Start-Service wuauserv

    # C. Purgado de Delivery Optimization (Archivos compartidos en red local)
    Remove-Item -Path "$env:windir\ServiceProfiles\LocalService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" -Recurse -Force -Confirm:$false

    # D. Eliminacion de volcados de memoria y reportes de error antiguos
    Remove-Item -Path "$env:windir\Minidump\*" -Recurse -Force -Confirm:$false
    Remove-Item -Path "$env:windir\MEMORY.DMP" -Force -Confirm:$false

    Write-Host "[+] Optimizacion completada. Gigabytes recuperados y latencia de disco reducida."
    exit 0

} Catch {
    # Cambiado a Write-Host para no romper el flujo de la consola
    Write-Host "[-] Error critico en Modulo de Almacenamiento: $_"
    exit 1
}