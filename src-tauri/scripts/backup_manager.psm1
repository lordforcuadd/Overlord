# Resolver SID e inyectar ruta HKCU_Path al inicio del módulo
$UserSID = ""
$Username = $null

# Fallback 1: Buscar dueño de explorer.exe mediante CIM
try {
    $Explorer = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Explorer) {
        $Owner = Invoke-CimMethod -InputObject $Explorer -MethodName GetOwner -ErrorAction SilentlyContinue
        if ($Owner -and $Owner.User) {
            $Username = $Owner.User
        }
    }
} catch {}

# Fallback 2: Win32_ComputerSystem
if ([string]::IsNullOrWhiteSpace($Username)) {
    try {
        $Username = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
        if ($Username -match '\\(.+)$') { $Username = $Matches[1] }
    } catch {}
}

# Fallback 3: Nombre de usuario desde explorer.exe (proceso secundario)
if ([string]::IsNullOrWhiteSpace($Username)) {
    try {
        $Username = (Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UserName -First 1)
        if ($Username -match '\\(.+)$') { $Username = $Matches[1] }
    } catch {}
}

# Fallback 4: Variable de entorno USERNAME
if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = $env:USERNAME
}

# Traducir a SID
if (-not [string]::IsNullOrWhiteSpace($Username)) {
    try {
        $NtAccount = New-Object System.Security.Principal.NTAccount($Username)
        $UserSID = $NtAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        try {
            $UserSID = (Get-CimInstance -ClassName Win32_UserAccount -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $Username }).SID
        } catch {}
    }
}

# Fallback 5: Encontrar subclave de usuario en HKEY_USERS con Volatile Environment
if ([string]::IsNullOrWhiteSpace($UserSID)) {
    try {
        $HKeyUsers = [Microsoft.Win32.Registry]::Users
        foreach ($SubkeyName in $HKeyUsers.GetSubKeyNames()) {
            if ($SubkeyName -match '^S-1-5-21-\d+-\d+-\d+-\d+$') {
                $VolatileKey = "Registry::HKEY_USERS\$SubkeyName\Volatile Environment"
                if (Test-Path $VolatileKey) {
                    $UserSID = $SubkeyName
                    break
                }
            }
        }
    } catch {}
}

# Definir la variable global de ruta de usuario
if (-not [string]::IsNullOrWhiteSpace($UserSID)) {
    $global:HKCU_Path = "Registry::HKEY_USERS\$UserSID"
} else {
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