param([string]$GameList = "", [bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    if ([string]::IsNullOrWhiteSpace($GameList)) { exit 0 }

    Write-Host "[*] Aplicando IFEO Hooks de Alto Rendimiento para juegos detectados..."
    
    # 🚀 PARSEO UNIFICADO v2.5: Divide y limpia espacios en una sola pasada segura sin conflictos de arreglos
    $Games = $GameList -split "," | ForEach-Object { $_.Trim() }

    foreach ($Game in $Games) {
        if (![string]::IsNullOrWhiteSpace($Game)) {
            # 1. Otorga Prioridad de CPU e Input/Output de datos Máxima al juego
            $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
            if (!(Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
            Set-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -Type DWord -Value 3 -Force
            Set-ItemProperty -Path $IfeoPath -Name "IoPriority" -Type DWord -Value 3 -Force
            
            # 2. Inyección de banderas de mitigación de pantalla completa (FSO Bypass nativo)
            $GameKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game"
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