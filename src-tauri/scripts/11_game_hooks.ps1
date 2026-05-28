param(
    [string]$GameList = "", 
    [bool]$IsLaptop = $false, 
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

$BackupManagerPath = Join-Path $PSScriptRoot "backup_manager.psm1"
if (Test-Path $BackupManagerPath) {
    Import-Module $BackupManagerPath -Force
}

Try {
    if ([string]::IsNullOrWhiteSpace($GameList)) { 
        Write-Host "[-] No se especificaron ejecutables en GameList. Saltando inyección de hilos."
        exit 0 
    }

    Write-Host "[*] Aplicando IFEO Hooks de Alto Rendimiento para juegos detectados..."
    
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $Games = $GameList -split "," | ForEach-Object { $_.Trim() }

    foreach ($Game in $Games) {
        if (![string]::IsNullOrWhiteSpace($Game)) {
            $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
            $GameKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game"
            
            $OrigCpuPriority = $null
            $OrigIoPriority = $null
            if (Test-Path $IfeoPath) {
                $OrigCpuPriority = (Get-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -ErrorAction SilentlyContinue).CpuPriorityClass
                $OrigIoPriority = (Get-ItemProperty -Path $IfeoPath -Name "IoPriority" -ErrorAction SilentlyContinue).IoPriority
            }

            $OrigFsoBypass = $null
            if (Test-Path $GameKey) {
                $OrigFsoBypass = (Get-ItemProperty -Path $GameKey -Name "DISABLEDXMAXIMIZEDWINDOWEDMODE" -ErrorAction SilentlyContinue).DISABLEDXMAXIMIZEDWINDOWEDMODE
            }

            if ((Get-ItemProperty -Path $BackupPath -Name "${Game}_CpuPriority" -ErrorAction SilentlyContinue) -eq $null) {
                $BckCpu = if ($OrigCpuPriority -eq $null) { '_ABSENT_' } else { $OrigCpuPriority }
                Set-ItemProperty -Path $BackupPath -Name "${Game}_CpuPriority" -Value $BckCpu -Force | Out-Null
            }

            if ((Get-ItemProperty -Path $BackupPath -Name "${Game}_IoPriority" -ErrorAction SilentlyContinue) -eq $null) {
                $BckIo = if ($OrigIoPriority -eq $null) { '_ABSENT_' } else { $OrigIoPriority }
                Set-ItemProperty -Path $BackupPath -Name "${Game}_IoPriority" -Value $BckIo -Force | Out-Null
            }

            if ((Get-ItemProperty -Path $BackupPath -Name "${Game}_FsoBypass" -ErrorAction SilentlyContinue) -eq $null) {
                $BckFso = if ($OrigFsoBypass -eq $null) { '_ABSENT_' } else { $OrigFsoBypass }
                Set-ItemProperty -Path $BackupPath -Name "${Game}_FsoBypass" -Value $BckFso -Force | Out-Null
            }

            if (!(Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
            Set-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -Type DWord -Value 3 -Force | Out-Null
            Set-ItemProperty -Path $IfeoPath -Name "IoPriority" -Type DWord -Value 3 -Force | Out-Null
            
            if (!(Test-Path $GameKey)) { New-Item -Path $GameKey -Force | Out-Null }
            Set-ItemProperty -Path $GameKey -Name "DISABLEDXMAXIMIZEDWINDOWEDMODE" -Type DWord -Value 1 -Force | Out-Null

            Write-Host "    -> Hooks inyectados para: $Game"
        }
    }

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Game Hooks: $_"
    exit 1
}