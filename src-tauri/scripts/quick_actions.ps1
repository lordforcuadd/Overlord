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
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Memory Dump Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Old Chkdsk Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Recycle Bin" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error memory dump files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error minidump files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup" /v StateFlags0001 /t REG_DWORD /d 2 /f | Out-Null
        
        cleanmgr.exe /sagerun:1 | Out-Null
        
        Remove-Item -Path "$env:localappdata\Temp\*" -Recurse -Force -Confirm:$false
        Remove-Item -Path "$env:windir\Temp\*" -Recurse -Force -Confirm:$false
    }
    "RepairOS" {
        dism.exe /online /cleanup-image /startcomponentcleanup | Out-Null
        dism.exe /online /cleanup-image /restorehealth | Out-Null
        sfc /scannow | Out-Null
    }
    "FlushNet" {
        ipconfig /release | Out-Null
        ipconfig /flushdns | Out-Null
        ipconfig /renew | Out-Null
        netsh int ip reset | Out-Null
        netsh winsock reset | Out-Null
    }
}

exit 0