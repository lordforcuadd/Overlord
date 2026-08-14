function Get-OverlordLaunchersConfig {
    if ($null -ne $global:LaunchersConfig) {
        return $global:LaunchersConfig
    }
    return [PSCustomObject]@{
        steam = [PSCustomObject]@{
            registryKeys = @(
                [PSCustomObject]@{ hive = "HKCU"; path = "Software\Valve\Steam"; value = "SteamPath" },
                [PSCustomObject]@{ hive = "HKLM"; path = "SOFTWARE\Wow6432Node\Valve\Steam"; value = "InstallPath" }
            )
            libraryFoldersRelPath = "steamapps\libraryfolders.vdf"
            commonRelPath = "steamapps\common"
            programFilesSubPath = "Steam\steamapps\common"
        }
        epic = [PSCustomObject]@{
            registryKeys = @(
                [PSCustomObject]@{ hive = "HKLM"; path = "SOFTWARE\Wow6432Node\EpicGames\Unreal Engine"; value = "INSTALLDIR" }
            )
            manifestsRelPath = "Epic\EpicGamesLauncher\Data\Manifests"
            defaultFolder = "Epic Games"
        }
        gog = [PSCustomObject]@{
            registryKeys = @("SOFTWARE\GOG.com\Games", "SOFTWARE\Wow6432Node\GOG.com\Games")
        }
        riot = [PSCustomObject]@{
            defaultFolder = "Riot Games"
            games = @("VALORANT", "League of Legends")
        }
        fixedDriveRoots = @("Riot Games", "XboxGames", "Epic Games", "Games", "SteamLibrary\steamapps\common")
        defaultProgramFilesRoots = @(
            "Steam\steamapps\common", "Epic Games", "Battle.net", "Overwatch", "EA Games", "Ubisoft"
        )
        minecraft = [PSCustomObject]@{
            userProfilePaths = @("curseforge\minecraft\Install", "curseforge\minecraft\Instances", "curseforge\minecraft", ".modrinth")
            appDataPaths = @(".minecraft", "PrismLauncher", "PrismLauncher\instances")
            localAppDataPaths = @("CurseForge", "ModrinthApp", "ModrinthApp\profiles", "Packages\Microsoft.4297127D64ECE_8wekyb3d8bbwe\LocalCache\Local", "Packages\Microsoft.4297127D64ECE_8wekyb3d8bbwe")
            javaRegistryKeys = @("SOFTWARE\JavaSoft\Java Runtime Environment", "SOFTWARE\JavaSoft\Java Development Kit", "SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment")
            javaAppPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\javaw.exe"
        }
    }
}

function Get-LauncherRoots {
    $cfg = Get-OverlordLaunchersConfig
    $LauncherRoots = [System.Collections.Generic.List[string]]::new()
    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    $ProgramFiles = $env:ProgramFiles
    if ([string]::IsNullOrWhiteSpace($ProgramFiles)) { $ProgramFiles = Join-Path $SysDrive "Program Files" }
    $ProgramFilesx86 = ${env:ProgramFiles(x86)}
    if ([string]::IsNullOrWhiteSpace($ProgramFilesx86)) { $ProgramFilesx86 = Join-Path $SysDrive "Program Files (x86)" }

    $LauncherRoots.AddRange([string[]]@(
        (Join-Path $SysDrive $cfg.riot.defaultFolder),
        (Join-Path $SysDrive "XboxGames")
    ))

    try {
        $FixedDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object { $_.Name }
        foreach ($Drive in $FixedDrives) {
            foreach ($sub in $cfg.fixedDriveRoots) {
                $P = Join-Path $Drive $sub
                if (Test-Path $P) {
                    if (!$LauncherRoots.Contains($P)) {
                        $LauncherRoots.Add($P)
                    }
                }
            }
        }
    } catch {}

    # Buscar rutas de Steam en el Registro
    $SteamPathReg = $null
    foreach ($reg in $cfg.steam.registryKeys) {
        $hivePrefix = if ($reg.hive -eq "HKLM") { "HKLM:" } else { if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" } }
        $regPath = "$hivePrefix\$($reg.path)"
        $steamProps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($null -ne $steamProps -and $null -ne $steamProps.PSObject.Properties[$reg.value]) {
            $val = $steamProps.$($reg.value)
            if (![string]::IsNullOrWhiteSpace($val)) {
                $commonP = Join-Path $val $cfg.steam.commonRelPath
                if (!$LauncherRoots.Contains($commonP)) { $LauncherRoots.Add($commonP) }
                if ($null -eq $SteamPathReg) { $SteamPathReg = $val }
            }
        }
    }

    # Buscar rutas de Epic Games en el Registro
    foreach ($reg in $cfg.epic.registryKeys) {
        $hivePrefix = if ($reg.hive -eq "HKLM") { "HKLM:" } else { if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" } }
        $regPath = "$hivePrefix\$($reg.path)"
        $epicProps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($null -ne $epicProps -and $null -ne $epicProps.PSObject.Properties[$reg.value]) {
            $val = $epicProps.$($reg.value)
            if (![string]::IsNullOrWhiteSpace($val) -and !$LauncherRoots.Contains($val)) {
                $LauncherRoots.Add($val)
            }
        }
    }

    # Buscar librerias adicionales de Steam en libraryfolders.vdf
    if ($SteamPathReg) {
        $VdfPath = Join-Path $SteamPathReg $cfg.steam.libraryFoldersRelPath
        if (Test-Path $VdfPath) {
            try {
                $VdfContent = Get-Content -Path $VdfPath -ErrorAction SilentlyContinue
                if ($VdfContent) {
                    foreach ($Line in $VdfContent) {
                        if ($Line -match '"path"\s+"([^"]+)"') {
                            $LibPath = $Matches[1] -replace '\\\\', '\'
                            $CommonPath = Join-Path $LibPath $cfg.steam.commonRelPath
                            if (Test-Path $CommonPath) {
                                if (!$LauncherRoots.Contains($CommonPath)) { $LauncherRoots.Add($CommonPath) }
                            }
                        }
                    }
                }
            } catch {}
        }
    }

    # Buscar manifiestos de Epic Games
    $ProgDataForEpic = $env:ProgramData
    if ([string]::IsNullOrWhiteSpace($ProgDataForEpic)) { $ProgDataForEpic = "C:\ProgramData" }
    $EpicManifestsPath = Join-Path $ProgDataForEpic $cfg.epic.manifestsRelPath
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

    foreach ($sub in $cfg.defaultProgramFilesRoots) {
        $P64 = Join-Path $ProgramFiles $sub
        $P32 = Join-Path $ProgramFilesx86 $sub
        if (!$LauncherRoots.Contains($P64)) { $LauncherRoots.Add($P64) }
        if (!$LauncherRoots.Contains($P32)) { $LauncherRoots.Add($P32) }
    }

    return $LauncherRoots
}

function Get-JavaRoots {
    $cfg = Get-OverlordLaunchersConfig
    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    $ProgramFiles = $env:ProgramFiles
    if ([string]::IsNullOrWhiteSpace($ProgramFiles)) { $ProgramFiles = Join-Path $SysDrive "Program Files" }
    $ProgramFilesx86 = ${env:ProgramFiles(x86)}
    if ([string]::IsNullOrWhiteSpace($ProgramFilesx86)) { $ProgramFilesx86 = Join-Path $SysDrive "Program Files (x86)" }

    $JavaRoots = [System.Collections.Generic.List[string]]::new()
    if ($env:USERPROFILE) {
        foreach ($sub in $cfg.minecraft.userProfilePaths) {
            $JavaRoots.Add((Join-Path $env:USERPROFILE $sub))
        }
    }
    if ($env:APPDATA) {
        foreach ($sub in $cfg.minecraft.appDataPaths) {
            $JavaRoots.Add((Join-Path $env:APPDATA $sub))
        }
    }
    if ($env:LOCALAPPDATA) {
        foreach ($sub in $cfg.minecraft.localAppDataPaths) {
            $JavaRoots.Add((Join-Path $env:LOCALAPPDATA $sub))
        }
    }
    $JavaRoots.Add((Join-Path $ProgramFilesx86 "Minecraft Launcher"))
    $JavaRoots.Add((Join-Path $ProgramFiles "Java"))

    # Búsqueda dinámica en el Registro
    $RegPaths = if ($cfg.minecraft.javaRegistryKeys) { $cfg.minecraft.javaRegistryKeys } else {
        @(
            "SOFTWARE\JavaSoft\Java Runtime Environment",
            "SOFTWARE\JavaSoft\Java Development Kit",
            "SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment"
        )
    }
    foreach ($RegSub in $RegPaths) {
        $RegPath = if ($RegSub -notlike "HKLM:\*") { "HKLM:\$RegSub" } else { $RegSub }
        if (Test-Path $RegPath) {
            $Versions = Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
            foreach ($Version in $Versions) {
                $VKey = "HKLM:\$Version"
                $JavaHome = Get-SafeRegistryValue -Path $VKey -Name "JavaHome"
                if (![string]::IsNullOrWhiteSpace($JavaHome) -and (Test-Path $JavaHome)) {
                    $JavaRoots.Add($JavaHome)
                }
            }
        }
    }

    $appKey = if ($cfg.minecraft.javaAppPath -like "HKLM:\*") { $cfg.minecraft.javaAppPath } else { "HKLM:\$($cfg.minecraft.javaAppPath)" }
    $AppPath = Get-SafeRegistryValue -Path $appKey -Name "Path"
    if (![string]::IsNullOrWhiteSpace($AppPath) -and (Test-Path $AppPath)) {
        $JavaRoots.Add($AppPath)
    }

    return $JavaRoots | Select-Object -Unique
}

function Get-OverlordFolderTranslationTable {
    return @{
        "LeagueClient" = "League of Legends"
        "Overwatch"    = "Overwatch"
    }
}

function Resolve-GameExePath {
    param (
        [string]$ExeName
    )
    $GameBaseName = $ExeName -replace '\.exe$',''
    $shortName = ($GameBaseName -split '-|_')[0]
    $FolderTranslationTable = Get-OverlordFolderTranslationTable
    $TranslatedName = if ($FolderTranslationTable.ContainsKey($shortName)) { $FolderTranslationTable[$shortName] } else { $null }

    $RealExePath = $null

    if ($ExeName -eq "javaw.exe") {
        $JavaPaths = Get-JavaRoots
        foreach ($Root in $JavaPaths) {
            if (Test-Path $Root) {
                $FoundFile = Find-FileFaster -Path $Root -Filter "javaw.exe" -MaxDepth 6
                if ($FoundFile) {
                    return $FoundFile.FullName
                }
            }
        }
    }

    $AppPathRegistry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ExeName"
    $RegProps = Get-ItemProperty -Path $AppPathRegistry -ErrorAction SilentlyContinue
    $RawRegistryValue = if ($RegProps) { $RegProps.'(Default)' } else { $null }

    if (![string]::IsNullOrWhiteSpace($RawRegistryValue)) {
        try {
            $CleanedPath = $RawRegistryValue -replace '^"|"$',''
            if ($CleanedPath -match '([a-zA-Z]:\\[^"]+\.exe)') {
                $CleanedPath = $Matches[1]
            }
            $ResolvedPath = [System.IO.Path]::GetFullPath($CleanedPath)
            if (Test-Path $ResolvedPath -PathType Leaf) {
                return $ResolvedPath
            }
        } catch {}
    }

    $ProgramFiles = $env:ProgramFiles
    if ([string]::IsNullOrWhiteSpace($ProgramFiles)) { $ProgramFiles = Join-Path $env:SystemDrive "Program Files" }
    $ProgramFilesx86 = ${env:ProgramFiles(x86)}
    if ([string]::IsNullOrWhiteSpace($ProgramFilesx86)) { $ProgramFilesx86 = Join-Path $env:SystemDrive "Program Files (x86)" }
    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }

    $DeepHints = [System.Collections.Generic.List[string]]::new()
    $DeepHints.AddRange([string[]]@(
        (Join-Path $ProgramFilesx86 "Overwatch\_retail_\$ExeName"),
        (Join-Path $ProgramFiles "Overwatch\_retail_\$ExeName"),
        (Join-Path $ProgramFilesx86 "Battle.net\$ExeName")
    ))
    try {
        $FixedDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object { $_.Name }
        foreach ($Drive in $FixedDrives) {
            $DeepHints.Add((Join-Path $Drive "Riot Games\$shortName\live\ShooterGame\Binaries\Win64\$ExeName"))
            $DeepHints.Add((Join-Path $Drive "Riot Games\League of Legends\$ExeName"))
            $DeepHints.Add((Join-Path $Drive "Riot Games\League of Legends\Game\$ExeName"))
        }
    } catch {
        $DeepHints.Add((Join-Path $SysDrive "Riot Games\$shortName\live\ShooterGame\Binaries\Win64\$ExeName"))
        $DeepHints.Add((Join-Path $SysDrive "Riot Games\League of Legends\$ExeName"))
    }
    foreach ($Hint in $DeepHints) {
        if (Test-Path $Hint -PathType Leaf) {
            return $Hint
        }
    }

    $LauncherRoots = Get-LauncherRoots
    foreach ($Root in $LauncherRoots) {
        if (Test-Path $Root) {
            $candidates = @()
            if ($TranslatedName) { $candidates += $TranslatedName }
            $candidates += $GameBaseName, $shortName
            
            foreach ($cand in $candidates) {
                $targetFolder = Join-Path $Root $cand
                if (Test-Path $targetFolder) {
                    $FoundFile = Find-FileFaster -Path $targetFolder -Filter $ExeName -MaxDepth 3
                    if ($FoundFile) {
                        return $FoundFile.FullName
                    }
                }
            }
        }
    }

    foreach ($Root in $LauncherRoots) {
        if (Test-Path $Root) {
            $FoundFile = Find-FileFaster -Path $Root -Filter $ExeName -MaxDepth 2
            if ($FoundFile) {
                return $FoundFile.FullName
            }
        }
    }
    
    return $null
}

