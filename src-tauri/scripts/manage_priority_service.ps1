param(
    [string]$Action = "status",
    [string]$GameList = ""
)

if ($null -ne $ToggleName -and $ToggleName -ne "") { $Action = $ToggleName }
if ($null -ne $IsEnabledStr -and $IsEnabledStr -ne "") { $GameList = $IsEnabledStr }

$ErrorActionPreference = "Stop"
$TaskName = "OverlordPriorityMonitor"
$InstallDir = "C:\ProgramData\Overlord"
$DaemonScript = Join-Path $InstallDir "priority_monitor_daemon.ps1"
$ConfigFile = Join-Path $InstallDir "games_to_optimize.txt"

if ($Action -eq "install") {
    if (!(Test-Path $InstallDir)) {
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        $Acl = Get-Acl $InstallDir
        $Acl.SetAccessRuleProtection($true, $false)
        $SystemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $AdminsRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $UsersRule  = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Users", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
        $Acl.AddAccessRule($SystemRule)
        $Acl.AddAccessRule($AdminsRule)
        $Acl.AddAccessRule($UsersRule)
        Set-Acl -Path $InstallDir -AclObject $Acl | Out-Null
    }

    $GameList | Out-File -FilePath $ConfigFile -Encoding utf8 -Force

    $DaemonCode = @'
$ErrorActionPreference = "SilentlyContinue"
$ConfigPath = "C:\ProgramData\Overlord\games_to_optimize.txt"
if (!(Test-Path $ConfigPath)) { exit 0 }
while ($true) {
    $Games = Get-Content -Path $ConfigPath -ErrorAction SilentlyContinue
    if ($Games) {
        $GamesList = $Games -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
        if ($GamesList) {
            foreach ($Game in $GamesList) {
                $ProcName = if ($Game -like "*.exe") { $Game -replace '\.exe$', '' } else { $Game }
                $Procs = Get-Process -Name $ProcName -ErrorAction SilentlyContinue
                foreach ($Proc in $Procs) {
                    try {
                        if ($Proc.PriorityClass -ne 'High') {
                            $Proc.PriorityClass = 'High'
                        }
                    } catch {}
                }
            }
        }
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
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $ExistingTask) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }

    if (Test-Path $ConfigFile) { Remove-Item $ConfigFile -Force | Out-Null }
    if (Test-Path $DaemonScript) { Remove-Item $DaemonScript -Force | Out-Null }

    Write-Output "uninstalled"
}
elseif ($Action -eq "status") {
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $ExistingTask) {
        Write-Output "installed"
    } else {
        Write-Output "uninstalled"
    }
}
