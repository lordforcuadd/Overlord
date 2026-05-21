param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando purga de optimizaciones de Overlord y volviendo a Stock..."

    # 1. Revertir Periféricos y Ratón
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 100
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 2
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Type String -Value "1"
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe" -Recurse -Force
    bcdedit /deletevalue useplatformtick | Out-Null
    bcdedit /deletevalue disabledynamictick | Out-Null

    # 2. Revertir Red
    $Interfaces = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($Interface in $Interfaces) {
        $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Interface.SettingID)"
        Remove-ItemProperty -Path $TcpPath -Name "TcpAckFrequency"
        Remove-ItemProperty -Path $TcpPath -Name "TCPNoDelay"
    }
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit"

    # 3. Revertir GPU / HAGS y DWM
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Type DWord -Value 1
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" # Restaura MPO
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" -Name "CpuPriorityClass"

    # 4. Revertir Telemetría, VBS y Defender
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
    Set-Service "DiagTrack" -StartupType Automatic
    Set-MpPreference -ScanAvgCPULoadFactor 50 

    # 5. Revertir RAM y Almacenamiento
    $MemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $MemPath -Name "DisablePagingExecutive" -Type DWord -Value 0
    Enable-MMAgent -MemoryCompression
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 0

    # 6. Revertir Energía y MMCSS
    $PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    Set-ItemProperty -Path $PowerPath -Name "ValueMax" -Type DWord -Value 100
    Set-ItemProperty -Path $PowerPath -Name "ValueMin" -Type DWord -Value 5
    powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e

    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Type DWord -Value 20

    # 7. Limpiar Hooks (IFEO)
    $TargetGames = @("League of Legends.exe", "VALORANT-Win64-Shipping.exe", "cs2.exe", "FortniteClient-Win64-Shipping.exe", "r5apex.exe", "Overwatch.exe")
    
    foreach ($Game in $TargetGames) {
        $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game"
        if (Test-Path $IfeoPath) { Remove-Item -Path $IfeoPath -Recurse -Force }
    }

    Write-Host "[+] Desinfeccion completa. Sistema revertido a la normalidad de Windows."
    exit 0
} Catch {
    exit 1
}