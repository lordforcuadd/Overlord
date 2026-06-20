param(
    [string]$GameList = "",
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

try {
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
    $SteamPathReg = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
    if ($SteamPathReg) { $LauncherRoots += Join-Path $SteamPathReg "steamapps\common" }
    $SteamPathReg2 = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam" -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
    if ($SteamPathReg2) { $LauncherRoots += Join-Path $SteamPathReg2 "steamapps\common" }

    # Buscar rutas de Epic Games en el Registro dinámicamente
    $EpicPathReg = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\EpicGames\Unreal Engine" -Name "INSTALLDIR" -ErrorAction SilentlyContinue).INSTALLDIR
    if ($EpicPathReg) { $LauncherRoots += $EpicPathReg }

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
                            $ini = Get-ChildItem -Path $ConfigFolder -Filter $engine.FileName -Recurse -Depth 3 -File -ErrorAction SilentlyContinue | Select-Object -First 1
                        }
                    } else {
                        $ini = Get-ChildItem -Path $ConfigFolder -Filter $engine.FileName -Recurse -Depth 3 -File -ErrorAction SilentlyContinue | Select-Object -First 1
                    }
                    if ($ini -and ($engine.Name -eq "Unreal")) {
                        if ($ini.IsReadOnly) { Set-ItemProperty -Path $ini.FullName -Name IsReadOnly -Value $false }

                        $content = Get-Content $ini.FullName
                        $newContent = [System.Collections.Generic.List[string]]::new()
                        $changed = $false
                        foreach ($line in $content) {
                            $modified = $line
                            foreach ($key in $engine.FullscreenKey) {
                                if ($line -match "^\s*$key\s*=") {
                                    $targetValue = "$key=0"
                                    if ($line.Trim() -notmatch "^\s*$key\s*=\s*0\s*$") {
                                        $modified = $targetValue
                                        $changed = $true
                                    }
                                    break
                                }
                            }
                            $newContent.Add($modified)
                        }
                        if ($changed) {
                            Set-Content -Path $ini.FullName -Value $newContent -Force
                            Write-Host "    -> Modo exclusivo forzado en $($engine.Name) ($($ini.FullName))"
                            $FullscreenForced = $true
                        } else {
                            Write-Host "    -> El archivo de configuracion ya se encontraba optimizado de forma idempotente."
                            $FullscreenForced = $true
                        }
                        break;
                    }
                }
            }

            $OldIfeo = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$ExeName"
            if (Test-Path $OldIfeo) { Remove-Item -Path $OldIfeo -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }

            $AppPathRegistry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ExeName"
            $RegProps = Get-ItemProperty -Path $AppPathRegistry -ErrorAction SilentlyContinue
            $RawRegistryValue = if ($RegProps) { $RegProps.'(Default)' } else { $null }
            $RealExePath = $null

            if (![string]::IsNullOrWhiteSpace($RawRegistryValue)) {
                $CleanedPath = $RawRegistryValue -replace '^"|"$',''
                $CleanedPath = ($CleanedPath -split '\.exe')[0] + ".exe"
                if (Test-Path $CleanedPath -PathType Leaf) {
                    $RealExePath = $CleanedPath
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
                                    $FoundFile = Get-ChildItem -Path $targetFolder -Filter $ExeName -Recurse -Depth 3 -File -ErrorAction SilentlyContinue | Select-Object -First 1
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
                                $FoundFile = Get-ChildItem -Path $Root -Filter $ExeName -Recurse -Depth 2 -File -ErrorAction SilentlyContinue | Select-Object -First 1
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
                $LayersPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
                if (!(Test-Path $LayersPath)) { New-Item -Path $LayersPath -Force | Out-Null }

                $GameBackupPath = Join-Path $BackupPath $ExeName
                if (!(Test-Path $GameBackupPath)) { New-Item -Path $GameBackupPath -Force | Out-Null }

                $ExistingLayers = (Get-ItemProperty -Path $LayersPath -Name $RealExePath -ErrorAction SilentlyContinue).$RealExePath
                $BackupRegistryCheck = Get-ItemProperty -Path $GameBackupPath -ErrorAction SilentlyContinue
                
                if ($ExistingLayers -and !$BackupRegistryCheck.PreviousLayers) {
                    Set-ItemProperty -Path $GameBackupPath -Name "PreviousLayers" -Value $ExistingLayers -Force | Out-Null
                }
                if (!$BackupRegistryCheck.Path) {
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
                $NewFlagsList.Add("HIGHDPI_SCALING_OVERRIDE_APPLICATION")
                $FinalFlagsValue = ($NewFlagsList -join " ").Trim()

                Set-ItemProperty -Path $LayersPath -Name $RealExePath -Type String -Value $FinalFlagsValue -Force | Out-Null

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
    return
} catch {
    Write-Error "[-] Error critico global en Módulo de Game Hooks: $_"
    exit 1
}