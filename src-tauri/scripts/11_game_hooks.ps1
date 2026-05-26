param([string]$GameList = "", [bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    if ([string]::IsNullOrWhiteSpace($GameList)) { exit 0 }

    Write-Host "[*] Aplicando IFEO Hooks de Alto Rendimiento para juegos detectados..."
    
    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $Games = $GameList -split "," | ForEach-Object { $_.Trim() }

    foreach ($Game in $Games) {
        if (![string]::IsNullOrWhiteSpace($Game)) {
            
            # Mapear rutas e inyectar persistencia simétrica de resguardo
            $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
            $GameKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game"
            
            # Guardar valores previos si la máquina del usuario ya contaba con IFEO de terceros
            if (Test-Path $IfeoPath) {
                $OrigCpuPriority = (Get-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -ErrorAction SilentlyContinue).CpuPriorityClass
                $OrigIoPriority = (Get-ItemProperty -Path $IfeoPath -Name "IoPriority" -ErrorAction SilentlyContinue).IoPriority
                
                if ($OrigCpuPriority -ne $null) { Set-ItemProperty -Path $BackupPath -Name "${Game}_CpuPriority" -Value $OrigCpuPriority -Force }
                if ($OrigIoPriority -ne $null) { Set-ItemProperty -Path $BackupPath -Name "${Game}_IoPriority" -Value $OrigIoPriority -Force }
            }
            if (Test-Path $GameKey) {
                $OrigFsoBypass = (Get-ItemProperty -Path $GameKey -Name "DISABLEDXMAXIMIZEDWINDOWEDMODE" -ErrorAction SilentlyContinue).DISABLEDXMAXIMIZEDWINDOWEDMODE
                if ($OrigFsoBypass -ne $null) { Set-ItemProperty -Path $BackupPath -Name "${Game}_FsoBypass" -Value $OrigFsoBypass -Force }
            }

            # Inyección limpia y asíncrona de Overlord
            if (!(Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
            Set-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -Type DWord -Value 3 -Force
            Set-ItemProperty -Path $IfeoPath -Name "IoPriority" -Type DWord -Value 3 -Force
            
            if (!(Test-Path $GameKey)) { New-Item -Path $GameKey -Force | Out-Null }
            Set-ItemProperty -Path $GameKey -Name "DISABLEDXMAXIMIZEDWINDOWEDMODE" -Type DWord -Value 1 -Force

            Write-Host "    -> Hooks de rendimiento y FSO Bypass inyectados para: $Game"
        }
    }

    exit 0
} Catch {
    Write-Error "[-] Error crítico en Módulo de Game Hooks: $_"
    exit 1
}