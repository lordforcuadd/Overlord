param([string]$GameList = "", [bool]$IsLaptop = $false, [int]$RamGB = 8)
if ($GameList -is [string]) {
    $GameList = $GameList.Split(',').Trim()
}
$ErrorActionPreference = "Stop"

Try {
    if ([string]::IsNullOrWhiteSpace($GameList)) { exit 0 }

    Write-Host "[*] Aplicando IFEO Hooks de Alto Rendimiento para juegos detectados..."
    
    $Games = $GameList -split ","

    foreach ($Game in $Games) {
        $Game = $Game.Trim()
        if ($Game -ne "") {
            # 1. Otorga Prioridad de CPU e Input/Output de datos Máxima al juego
            $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
            if (!(Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
            Set-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -Type DWord -Value 3 -Force # High Priority
            Set-ItemProperty -Path $IfeoPath -Name "IoPriority" -Type DWord -Value 3 -Force          # High Priority
            
            # 2. Inyección de banderas de mitigación de pantalla completa (FSO Bypass nativo)
            $GameKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game"
            Set-ItemProperty -Path $GameKey -Name "DISABLEDXMAXIMIZEDWINDOWEDMODE" -Type DWord -Value 1 -Force

            Write-Host "    -> Hooks de rendimiento y FSO Bypass inyectados para: $Game"
        }
    }

    exit 0
} Catch {
    exit 1
}