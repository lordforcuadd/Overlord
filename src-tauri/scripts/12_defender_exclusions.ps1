param(
    [string]$GameList = "",
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }

    if ([string]::IsNullOrWhiteSpace($GameList)) {
        Write-Host "[-] No se especificaron ejecutables en GameList. Saltando exclusiones de Defender."
        exit 0
    }

    Write-Host "[*] Aplicando exclusiones en Windows Defender..."

    # Reutilizar el buscador rápido de 11_game_hooks.ps1
    function Find-FileFaster {
        param(
            [string]$Path,
            [string]$Filter,
            [int]$MaxDepth = 3
        )
        if (!(Test-Path $Path)) { return $null }
        try {
            $files = [System.IO.Directory]::GetFiles($Path, $Filter)
            if ($files.Count -gt 0) {
                return [System.IO.FileInfo]::new($files[0])
            }
        } catch {}
        if ($MaxDepth -le 0) { return $null }
        try {
            $subdirs = [System.IO.Directory]::GetDirectories($Path)
            foreach ($dir in $subdirs) {
                $found = Find-FileFaster -Path $dir -Filter $Filter -MaxDepth ($MaxDepth - 1)
                if ($found) { return $found }
            }
        } catch {}
        return $null
    }

    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    $ProgramFiles = $env:ProgramFiles
    if ([string]::IsNullOrWhiteSpace($ProgramFiles)) { $ProgramFiles = Join-Path $SysDrive "Program Files" }
    $ProgramFilesx86 = ${env:ProgramFiles(x86)}
    if ([string]::IsNullOrWhiteSpace($ProgramFilesx86)) { $ProgramFilesx86 = Join-Path $SysDrive "Program Files (x86)" }

    $Games = $GameList -split "," | ForEach-Object { $_.Trim() }

    $LauncherRoots = [System.Collections.Generic.List[string]]::new()
    $LauncherRoots.AddRange([string[]]@(
        (Join-Path $SysDrive "Riot Games"),
        (Join-Path $SysDrive "XboxGames"),
        "D:\Games",
        "E:\Games"
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

    $steamProps = Get-ItemProperty -Path "$HKCU_Path\Software\Valve\Steam" -ErrorAction SilentlyContinue
    $SteamPathReg = if ($null -ne $steamProps) { $steamProps.SteamPath } else { $null }
    if ($SteamPathReg) { $LauncherRoots += Join-Path $SteamPathReg "steamapps\common" }
    $steamProps2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam" -ErrorAction SilentlyContinue
    $SteamPathReg2 = if ($null -ne $steamProps2) { $steamProps2.InstallPath } else { $null }
    if ($SteamPathReg2) { $LauncherRoots += Join-Path $SteamPathReg2 "steamapps\common" }

    $epicProps = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\EpicGames\Unreal Engine" -ErrorAction SilentlyContinue
    $EpicPathReg = if ($null -ne $epicProps) { $epicProps.INSTALLDIR } else { $null }
    if ($EpicPathReg) { $LauncherRoots += $EpicPathReg }

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
        (Join-Path $ProgramFiles "Ubisoft"),
        "D:\SteamLibrary\steamapps\common"
    )
    foreach ($Root in $DefaultRoots) {
        if (!($LauncherRoots -contains $Root)) { $LauncherRoots += $Root }
    }

    $FolderTranslationTable = @{
        "LeagueClient" = "League of Legends"
        "Overwatch"    = "Overwatch"
    }

    $localAppDataFolders = Get-ChildItem -Path $env:LOCALAPPDATA -Directory -ErrorAction SilentlyContinue
    $ExcludedPaths = [System.Collections.Generic.List[string]]::new()

    foreach ($Game in $Games) {
        if ([string]::IsNullOrWhiteSpace($Game)) { continue }
        
        $RealExePath = $null
        # Intentar obtener ruta previamente resuelta en backup de GameHooks por consistencia total
        $ExeName = if ($Game -notlike "*.exe") { "$Game.exe" } else { $Game }
        $GameBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks\$ExeName"
        if (Test-Path $GameBackupPath) {
            $RegPath = Get-ItemPropertyValue -Path $GameBackupPath -Name "Path" -ErrorAction SilentlyContinue
            if ($RegPath -and (Test-Path $RegPath -PathType Leaf)) {
                $RealExePath = $RegPath
            }
        }

        # Si no existía backup de GameHooks, resolver la ruta con la misma lógica
        if ([string]::IsNullOrWhiteSpace($RealExePath)) {
            $GameBaseName = $ExeName -replace '\.exe$',''
            $shortName = ($GameBaseName -split '-|_')[0]
            $TranslatedName = if ($FolderTranslationTable.ContainsKey($shortName)) { $FolderTranslationTable[$shortName] } else { $null }

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
                        $RealExePath = $ResolvedPath
                    }
                } catch {}
            }

            if ([string]::IsNullOrWhiteSpace($RealExePath)) {
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
                        $RealExePath = $Hint
                        break
                    }
                }
            }

            if ([string]::IsNullOrWhiteSpace($RealExePath)) {
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
                                    $RealExePath = $FoundFile.FullName
                                    break
                                }
                            }
                        }
                        if (![string]::IsNullOrWhiteSpace($RealExePath)) { break }
                    }
                }
            }
        }

        if (![string]::IsNullOrWhiteSpace($RealExePath) -and (Test-Path $RealExePath -PathType Leaf)) {
            $GameDir = Split-Path $RealExePath -Parent
            if (![string]::IsNullOrWhiteSpace($GameDir) -and (Test-Path $GameDir -PathType Container)) {
                $ResolvedDir = [System.IO.Path]::GetFullPath($GameDir).TrimEnd('\')
                if (!$ExcludedPaths.Contains($ResolvedDir)) {
                    $ExcludedPaths.Add($ResolvedDir)
                }
            }
        }
    }

    if ($ExcludedPaths.Count -eq 0) {
        Write-Host "[-] No se detecto ninguna carpeta de juego valida para excluir de Windows Defender."
        exit 0
    }

    # Mecanismo de Respaldo Quirúrgico: registrar qué rutas fueron agregadas por Overlord
    $BackupKey = "HKLM:\SOFTWARE\Overlord\Backup\DefenderExclusions"
    if (!(Test-Path $BackupKey)) { New-Item -Path $BackupKey -Force | Out-Null }
    
    # Cargar rutas previamente excluidas por Overlord para no sobreescribir si ya existían
    $PrevPaths = @()
    $BackupProps = Get-ItemProperty -Path $BackupKey -ErrorAction SilentlyContinue
    if ($null -ne $BackupProps -and $null -ne $BackupProps.PSObject.Properties["AddedExclusions"]) {
        $PrevPaths = $BackupProps.AddedExclusions -split ";" | Where-Object { $_ -ne "" }
    }

    # Obtener exclusiones actuales de Windows Defender de forma nativa
    $CurrentExclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath -ErrorAction SilentlyContinue
    $CurrentExclusionsList = [System.Collections.Generic.List[string]]::new()
    if ($CurrentExclusions) {
        foreach ($Path in $CurrentExclusions) {
            $CurrentExclusionsList.Add([System.IO.Path]::GetFullPath($Path).TrimEnd('\').ToLower())
        }
    }

    $NewAddedPaths = [System.Collections.Generic.List[string]]::new($PrevPaths)
    
    foreach ($Dir in $ExcludedPaths) {
        $DirLower = $Dir.ToLower()
        # Solo agregar a Windows Defender si no está ya en las exclusiones globales de Defender
        if (-not $CurrentExclusionsList.Contains($DirLower)) {
            Add-MpPreference -ExclusionPath $Dir -ErrorAction SilentlyContinue
            Write-Host "    [+] Ruta excluida en Windows Defender: $Dir"
            
            # Registrar en nuestro backup que Overlord gestiona esta exclusión
            if (-not $NewAddedPaths.Contains($Dir)) {
                $NewAddedPaths.Add($Dir)
            }
        } else {
            Write-Host "    [*] La ruta ya estaba excluida en Windows Defender: $Dir"
        }
    }

    # Guardar la lista persistente en el registro
    $Serialized = $NewAddedPaths -join ";"
    Set-ItemProperty -Path $BackupKey -Name "AddedExclusions" -Value $Serialized -Force | Out-Null

    exit 0
} catch {
    Write-Error "[-] Error critico al aplicar exclusiones de Windows Defender: $_"
    exit 1
}
