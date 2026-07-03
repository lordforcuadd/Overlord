# $HKCU_Path ya está resuelto e inyectado globalmente por sid_resolver.ps1
if (-not (Get-Variable -Name 'HKCU_Path' -Scope 'Global' -ErrorAction SilentlyContinue)) {
    $global:HKCU_Path = "HKCU:"
}

function Get-SafeRegistryValue {
    param([string]$Path, [string]$Name)
    $obj = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $obj -and $null -ne $obj.PSObject.Properties[$Name]) {
        return $obj.$Name
    }
    return $null
}

function Backup-OverlordRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetKey,
        [Parameter(Mandatory=$true)][string]$ValueName,
        [Parameter(Mandatory=$true)][string]$BackupSubFolder
    )
    
    try {
        # Redirigir HKCU de forma dinámica
        if ($TargetKey -match "^HKCU:") {
            $TargetKey = $TargetKey -replace '^HKCU:', $global:HKCU_Path
        }
        
        $GlobalBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\$BackupSubFolder"
        if (!(Test-Path $GlobalBackupPath)) {
            New-Item -Path $GlobalBackupPath -Force | Out-Null
        }
        
        if (Test-Path $TargetKey) {
            $OrigValue = Get-SafeRegistryValue -Path $TargetKey -Name $ValueName
            $ExistingBackup = Get-SafeRegistryValue -Path $GlobalBackupPath -Name $ValueName
            
            if ($null -ne $OrigValue -and $null -eq $ExistingBackup) {
                $RegKey = Get-Item -Path $TargetKey -ErrorAction SilentlyContinue
                if ($null -ne $RegKey) {
                    $Kind = $RegKey.GetValueKind($ValueName)
                    Set-ItemProperty -Path $GlobalBackupPath -Name "${ValueName}_Kind" -Value $Kind.ToString() -Force | Out-Null
                    Set-ItemProperty -Path $GlobalBackupPath -Name $ValueName -Value $OrigValue -Force | Out-Null
                }
            } elseif ($null -eq $OrigValue -and $null -eq $ExistingBackup) {
                Set-ItemProperty -Path $GlobalBackupPath -Name $ValueName -Value '_ABSENT_' -Force | Out-Null
            }
        } else {
            $ExistingBackup = Get-SafeRegistryValue -Path $GlobalBackupPath -Name $ValueName
            if ($null -eq $ExistingBackup) {
                Set-ItemProperty -Path $GlobalBackupPath -Name $ValueName -Value '_ABSENT_' -Force | Out-Null
            }
        }
    } catch {
        Write-Warning "No se pudo realizar el respaldo del valor de registro $ValueName en $TargetKey : $_"
    }
}

function Restore-OverlordRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetKey,
        [Parameter(Mandatory=$true)][string]$ValueName,
        [Parameter(Mandatory=$true)][string]$BackupSubFolder
    )
    
    try {
        # Redirigir HKCU de forma dinámica
        if ($TargetKey -match "^HKCU:") {
            $TargetKey = $TargetKey -replace '^HKCU:', $global:HKCU_Path
        }
        
        $GlobalBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\$BackupSubFolder"
        if (Test-Path $GlobalBackupPath) {
            $BackupValue = Get-SafeRegistryValue -Path $GlobalBackupPath -Name $ValueName
            $SavedKind = Get-SafeRegistryValue -Path $GlobalBackupPath -Name "${ValueName}_Kind"
            
            if ($null -ne $BackupValue) {
                if ($BackupValue -eq '_ABSENT_') {
                     Remove-ItemProperty -Path $TargetKey -Name $ValueName -ErrorAction SilentlyContinue | Out-Null
                } else {
                    if (!(Test-Path $TargetKey)) { New-Item -Path $TargetKey -Force | Out-Null }
                    $Type = if ($SavedKind) { $SavedKind } else { "DWord" }
                    Set-ItemProperty -Path $TargetKey -Name $ValueName -Type $Type -Value $BackupValue -Force | Out-Null
                }
            }
        }
    } catch {
        Write-Warning "No se pudo restaurar el valor de registro $ValueName en $TargetKey : $_"
    }
}

function Backup-OverlordPowerSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$SchemeGuid,
        [Parameter(Mandatory=$true)][string]$SubGroupGuid,
        [Parameter(Mandatory=$true)][string]$SettingGuid,
        [Parameter(Mandatory=$true)][string]$BackupName
    )
    
    $PowerBackup = "HKLM:\SOFTWARE\Overlord\Backup\Power"
    if (!(Test-Path $PowerBackup)) { New-Item -Path $PowerBackup -Force | Out-Null }

    if (!(Get-ItemProperty -Path $PowerBackup -Name $BackupName -ErrorAction SilentlyContinue)) {
        $Value = $null
        
        # Lectura directa del registro (locale-independiente y siempre funciona)
        $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$SchemeGuid\$SubGroupGuid\$SettingGuid"
        if (Test-Path $RegPath) {
            $regProps = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
            if ($null -ne $regProps) {
                $Value = $regProps.ACSettingIndex
            }
        }
        
        $BckVal = if ($null -eq $Value) { '_ABSENT_' } else { $Value }
        Set-ItemProperty -Path $PowerBackup -Name $BackupName -Value $BckVal -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

function Uninstall-OverlordPriorityDaemon {
    $TaskName = "OverlordPriorityMonitor"
    $ProgData = $env:ProgramData
    if ([string]::IsNullOrWhiteSpace($ProgData)) {
        $SysDrive = $env:SystemDrive
        if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
        $ProgData = Join-Path $SysDrive "ProgramData"
    }
    $InstallDir = Join-Path $ProgData "Overlord"
    
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $ExistingTask) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Out-Null
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }

    # Matar de forma explicita procesos PowerShell huérfanos del daemon (WMI/CIM compatible con PS 5.1)
    try {
        $DaemonProcs = Get-CimInstance -ClassName Win32_Process -Filter "(Name='powershell.exe' OR Name='pwsh.exe') AND CommandLine LIKE '%priority_monitor_daemon.ps1%'" -ErrorAction SilentlyContinue
        if ($null -eq $DaemonProcs -or @($DaemonProcs).Count -eq 0) {
            $DaemonProcs = Get-WmiObject -Class Win32_Process -Filter "(Name='powershell.exe' OR Name='pwsh.exe') AND CommandLine LIKE '%priority_monitor_daemon.ps1%'" -ErrorAction SilentlyContinue
        }
        if ($null -ne $DaemonProcs) {
            foreach ($P in $DaemonProcs) {
                $pidToKill = $null
                if ($null -ne $P.ProcessId) { $pidToKill = $P.ProcessId }
                elseif ($null -ne $P.ProcessID) { $pidToKill = $P.ProcessID }
                if ($null -ne $pidToKill) {
                    Stop-Process -Id $pidToKill -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
    } catch {}

    # Limpieza de la carpeta raíz del daemon en ProgramData
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

function Find-FileFaster {
    param(
        [string]$Path,
        [string]$Filter,
        [int]$MaxDepth = 3
    )
    if (!(Test-Path $Path)) { return $null }
    try {
        $files = [System.IO.Directory]::GetFiles($Path, $Filter)
        if ($files.Count -gt 0) {
            return [System.IO.FileInfo]::new($files[0])
        }
    } catch {}
    if ($MaxDepth -le 0) { return $null }
    try {
        $subdirs = [System.IO.Directory]::GetDirectories($Path)
        foreach ($dir in $subdirs) {
            $found = Find-FileFaster -Path $dir -Filter $Filter -MaxDepth ($MaxDepth - 1)
            if ($found) { return $found }
        }
    } catch {}
    return $null
}