param([string]$GameList = "", [bool]$IsLaptop = $false, [int]$RamGB = 8)
if ($GameList -is [string]) {
    $GameList = $GameList.Split(',').Trim()
}
$ErrorActionPreference = "Stop"

Try {
    if ([string]::IsNullOrWhiteSpace($GameList)) { exit 0 }

    Write-Host "[*] Aplicando IFEO Hooks (Prioridad CPU) para juegos detectados..."
    
    $Games = $GameList -split ","

    foreach ($Game in $Games) {
        $Game = $Game.Trim()
        if ($Game -ne "") {
            $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
            if (!(Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
            Set-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -Type DWord -Value 3 -Force
            
            Write-Host "    -> Prioridad de CPU (High) inyectada para: $Game"
        }
    }

    exit 0
} Catch {
    exit 1
}