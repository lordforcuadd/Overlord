param(
    [string]$GameList = "",
    [bool]$IsLaptop = $false,
    [int]$RamGB = 8
)
$ErrorActionPreference = "Stop"

try {
    $HKCU_Path = if (Get-Variable -Name "HKCU_Path" -Scope "global" -ErrorAction SilentlyContinue) { $global:HKCU_Path } else { "HKCU:" }



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

    $Games = $GameList -split "," | ForEach-Object { $_.Trim().ToLower() }

    $EngineConfigPatterns = @(
        @{
            Name = "Unreal"
            FileName = "GameUserSettings.ini"
            FullscreenKey = @("FullscreenMode", "LastConfirmedFullscreenMode", "PreferredFullscreenMode")
        }
    )

    $LauncherRoots = Get-LauncherRoots

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
                        # Comprobar si el proceso del juego esta activo
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
                                # Si no existia en el archivo, guardamos _ABSENT_ para la reversion simetrica
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
                        # Construir el nuevo contenido (Refactorizado sin boolean-spaghetti)
                        $iniText = $content -join "`r`n"
                        $sectionHeader = "[/Script/Engine.GameUserSettings]"
                        $changed = $false

                        if ($iniText -notmatch "\[/Script/Engine\.GameUserSettings\]") {
                            $iniText += "`r`n`r`n$sectionHeader`r`n"
                            foreach ($key in $engine.FullscreenKey) {
                                $iniText += "$key=0`r`n"
                            }
                            $changed = $true
                        } else {
                            # Extraer la seccion objetivo
                            $pattern = "(?s)(\[/Script/Engine\.GameUserSettings\]\r?\n)(.*?)(?=\r?\n\[|$)"
                            if ($iniText -match $pattern) {
                                $sectionHead = $Matches[1]
                                $sectionBody = $Matches[2]
                                
                                foreach ($key in $engine.FullscreenKey) {
                                    if ($sectionBody -match "(?m)^\s*$key\s*=.*$") {
                                        # Si existe, reemplazar el valor si no es 0
                                        if ($sectionBody -notmatch "(?m)^\s*$key\s*=\s*0\s*$") {
                                            $sectionBody = $sectionBody -replace "(?m)^(\s*$key\s*=).*$", "`$10"
                                            $changed = $true
                                        }
                                    } else {
                                        # Si no existe, agregarlo al final de la seccion
                                        $sectionBody += "`r`n$key=0"
                                        $changed = $true
                                    }
                                }
                                
                                if ($changed) {
                                    # Limpiar posibles saltos de linea multiples
                                    $sectionBody = $sectionBody -replace "\r?\n{3,}", "`r`n`r`n"
                                    $iniText = $iniText -replace $pattern, "$sectionHead$sectionBody"
                                }
                            }
                        }
                        
                        $newContent = $iniText -split "`r`n"

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
            $IfeoBackup = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks\$ExeName\IFEORegacy"
            if (Test-Path $OldIfeo) {
                if (!(Test-Path (Split-Path $IfeoBackup -Parent))) {
                    New-Item -Path (Split-Path $IfeoBackup -Parent) -Force | Out-Null
                }
                Copy-Item -Path $OldIfeo -Destination $IfeoBackup -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                $PropsToRemove = @("CpuPriorityClass", "IoPriority", "PagePriorityClass")
                foreach ($Prop in $PropsToRemove) {
                    Remove-ItemProperty -Path $OldIfeo -Name $Prop -Force -ErrorAction SilentlyContinue | Out-Null
                }
                if (Test-Path "$OldIfeo\PerfOptions") {
                    Remove-Item -Path "$OldIfeo\PerfOptions" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                }
            } else {
                # Guardar marcador de ausente para saber que no existia originalmente
                if (!(Test-Path (Split-Path $IfeoBackup -Parent))) {
                    New-Item -Path (Split-Path $IfeoBackup -Parent) -Force | Out-Null
                }
                $null = New-Item -Path $IfeoBackup -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $IfeoBackup -Name "Status" -Value "_ABSENT_" -Force -ErrorAction SilentlyContinue | Out-Null
            }

            $RealExePath = Resolve-GameExePath -ExeName $ExeName

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
                    $chkFlags = Get-ItemPropertyValue -Path $LayersPath -Name $RealExePath -ErrorAction SilentlyContinue
                    if ($null -eq $chkFlags -or $chkFlags.ToString() -ne $FinalFlagsValue) { throw "Bloqueado al escribir AppCompatFlags para $RealExePath" }
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
    Write-Error "[-] Error critico global en Modulo de Game Hooks: $_"
    exit 1
}
