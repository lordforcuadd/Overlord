param(
    [string]$Action = "status",
    [string]$GameList = ""
)

if ($null -ne $ToggleName -and $ToggleName -ne "") { $Action = $ToggleName }
if ($null -ne $IsEnabledStr -and $IsEnabledStr -ne "") { $GameList = $IsEnabledStr }

$ErrorActionPreference = "Stop"
$TaskName = "OverlordPriorityMonitor"
$ProgData = $env:ProgramData
if ([string]::IsNullOrWhiteSpace($ProgData)) {
    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    $ProgData = Join-Path $SysDrive "ProgramData"
}
$InstallDir = Join-Path $ProgData "Overlord"
$DaemonScript = Join-Path $InstallDir "priority_monitor_daemon.ps1"
$ConfigFile = Join-Path $InstallDir "games_to_optimize.txt"


if ($Action -eq "install") {
    if (!(Test-Path $InstallDir)) {
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    }
    
    # Aplicar ACL de forma mandatoria siempre
    $Acl = Get-Acl $InstallDir
    $Acl.SetAccessRuleProtection($true, $false)
    $SystemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $AdminsRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $AdminsRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administradores", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $UsersRule  = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Users", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    $UsersRule2  = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Usuarios", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    
    $Acl.AddAccessRule($SystemRule)
    $Acl.AddAccessRule($AdminsRule)
    try { $Acl.AddAccessRule($AdminsRule2) } catch {}
    $Acl.AddAccessRule($UsersRule)
    try { $Acl.AddAccessRule($UsersRule2) } catch {}
    
    Set-Acl -Path $InstallDir -AclObject $Acl | Out-Null

    $GameList | Out-File -FilePath $ConfigFile -Encoding utf8 -Force

    $DaemonCode = @'
$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:ProgramData "Overlord"
$ConfigPath = Join-Path $InstallDir "games_to_optimize.txt"
$LogPath = Join-Path $InstallDir "daemon.log"
if (!(Test-Path $ConfigPath)) { exit 0 }

function Write-DaemonLog {
    param([string]$Message)
    try {
        if (Test-Path $LogPath) {
            $File = Get-Item $LogPath -ErrorAction SilentlyContinue
            if ($null -ne $File -and $File.Length -gt 500KB) {
                Clear-Content -Path $LogPath -ErrorAction SilentlyContinue
            }
        }
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$Timestamp] $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {}
}

Write-DaemonLog "Iniciando daemon de prioridad de juegos..."

while ($true) {
    try {
        $Games = Get-Content -Path $ConfigPath -ErrorAction Stop
        if ($Games) {
            $GamesList = $Games -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
            if ($GamesList) {
                foreach ($Game in $GamesList) {
                    $ProcName = if ($Game -like "*.exe") { $Game -replace '\.exe$', '' } else { $Game }
                    try {
                        $Procs = [System.Diagnostics.Process]::GetProcessesByName($ProcName)
                        if ($null -ne $Procs -and $Procs.Count -gt 0) {
                            foreach ($Proc in $Procs) {
                                try {
                                    if ($ProcName -eq "javaw") {
                                        $IsMinecraft = $false
                                        try {
                                            $Path = $Proc.MainModule.FileName
                                            if ($Path -and ($Path.ToLower().Contains(".minecraft") -or $Path.ToLower().Contains("minecraft"))) {
                                                $IsMinecraft = $true
                                            }
                                        } catch {}
                                        if (-not $IsMinecraft) {
                                            try {
                                                $CimProc = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($Proc.Id)" -ErrorAction SilentlyContinue
                                                if ($CimProc -and $CimProc.CommandLine -and ($CimProc.CommandLine.ToLower().Contains(".minecraft") -or $CimProc.CommandLine.ToLower().Contains("minecraft") -or $CimProc.CommandLine.ToLower().Contains("tlauncher") -or $CimProc.CommandLine.ToLower().Contains("prism") -or $CimProc.CommandLine.ToLower().Contains("multimc"))) {
                                                    $IsMinecraft = $true
                                                }
                                            } catch {}
                                        }
                                        if (-not $IsMinecraft) {
                                            if ($null -ne $Proc) { $Proc.Dispose() }
                                            continue
                                        }
                                    }
                                    if ($Proc.PriorityClass -ne 'High') {
                                        $Proc.PriorityClass = 'High'
                                        Write-DaemonLog "Establecida prioridad ALTA para el proceso: $($Proc.Name) (PID: $($Proc.Id))"
                                    }
                                } catch {
                                    Write-DaemonLog "No se pudo cambiar la prioridad del proceso $($Proc.Name): $_"
                                } finally {
                                    if ($null -ne $Proc) { $Proc.Dispose() }
                                }
                            }
                        }
                    } catch {
                        Write-DaemonLog "Error buscando procesos para $ProcName: $_"
                    }
                }
            }
        }
    } catch {
        Write-DaemonLog "Error general en el ciclo del daemon: $_"
    }
    Start-Sleep -Seconds 15
}
'@
    $DaemonCode | Out-File -FilePath $DaemonScript -Encoding utf8 -Force

    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -eq $ExistingTask) {
        $ActionCmd = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -File `"$DaemonScript`""
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        
        Register-ScheduledTask -TaskName $TaskName -Action $ActionCmd -Trigger $Trigger -Principal $Principal -Settings $Settings | Out-Null
    }
    
    $RunningTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($RunningTask.State -ne "Running") {
        Start-ScheduledTask -TaskName $TaskName | Out-Null
    }

    Write-Output "installed"
}
elseif ($Action -eq "uninstall") {
    Uninstall-OverlordPriorityDaemon
    Write-Output "uninstalled"
}
elseif ($Action -eq "status") {
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $ExistingTask -and ($ExistingTask.State -eq "Ready" -or $ExistingTask.State -eq "Running")) {
        Write-Output "installed"
    } else {
        Write-Output "uninstalled"
    }
}
