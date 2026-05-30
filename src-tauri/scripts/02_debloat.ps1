param([bool]$IsLaptop = $false, [int]$RamGB = 8)
$ErrorActionPreference = "Stop"

$BackupManagerPath = Join-Path $PSScriptRoot "backup_manager.psm1"
if (Test-Path $BackupManagerPath) {
    Import-Module $BackupManagerPath -Force
}

Try {
    Write-Host "[*] Iniciando purga de Bloatware y aplicaciones residuales..."

    $Apps = @(
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.GetHelp",
        "Microsoft.Getstarted", "Microsoft.Messaging", "Microsoft.3DBuilder",
        "Microsoft.People", "Microsoft.SkypeApp", "Microsoft.StickyNotes",
        "Microsoft.Wallet", "Microsoft.YourPhone", "Microsoft.ZuneVideo",
        "Microsoft.ZuneMusic", "Microsoft.MixedReality.Portal",
        "Microsoft.549981C3F5F10", "Microsoft.Windows.Ai.Copilot.Provider",
        "Microsoft.BingSearch", "Clipchamp.Clipchamp", "Microsoft.MicrosoftSolitaireCollection",
        "Disney.DisneyPlus", "SpotifyAB.SpotifyMusic", "Microsoft.Todos",
        "Microsoft.PowerAutomateDesktop", "Microsoft.Cortana"
    )

    foreach ($App in $Apps) {
        Get-AppxPackage -Name $App -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -match $App } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }

    if (Get-Command Backup-OverlordRegistryValue -ErrorAction SilentlyContinue) {
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "BingSearchEnabled" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "CortanaConsent" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "Telemetry"
        Backup-OverlordRegistryValue -TargetKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -ValueName "TurnOffWindowsCopilot" -BackupSubFolder "Telemetry"
    }

    $DataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $DataPath)) { New-Item -Path $DataPath -Force | Out-Null }
    Set-ItemProperty -Path $DataPath -Name "AllowTelemetry" -Type DWord -Value 0 -Force

    $SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (!(Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $SearchPath -Name "CortanaConsent" -Type DWord -Value 0 -Force

    $CopilotUserPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotUserPath)) { New-Item -Path $CopilotUserPath -Force | Out-Null }
    Set-ItemProperty -Path $CopilotUserPath -Name "TurnOffWindowsCopilot" -Type DWord -Value 1 -Force

    $CopilotSystemPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotSystemPath)) { New-Item -Path $CopilotSystemPath -Force | Out-Null }
    Set-ItemProperty -Path $CopilotSystemPath -Name "TurnOffWindowsCopilot" -Type DWord -Value 1 -Force

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