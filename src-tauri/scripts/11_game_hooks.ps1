param(
    [string]$GameList = "",
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }

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

    if ([string]::IsNullOrWhiteSpace($GameList)) {
        Write-Host "[-] No se especificaron ejecutables en GameList. Saltando optimizaciones."
        exit 0
    }

    Write-Host "[*] Aplicando Optimizaciones Graficas de Baja Latencia para juegos..."

    $BackupPath = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -Force | Out-Null }

    $Games = $GameList -split "," | ForEach-Object { $_.Trim() }

    $EngineConfigPatterns = @(
        @{
            Name = "Unreal"
            FileName = "GameUserSettings.ini"
            FullscreenKey = @("FullscreenMode", "LastConfirmedFullscreenMode", "PreferredFullscreenMode")
        }
    )

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

    # Buscar rutas de Steam en el Registro dinámicamente
    $steamProps = Get-ItemProperty -Path "$HKCU_Path\Software\Valve\Steam" -ErrorAction SilentlyContinue
    $SteamPathReg = if ($null -ne $steamProps) { $steamProps.SteamPath } else { $null }
    if ($SteamPathReg) { $LauncherRoots += Join-Path $SteamPathReg "steamapps\common" }
    $steamProps2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam" -ErrorAction SilentlyContinue
    $SteamPathReg2 = if ($null -ne $steamProps2) { $steamProps2.InstallPath } else { $null }
    if ($SteamPathReg2) { $LauncherRoots += Join-Path $SteamPathReg2 "steamapps\common" }

    # Buscar rutas de Epic Games en el Registro dinámicamente
    $epicProps = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\EpicGames\Unreal Engine" -ErrorAction SilentlyContinue
    $EpicPathReg = if ($null -ne $epicProps) { $epicProps.INSTALLDIR } else { $null }
    if ($EpicPathReg) { $LauncherRoots += $EpicPathReg }

    # Buscar librerías adicionales de Steam en libraryfolders.vdf
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

    # Buscar manifiestos de Epic Games (.item) para resolver rutas secundarias
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

    # Agregar rutas por defecto comunes de fallback
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
    $TotalJuegosProcesados = 0
    $TotalErroresFatales = 0

    foreach ($Game in $Games) {
        if ([string]::IsNullOrWhiteSpace($Game)) { continue }

        try {
            $ExeName = if ($Game -notlike "*.exe") { "$Game.exe" } else { $Game }
            $GameBaseName = $ExeName -replace '\.exe$',''
            $shortName = ($GameBaseName -split '-|_')[0]
            $FullscreenForced = $false

            Write-Host "[*] Procesando: $ExeName"

            $GameBackupPath = Join-Path $BackupPath $ExeName
            if (!(Test-Path $GameBackupPath)) { New-Item -Path $GameBackupPath -Force | Out-Null }

            $ConfigFolder = $null
            $TranslatedName = if ($FolderTranslationTable.ContainsKey($shortName)) { $FolderTranslationTable[$shortName] } else { $null }

            if ($TranslatedName -and (Test-Path (Join-Path $env:LOCALAPPDATA $TranslatedName))) {
                $ConfigFolder = Join-Path $env:LOCALAPPDATA $TranslatedName
            } elseif (Test-Path (Join-Path $env:LOCALAPPDATA $GameBaseName)) {
                $ConfigFolder = Join-Path $env:LOCALAPPDATA $GameBaseName
            } elseif (Test-Path (Join-Path $env:LOCALAPPDATA $shortName)) {
                $ConfigFolder = Join-Path $env:LOCALAPPDATA $shortName
            } else {
                $filterName = if ($TranslatedName) { $TranslatedName } else { $GameBaseName }
                $escapedFilter = [WildcardPattern]::Escape($filterName)
                $candidate = $localAppDataFolders | Where-Object { $_.Name -like "*$escapedFilter*" } | Select-Object -First 1
                if (-not $candidate) {
                    $escapedShort = [WildcardPattern]::Escape($shortName)
                    $candidate = $localAppDataFolders | Where-Object { $_.Name -like "*$escapedShort*" } | Select-Object -First 1
                }
                if ($candidate) { $ConfigFolder = $candidate.FullName }
            }

            if ($ConfigFolder) {
                foreach ($engine in $EngineConfigPatterns) {
                    $ini = $null
                    if ($engine.Name -eq "Unreal") {
                        $KnownPaths = @(
                            (Join-Path $ConfigFolder "Saved\Config\WindowsNoEditor\GameUserSettings.ini"),
                            (Join-Path $ConfigFolder "Saved\Config\Windows\GameUserSettings.ini"),
                            (Join-Path $ConfigFolder "Saved\Config\WindowsClient\GameUserSettings.ini")
                        )
                        foreach ($kp in $KnownPaths) {
                            if (Test-Path $kp) {
                                $ini = Get-Item $kp
                                break
                            }
                        }
                        if ($null -eq $ini) {
                            $ini = Find-FileFaster -Path $ConfigFolder -Filter $engine.FileName -MaxDepth 3
                        }
                    } else {
                        $ini = Find-FileFaster -Path $ConfigFolder -Filter $engine.FileName -MaxDepth 3
                    }
                    if ($ini -and ($engine.Name -eq "Unreal")) {
                        # Comprobar si el proceso del juego está activo
                        $RunningProc = Get-Process -Name $GameBaseName -ErrorAction SilentlyContinue
                        if ($null -ne $RunningProc) {
                            Write-Warning "El juego $GameBaseName esta en ejecucion. Se omitira la modificacion de GameUserSettings.ini para evitar conflictos de escritura."
                            continue
                        }

                        $content = Get-Content $ini.FullName -ErrorAction SilentlyContinue
                        if ($null -eq $content) { $content = @() }

                        $origReadOnly = $ini.IsReadOnly
                        if ($origReadOnly) { Set-ItemProperty -Path $ini.FullName -Name IsReadOnly -Value $false }

                        # Resguardar los valores originales antes de cualquier modificacion
                        foreach ($key in $engine.FullscreenKey) {
                            $foundKey = $false
                            foreach ($line in $content) {
                                if ($line -match "^\s*$key\s*=\s*(\d+)") {
                                    $origVal = $Matches[1]
                                    $gameProps = Get-ItemProperty -Path $GameBackupPath -ErrorAction SilentlyContinue
                                    if ($null -eq $gameProps -or $null -eq $gameProps.PSObject.Properties["Original_$key"]) {
                                        Set-ItemProperty -Path $GameBackupPath -Name "Original_$key" -Value $origVal -Force | Out-Null
                                    }
                                    $foundKey = $true
                                    break
                                }
                            }
                            if (-not $foundKey) {
                                # Si no existía en el archivo, guardamos _ABSENT_ para la reversión simétrica
                                $gameProps = Get-ItemProperty -Path $GameBackupPath -ErrorAction SilentlyContinue
                                if ($null -eq $gameProps -or $null -eq $gameProps.PSObject.Properties["Original_$key"]) {
                                    Set-ItemProperty -Path $GameBackupPath -Name "Original_$key" -Value "_ABSENT_" -Force | Out-Null
                                }
                            }
                        }

                        # Guardar ruta del archivo ini para reversion simetrica
                        Set-ItemProperty -Path $GameBackupPath -Name "IniPath" -Value $ini.FullName -Force | Out-Null
                        $gameProps = Get-ItemProperty -Path $GameBackupPath -ErrorAction SilentlyContinue
                        if ($null -eq $gameProps -or $null -eq $gameProps.PSObject.Properties["Original_IsReadOnly"]) {
                            Set-ItemProperty -Path $GameBackupPath -Name "Original_IsReadOnly" -Value $(if ($origReadOnly) { 1 } else { 0 }) -Force | Out-Null
                        }

                        # Construir el nuevo contenido
                        $newContent = [System.Collections.Generic.List[string]]::new()
                        $sectionHeader = "[/Script/Engine.GameUserSettings]"
                        $hasSection = $false
                        $inSection = $false
                        
                        foreach ($line in $content) {
                            if ($line -match "^\s*\[/Script/Engine\.GameUserSettings\]") {
                                $hasSection = $true
                                break
                            }
                        }

                        $keysToWrite = [System.Collections.Generic.Dictionary[string, bool]]::new()
                        foreach ($key in $engine.FullscreenKey) {
                            $keysToWrite.Add($key, $true)
                        }

                        $changed = $false

                        if (-not $hasSection) {
                            foreach ($line in $content) {
                                $newContent.Add($line)
                            }
                            $newContent.Add("")
                            $newContent.Add($sectionHeader)
                            foreach ($key in $engine.FullscreenKey) {
                                $newContent.Add("$key=0")
                            }
                            $changed = $true
                        } else {
                            foreach ($line in $content) {
                                if ($line -match "^\s*\[") {
                                    if ($inSection) {
                                        foreach ($key in $keysToWrite.Keys) {
                                            if ($keysToWrite[$key]) {
                                                $newContent.Add("$key=0")
                                                $changed = $true
                                            }
                                        }
                                        $keysToWrite = [System.Collections.Generic.Dictionary[string, bool]]::new()
                                    }
                                    if ($line -match "^\s*\[/Script/Engine\.GameUserSettings\]") {
                                        $inSection = $true
                                    } else {
                                        $inSection = $false
                                    }
                                    $newContent.Add($line)
                                    continue
                                }

                                if ($inSection) {
                                    $matchedKey = $null
                                    foreach ($key in $keysToWrite.Keys) {
                                        if ($line -match "^\s*$key\s*=") {
                                            $matchedKey = $key
                                            break
                                        }
                                    }
                                    if ($null -ne $matchedKey) {
                                        if ($line.Trim() -notmatch "^\s*$matchedKey\s*=\s*0\s*$") {
                                            $newContent.Add("$matchedKey=0")
                                            $changed = $true
                                        } else {
                                            $newContent.Add($line)
                                        }
                                        $keysToWrite.Remove($matchedKey)
                                    } else {
                                        $newContent.Add($line)
                                    }
                                } else {
                                    $newContent.Add($line)
                                }
                            }
                            if ($inSection) {
                                foreach ($key in $keysToWrite.Keys) {
                                    if ($keysToWrite[$key]) {
                                        $newContent.Add("$key=0")
                                        $changed = $true
                                    }
                                }
                            }
                        }

                        if ($changed) {
                            Set-Content -Path $ini.FullName -Value $newContent -Force
                            Write-Host "    -> Modo exclusivo forzado en $($engine.Name) ($($ini.FullName))"
                            $FullscreenForced = $true
                        } else {
                            Write-Host "    -> El archivo de configuracion ya se encontraba optimizado de forma idempotente."
                            $FullscreenForced = $true
                        }
                        if ($origReadOnly) { Set-ItemProperty -Path $ini.FullName -Name IsReadOnly -Value $true }
                        break;
                    }
                }
            }

            # Detectar Vanguard/EAC antes de modificar IFEO
            # Vanguard y EasyAntiCheat (EAC) son muy sensibles a la inyeccion en IFEO.
            # Por seguridad, solo eliminamos registros de compatibilidad antiguos y no inyectamos nuevos hooks bajo HKLM:\...\Image File Execution Options.
            $OldIfeo = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$ExeName"
            if (Test-Path $OldIfeo) { Remove-Item -Path $OldIfeo -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }

            $AppPathRegistry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ExeName"
            $RegProps = Get-ItemProperty -Path $AppPathRegistry -ErrorAction SilentlyContinue
            $RawRegistryValue = if ($RegProps) { $RegProps.'(Default)' } else { $null }
            $RealExePath = $null

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
                } catch {
                    Write-Warning "No se pudo resolver la ruta del registro para $ExeName: $_"
                }
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
                    
                    # Fallback to direct search if specific folder search fails
                    if ([string]::IsNullOrWhiteSpace($RealExePath)) {
                        foreach ($Root in $LauncherRoots) {
                            if (Test-Path $Root) {
                                $FoundFile = Find-FileFaster -Path $Root -Filter $ExeName -MaxDepth 2
                                if ($FoundFile) {
                                    $RealExePath = $FoundFile.FullName
                                    break
                                }
                            }
                        }
                    }
                }
            }

            if (![string]::IsNullOrWhiteSpace($RealExePath) -and (Test-Path $RealExePath -PathType Leaf)) {
                $LayersPath = "$HKCU_Path\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
                if (!(Test-Path $LayersPath)) { New-Item -Path $LayersPath -Force | Out-Null }



                $layersProps = Get-ItemProperty -Path $LayersPath -ErrorAction SilentlyContinue
                $ExistingLayers = if ($null -ne $layersProps -and $null -ne $layersProps.PSObject.Properties[$RealExePath]) { $layersProps.$RealExePath } else { $null }
                $BackupRegistryCheck = Get-ItemProperty -Path $GameBackupPath -ErrorAction SilentlyContinue
                
                if ($ExistingLayers -and ($null -eq $BackupRegistryCheck -or $null -eq $BackupRegistryCheck.PSObject.Properties["PreviousLayers"])) {
                    Set-ItemProperty -Path $GameBackupPath -Name "PreviousLayers" -Value $ExistingLayers -Force | Out-Null
                }
                if ($null -eq $BackupRegistryCheck -or $null -eq $BackupRegistryCheck.PSObject.Properties["Path"]) {
                    Set-ItemProperty -Path $GameBackupPath -Name "Path" -Value $RealExePath -Force | Out-Null
                }

                $NewFlagsList = [System.Collections.Generic.List[string]]::new()
                if ($ExistingLayers) {
                    $FilteredLayers = $ExistingLayers -split '\s+' | Where-Object { 
                        $_ -and 
                        $_ -ine "HIGHDPI_SCALING_OVERRIDE_APPLICATION" -and 
                        $_ -ine "~HIGHDPI_SCALING_OVERRIDE_APPLICATION"
                    }
                    if ($FilteredLayers) { $NewFlagsList.AddRange([string[]]$FilteredLayers) }
                }
                
                $DpiVal = Get-ItemPropertyValue -Path "$HKCU_Path\Control Panel\Desktop" -Name "LogPixels" -ErrorAction SilentlyContinue
                $IsDpi100 = $null -eq $DpiVal -or $DpiVal -eq 96
                if (-not $IsDpi100) {
                    $NewFlagsList.Add("HIGHDPI_SCALING_OVERRIDE_APPLICATION")
                }
                
                $FinalFlagsValue = ($NewFlagsList -join " ").Trim()

                if ($FinalFlagsValue) {
                    Set-ItemProperty -Path $LayersPath -Name $RealExePath -Type String -Value $FinalFlagsValue -Force | Out-Null
                } else {
                    Remove-ItemProperty -Path $LayersPath -Name $RealExePath -ErrorAction SilentlyContinue | Out-Null
                }

                if ($FullscreenForced) {
                    Write-Host "    -> Capas dinamicas + modo exclusivo aplicados en: $RealExePath"
                } else {
                    Write-Host "    -> Capas dinamicas aplicadas en: $RealExePath (sin modo exclusivo, motor no compatible)"
                }
                $TotalJuegosProcesados++
            } else {
                Write-Warning "No se pudo asegurar una ruta de ejecutable valida para: $ExeName"
                $TotalErroresFatales++
            }
        } catch {
            Write-Warning "[-] Error no critico procesando el objetivo $Game : $_"
            $TotalErroresFatales++
        }
    }

    if ($TotalJuegosProcesados -eq 0 -and $TotalErroresFatales -gt 0) {
        throw "El modulo de optimizacion gaming fallo: Ningun juego pudo ser procesado de forma valida."
    }

    Write-Host "[+] Protocolo de Game Hooks completado."
    exit 0
} catch {
    Write-Error "[-] Error critico global en Módulo de Game Hooks: $_"
    exit 1
}