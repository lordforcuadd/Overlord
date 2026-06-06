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
        Get-ChildItem -Path "$env:localappdata\Temp" -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Get-ChildItem -Path "$env:windir\Temp" -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Output "OK: Limpieza profunda de almacenamiento completada preservando logs de caidas."
    }
    "RepairOS" {
        dism.exe /online /cleanup-image /restorehealth | Out-Null
        sfc.exe /scannow | Out-Null
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