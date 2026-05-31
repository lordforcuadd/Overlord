param(
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

$BackupManagerPath = Join-Path $PSScriptRoot "backup_manager.psm1"
if (Test-Path $BackupManagerPath) {
    Import-Module $BackupManagerPath -Force
}

Try {
    Write-Host "[*] Reconfigurando perfiles multimedia y afinidad de Hardware (IRQ)..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\CPU"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $TasksPath = "$ProfilePath\Tasks\Games"
    if (!(Test-Path $TasksPath)) { New-Item -Path $TasksPath -Force | Out-Null }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "GPU Priority" -BackupSubFolder "CPU"
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "Priority" -BackupSubFolder "CPU"
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "Scheduling Category" -BackupSubFolder "CPU"
        Backup-OverlordRegistryValue -TargetKey $TasksPath -ValueName "SFIO Priority" -BackupSubFolder "CPU"
    }

    Set-ItemProperty -Path $TasksPath -Name "GPU Priority" -Type DWord -Value 8 -Force
    Set-ItemProperty -Path $TasksPath -Name "Priority" -Type DWord -Value 6 -Force
    Set-ItemProperty -Path $TasksPath -Name "Scheduling Category" -Type String -Value "High" -Force
    Set-ItemProperty -Path $TasksPath -Name "SFIO Priority" -Type String -Value "High" -Force

    $NetBackupKey = "$BackupPath\NetworkAffinity"
    if (!(Test-Path $NetBackupKey)) { New-Item -Path $NetBackupKey -Force | Out-Null }

    $Devices = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\*\*\Device Parameters" -ErrorAction SilentlyContinue
    foreach ($Device in $Devices) {
        $Class = (Get-ItemProperty -Path $Device.PSParentPath -ErrorAction SilentlyContinue).Class
        
        if ($Class -eq "Net") {
            $AffinityPath = "$($Device.PSPath)\Interrupt Management\Affinity Policy"
            if (!(Test-Path $AffinityPath)) { New-Item -Path $AffinityPath -Force | Out-Null }
            
            $DeviceID = ($Device.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
            $OrigPolicy = (Get-ItemProperty -Path $AffinityPath -Name "DevicePolicy" -ErrorAction SilentlyContinue).DevicePolicy
            $OrigOverride = (Get-ItemProperty -Path $AffinityPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue).AssignmentSetOverride

            if ((Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Policy" -ErrorAction SilentlyContinue) -eq $null) {
                $BckPolicy = if ($OrigPolicy -eq $null) { '_ABSENT_' } else { $OrigPolicy }
                Set-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Policy" -Value $BckPolicy -Force | Out-Null
                
                $BckOverride = if ($OrigOverride -eq $null) { '_ABSENT_' } else { $OrigOverride }
                Set-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_Override" -Value $BckOverride -Force | Out-Null
            }

            Set-ItemProperty -Path $AffinityPath -Name "DevicePolicy" -Type DWord -Value 4 -Force | Out-Null
            $MaskValue = [math]::Pow(2, 2)
            $AffinityMask = [System.BitConverter]::GetBytes([int]$MaskValue)
            Set-ItemProperty -Path $AffinityPath -Name "AssignmentSetOverride" -Type Binary -Value $AffinityMask -Force | Out-Null
        }
        
        if ($Class -eq "MEDIA") {
            $AffinityPath = "$($Device.PSPath)\Interrupt Management\Affinity Policy"
            if (!(Test-Path $AffinityPath)) { New-Item -Path $AffinityPath -Force | Out-Null }
            
            $DeviceID = ($Device.PSPath -split "::" | Select-Object -Last 1) -replace "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\", "" -replace "\\", "_"
            
            if ((Get-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_AudioPolicy" -ErrorAction SilentlyContinue) -eq $null) {
                $OrigAudioPolicy = (Get-ItemProperty -Path $AffinityPath -Name "DevicePolicy" -ErrorAction SilentlyContinue).DevicePolicy
                $BckAudioPolicy = if ($OrigAudioPolicy -eq $null) { '_ABSENT_' } else { $OrigAudioPolicy }
                Set-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_AudioPolicy" -Value $BckAudioPolicy -Force | Out-Null
                
                $OrigAudioOverride = (Get-ItemProperty -Path $AffinityPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue).AssignmentSetOverride
                $BckAudioOverride = if ($OrigAudioOverride -eq $null) { '_ABSENT_' } else { $OrigAudioOverride }
                Set-ItemProperty -Path $NetBackupKey -Name "${DeviceID}_AudioOverride" -Value $BckAudioOverride -Force | Out-Null
            }

            Set-ItemProperty -Path $AffinityPath -Name "DevicePolicy" -Type DWord -Value 4 -Force | Out-Null
            $AudioMaskValue = [math]::Pow(2, 1)
            $AudioMask = [System.BitConverter]::GetBytes([int]$AudioMaskValue)
            Set-ItemProperty -Path $AffinityPath -Name "AssignmentSetOverride" -Type Binary -Value $AudioMask -Force | Out-Null
        }
    }

    Write-Host "[+] Carga equilibrada en los núcleos del CPU. Prioridades multimedia inyectadas."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Gestion IRQ y Procesador: $_"
    exit 1
}