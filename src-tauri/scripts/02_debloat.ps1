param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

Try {
    Write-Host "[*] Iniciando purga de Bloatware y aplicaciones residuales..."

    $Apps = @(
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.GetHelp",
        "Microsoft.Getstarted", "Microsoft.Messaging", "Microsoft.3DBuilder",
        "Microsoft.People", "Microsoft.SkypeApp", "Microsoft.StickyNotes",
        "Microsoft.Wallet", "Microsoft.YourPhone", "Microsoft.ZuneVideo",
        "Microsoft.ZuneMusic", "Microsoft.MixedReality.Portal", "Microsoft.XboxApp"
    )

    foreach ($App in $Apps) {
        Get-AppxPackage -Name $App -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -match $App } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }

    $DataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $DataPath)) { New-Item -Path $DataPath -Force | Out-Null }
    Set-ItemProperty -Path $DataPath -Name "AllowTelemetry" -Type DWord -Value 0 -Force

    $SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (!(Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $SearchPath -Name "CortanaConsent" -Type DWord -Value 0 -Force

    $Tasks = @(
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "Microsoft\Windows\Autochk\Proxy"
    )

    foreach ($Task in $Tasks) {
        Disable-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue
    }

    exit 0
} Catch {
    Write-Error "[-] Error critico en Modulo Debloat: $_"
    exit 1
}