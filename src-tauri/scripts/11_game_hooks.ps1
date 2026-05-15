param([string]$GameList = "", [bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    if ([string]::IsNullOrWhiteSpace($GameList)) {
        Write-Host "[*] No se recibieron juegos para optimizar. Abortando inyección."
        exit 0
    }

    Write-Host "[*] Aplicando Hooks a nivel Kernel para ejecutables seleccionados..."
    
    $Games = $GameList -split ","

    foreach ($Game in $Games) {
        $Game = $Game.Trim()
        if ($Game -ne "") {
            $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
            
            if (!(Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
            
            Set-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -Type DWord -Value 3
            Write-Host "    -> IFEO Hook inyectado (Prioridad Alta) para: $Game"
        }
    }

    Write-Host "[+] Game Hooks aplicados exitosamente."
    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo de Game Hooks: $_"
    exit 1
}