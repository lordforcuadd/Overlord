param([string]$GameList = "", [bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    if ([string]::IsNullOrWhiteSpace($GameList)) { exit 0 }

    Write-Host "[*] Aplicando Hooks a nivel Kernel para ejecutables seleccionados..."
    
    $Games = $GameList -split ","
    $Drives = @("C:\*", "D:\*", "E:\*", "F:\*", "G:\*") # Cobertura total de discos

    foreach ($Game in $Games) {
        $Game = $Game.Trim()
        if ($Game -ne "") {
            # 1. CPU Priority Hook (Alta)
            $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Game\PerfOptions"
            if (!(Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
            Set-ItemProperty -Path $IfeoPath -Name "CpuPriorityClass" -Type DWord -Value 3

            # 2. Destruccion de FSO Global (Soporte multi-disco)
            $AppCompatPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
            if (!(Test-Path $AppCompatPath)) { New-Item -Path $AppCompatPath -Force | Out-Null }
            
            foreach ($Drive in $Drives) {
                $TargetString = "$Drive$Game"
                Set-ItemProperty -Path $AppCompatPath -Name $TargetString -Value "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" -Type String -Force
            }
            
            Write-Host "    -> IFEO Hook y FSO Disable (Multi-Disco) inyectado para: $Game"
        }
    }

    exit 0
} Catch {
    exit 1
}