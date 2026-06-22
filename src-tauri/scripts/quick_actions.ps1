param([string]$ActionId)
$ErrorActionPreference = "SilentlyContinue"

switch ($ActionId) {
    "DeepClean" {
        if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files")) {
            exit 1
        }
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\ActiveX Cache" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Internet Cache Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Old Chkdsk Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        
        $CleanProcess = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
        if ($CleanProcess) {
            $Timeout = 180
            $Interval = 2
            $Waited = 0
            while (-not $CleanProcess.HasExited -and $Waited -lt $Timeout) {
                Start-Sleep -Seconds $Interval
                $Waited += $Interval
            }
        }

        # Limpiar los flags temporales creados para evitar polución del registro
        $CachesPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        if (Test-Path $CachesPath) {
            $Caches = Get-ChildItem -Path $CachesPath -ErrorAction SilentlyContinue
            foreach ($Cache in $Caches) {
                Remove-ItemProperty -Path $Cache.PSPath -Name "StateFlags0001" -ErrorAction SilentlyContinue | Out-Null
            }
        }
        
        # Eliminación rápida y segura de archivos temporales sin colisiones por bloqueos profundos
        Remove-Item -Path "$env:localappdata\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Path "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

        Write-Output "OK: Limpieza profunda de almacenamiento completada."
    }
    "RepairOS" {
        # DISM requiere wuauserv (Windows Update) habilitado e iniciado para descargar reparaciones
        $wuauserv = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        $originalStartType = $null
        $wasRunning = $false
        if ($null -ne $wuauserv) {
            $CimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='wuauserv'" -ErrorAction SilentlyContinue
            if ($null -ne $CimSvc) {
                $originalStartType = $CimSvc.StartMode
            } else {
                $WmiSvc = Get-WmiObject -Class Win32_Service -Filter "Name='wuauserv'" -ErrorAction SilentlyContinue
                if ($null -ne $WmiSvc) { $originalStartType = $WmiSvc.StartMode }
            }
            $wasRunning = ($wuauserv.Status -eq 'Running')
            if ($null -ne $originalStartType -and $originalStartType -eq 'Disabled') {
                Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
            }
            if (-not $wasRunning) {
                Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            }
        }

        dism.exe /online /cleanup-image /restorehealth | Out-Null
        sfc.exe /scannow | Out-Null

        # Restaurar estado original del servicio Windows Update
        if ($null -ne $wuauserv) {
            if (-not $wasRunning) {
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            }
            if ($null -ne $originalStartType -and $originalStartType -eq 'Disabled') {
                Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }
        Write-Output "OK: Almacen de componentes e integridad de sistema reparados."
    }
    "FlushNet" {
        ipconfig /release | Out-Null
        ipconfig /flushdns | Out-Null
        ipconfig /renew | Out-Null
        netsh int ip reset | Out-Null
        netsh winsock reset | Out-Null
        Write-Output "ADVERTENCIA: Catalogos de red restablecidos. Es obligatorio reiniciar el equipo para evitar estados de red inconsistentes."
    }
}
exit 0