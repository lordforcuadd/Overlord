function Backup-RegistryValue {
    param(
        [string]$TargetKey,
        [string]$ValueName,
        [string]$BackupSubFolder
    )
    
    $GlobalBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\$BackupSubFolder"
    if (!(Test-Path $GlobalBackupPath)) {
        New-Item -Path $GlobalBackupPath -Force | Out-Null
    }
    
    if (Test-Path $TargetKey) {
        $OrigValue = (Get-ItemProperty -Path $TargetKey -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
        $ExistingBackup = (Get-ItemProperty -Path $GlobalBackupPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
        
        if ($OrigValue -ne $null -and $ExistingBackup -eq $null) {
            Set-ItemProperty -Path $GlobalBackupPath -Name $ValueName -Value $OrigValue -Force | Out-Null
        } elseif ($OrigValue -eq $null -and $ExistingBackup -eq $null) {
            Set-ItemProperty -Path $GlobalBackupPath -Name $ValueName -Value 999 -Force | Out-Null
        }
    }
}