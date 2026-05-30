function Backup-OverlordRegistryValue {
    [CmdletBinding()]\
    param(
        [Parameter(Mandatory=$true)][string]$TargetKey,
        [Parameter(Mandatory=$true)][string]$ValueName,
        [Parameter(Mandatory=$true)][string]$BackupSubFolder
    )
    
    $GlobalBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\$BackupSubFolder"
    if (!(Test-Path $GlobalBackupPath)) {
        New-Item -Path $GlobalBackupPath -Force | Out-Null
    }
    
    if (Test-Path $TargetKey) {
        $OrigValue = (Get-ItemProperty -Path $TargetKey -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
        $ExistingBackup = (Get-ItemProperty -Path $GlobalBackupPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
        
        if ($OrigValue -ne $null -and $ExistingBackup -eq $null) {
            $RegKey = Get-Item -Path $TargetKey
            $Kind = $RegKey.GetValueKind($ValueName)
            Set-ItemProperty -Path $GlobalBackupPath -Name "${ValueName}_Kind" -Value $Kind.ToString() -Force | Out-Null
            Set-ItemProperty -Path $GlobalBackupPath -Name $ValueName -Value $OrigValue -Force | Out-Null
        } elseif ($OrigValue -eq $null -and $ExistingBackup -eq $null) {
            Set-ItemProperty -Path $GlobalBackupPath -Name $ValueName -Value '_ABSENT_' -Force | Out-Null
        }
    }
}

function Restore-OverlordRegistryValue {
    [CmdletBinding()]\
    param(
        [Parameter(Mandatory=$true)][string]$TargetKey,
        [Parameter(Mandatory=$true)][string]$ValueName,
        [Parameter(Mandatory=$true)][string]$BackupSubFolder
    )
    
    $GlobalBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\$BackupSubFolder"
    if (Test-Path $GlobalBackupPath) {
        $BackupValue = (Get-ItemProperty -Path $GlobalBackupPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
        $SavedKind = (Get-ItemProperty -Path $GlobalBackupPath -Name "${ValueName}_Kind" -ErrorAction SilentlyContinue)."${ValueName}_Kind"
        
        if ($BackupValue -ne $null) {
            if ($BackupValue -eq '_ABSENT_') {
                Remove-ItemProperty -Path $TargetKey -Name $ValueName -ErrorAction SilentlyContinue | Out-Null
            } else {
                if (!(Test-Path $TargetKey)) {
                    New-Item -Path $TargetKey -Force | Out-Null
                }
                $Type = if ($SavedKind) { $SavedKind } else { "DWord" }
                Set-ItemProperty -Path $TargetKey -Name $ValueName -Type $Type -Value $BackupValue -Force | Out-Null
            }
        }
    }
}