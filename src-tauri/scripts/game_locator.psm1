function Get-LauncherRoots {
    $LauncherRoots = [System.Collections.Generic.List[string]]::new()
    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    $ProgramFiles = $env:ProgramFiles
    if ([string]::IsNullOrWhiteSpace($ProgramFiles)) { $ProgramFiles = Join-Path $SysDrive "Program Files" }
    $ProgramFilesx86 = ${env:ProgramFiles(x86)}
    if ([string]::IsNullOrWhiteSpace($ProgramFilesx86)) { $ProgramFilesx86 = Join-Path $SysDrive "Program Files (x86)" }

    $LauncherRoots.AddRange([string[]]@(
        (Join-Path $SysDrive "Riot Games"),
        (Join-Path $SysDrive "XboxGames")
    ))

    try {
        $FixedDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object { $_.Name }
        foreach ($Drive in $FixedDrives) {
            $CandidatePaths = @(
                (Join-Path $Drive "Riot Games"),
                (Join-Path $Drive "Games"),
                (Join-Path $Drive "SteamLibrary\steamapps\common")
            )
            foreach ($P in $CandidatePaths) {
                if (Test-Path $P) {
                    if (!$LauncherRoots.Contains($P)) {
                        $LauncherRoots.Add($P)
                    }
                }
            }
        }
    } catch {}

    # Buscar rutas de Steam en el Registro
    $steamProps = Get-ItemProperty -Path "$global:HKCU_Path\Software\Valve\Steam" -ErrorAction SilentlyContinue
    $SteamPathReg = if ($null -ne $steamProps) { $steamProps.SteamPath } else { $null }
    if ($SteamPathReg) { $LauncherRoots.Add(Join-Path $SteamPathReg "steamapps\common" })
    $steamProps2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam" -ErrorAction SilentlyContinue
    $SteamPathReg2 = if ($null -ne $steamProps2) { $steamProps2.InstallPath } else { $null }
    if ($SteamPathReg2) { $LauncherRoots.Add(Join-Path $SteamPathReg2 "steamapps\common" })

    # Buscar rutas de Epic Games en el Registro
    $epicProps = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\EpicGames\Unreal Engine" -ErrorAction SilentlyContinue
    $EpicPathReg = if ($null -ne $epicProps) { $epicProps.INSTALLDIR } else { $null }
    if ($EpicPathReg) { $LauncherRoots.Add($EpicPathReg })

    # Buscar librerias adicionales de Steam en libraryfolders.vdf
    if ($SteamPathReg -and (Test-Path (Join-Path $SteamPathReg "steamapps\libraryfolders.vdf"))) {
        try {
            $VdfPath = Join-Path $SteamPathReg "steamapps\libraryfolders.vdf"
            $VdfContent = Get-Content -Path $VdfPath -ErrorAction SilentlyContinue
            if ($VdfContent) {
                foreach ($Line in $VdfContent) {
                    if ($Line -match '"path"\s+"([^"]+)"') {
                        $LibPath = $Matches[1] -replace '\\\\', '\'
                        $CommonPath = Join-Path $LibPath "steamapps\common"
                        if (Test-Path $CommonPath) {
                            if (!$LauncherRoots.Contains($CommonPath)) { $LauncherRoots.Add($CommonPath) }
                        }
                    }
                }
            }
        } catch {}
    }

    # Buscar manifiestos de Epic Games
    $ProgDataForEpic = $env:ProgramData
    if ([string]::IsNullOrWhiteSpace($ProgDataForEpic)) { $ProgDataForEpic = "C:\ProgramData" }
    $EpicManifestsPath = Join-Path $ProgDataForEpic "Epic\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $EpicManifestsPath) {
        try {
            $ManifestFiles = Get-ChildItem -Path $EpicManifestsPath -Filter "*.item" -ErrorAction SilentlyContinue
            foreach ($MFile in $ManifestFiles) {
                $MContent = Get-Content -Path $MFile.FullName -Raw -ErrorAction SilentlyContinue
                if ($MContent -and $MContent -match '"InstallLocation"\s*:\s*"([^"]+)"') {
                    $InstLoc = $Matches[1] -replace '\\\\', '\'
                    if (Test-Path $InstLoc) {
                        if (!$LauncherRoots.Contains($InstLoc)) { $LauncherRoots.Add($InstLoc) }
                    }
                }
            }
        } catch {}
    }

    $DefaultRoots = @(
        (Join-Path $ProgramFiles "Steam\steamapps\common"),
        (Join-Path $ProgramFilesx86 "Steam\steamapps\common"),
        (Join-Path $ProgramFiles "Epic Games"),
        (Join-Path $ProgramFilesx86 "Battle.net"),
        (Join-Path $ProgramFiles "Overwatch"),
        (Join-Path $ProgramFiles "EA Games"),
        (Join-Path $ProgramFiles "Ubisoft")
    )
    foreach ($Root in $DefaultRoots) {
        if (!($LauncherRoots -contains $Root)) { $LauncherRoots.Add($Root })
    }

    return $LauncherRoots
}

function Get-JavaRoots {
    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    $ProgramFiles = $env:ProgramFiles
    if ([string]::IsNullOrWhiteSpace($ProgramFiles)) { $ProgramFiles = Join-Path $SysDrive "Program Files" }
    $ProgramFilesx86 = ${env:ProgramFiles(x86)}
    if ([string]::IsNullOrWhiteSpace($ProgramFilesx86)) { $ProgramFilesx86 = Join-Path $SysDrive "Program Files (x86)" }

    $JavaRoots = @(
        (Join-Path $env:USERPROFILE "curseforge\minecraft\Install"),
        (Join-Path $env:APPDATA ".minecraft"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.4297127D64ECE_8wekyb3d8bbwe\LocalCache\Local"),
        (Join-Path $env:LOCALAPPDATA "PrismLauncher"),
        (Join-Path $env:APPDATA "PrismLauncher"),
        (Join-Path $ProgramFilesx86 "Minecraft Launcher"),
        (Join-Path $ProgramFiles "Java")
    )
    return $JavaRoots
}
