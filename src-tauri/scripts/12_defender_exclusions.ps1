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

    # Reutilizar el buscador rÃ¡pido de 11_game_hooks.ps1


    $SysDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($SysDrive)) { $SysDrive = "C:" }
    $ProgramFiles = $env:ProgramFiles
    if ([string]::IsNullOrWhiteSpace($ProgramFiles)) { $ProgramFiles = Join-Path $SysDrive "Program Files" }
    $ProgramFilesx86 = ${env:ProgramFiles(x86)}
    if ([string]::IsNullOrWhiteSpace($ProgramFilesx86)) { $ProgramFilesx86 = Join-Path $SysDrive "Program Files (x86)" }

    $Games = $GameList -split "," | ForEach-Object { $_.Trim() }
    $LauncherRoots = Get-LauncherRoots

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

        if ($ExeName -eq "javaw.exe") {
            # BÃºsqueda dedicada para Java Runtime de Minecraft / CurseForge / Prism / TLauncher
            $JavaPaths = Get-JavaRoots
            foreach ($Root in $JavaPaths) {
                if (Test-Path $Root) {
                    $FoundFile = Find-FileFaster -Path $Root -Filter "javaw.exe" -MaxDepth 6
                    if ($FoundFile) {
                        $RealExePath = $FoundFile.FullName
                        break
                    }
                }
            }

            # Agregar exclusiÃ³n de la carpeta de instancias de Minecraft por seguridad/latencia
            $InstancePaths = @(
                (Join-Path $env:USERPROFILE "curseforge\minecraft\Instances"),
                (Join-Path $env:APPDATA ".minecraft"),
                (Join-Path $env:LOCALAPPDATA "PrismLauncher\instances"),
                (Join-Path $env:APPDATA "PrismLauncher\instances"),
                (Join-Path $env:LOCALAPPDATA "ModrinthApp\profiles")
            )
            foreach ($InstPath in $InstancePaths) {
                if (Test-Path $InstPath) {
                    $ResolvedInst = [System.IO.Path]::GetFullPath($InstPath).TrimEnd('\')
                    if (!$ExcludedPaths.Contains($ResolvedInst)) {
                        $ExcludedPaths.Add($ResolvedInst)
                    }
                }
            }
        }

        $GameBackupPath = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks\$ExeName"
        if (Test-Path $GameBackupPath) {
            $RegPath = Get-ItemPropertyValue -Path $GameBackupPath -Name "Path" -ErrorAction SilentlyContinue
            if ($RegPath -and (Test-Path $RegPath -PathType Leaf)) {
                $RealExePath = $RegPath
            }
        }

        # Si no existÃ­a backup de GameHooks, resolver la ruta con la misma lÃ³gica
        if ([string]::IsNullOrWhiteSpace($RealExePath)) {
            $GameBaseName = $ExeName -replace '\.exe$',''
            $shortName = ($GameBaseName -split '-|_')[0]
            $TranslatedName = if ($FolderTranslationTable.ContainsKey($shortName)) { $FolderTranslationTable[$shortName] } else { $null }

            $RealExePath = Resolve-GameExePath -ExeName $ExeName
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

    # Mecanismo de Respaldo QuirÃºrgico: registrar quÃ© rutas fueron agregadas por Overlord
    $BackupKey = "HKLM:\SOFTWARE\Overlord\Backup\DefenderExclusions"
    if (!(Test-Path $BackupKey)) { New-Item -Path $BackupKey -Force | Out-Null }
    
    # Cargar rutas previamente excluidas por Overlord para no sobreescribir si ya existÃ­an
    $PrevPaths = @()
    $BackupProps = Get-ItemProperty -Path $BackupKey -ErrorAction SilentlyContinue
    if ($null -ne $BackupProps -and $null -ne $BackupProps.PSObject.Properties["AddedExclusions"]) {
        $PrevPaths = $BackupProps.AddedExclusions -split ";" | Where-Object { $_ -ne "" }
    }

    # Obtener exclusiones actuales de Windows Defender de forma nativa
    if (-not (Get-Command Get-MpPreference -ErrorAction SilentlyContinue)) {
        Write-Warning "Get-MpPreference no esta disponible en este sistema."
        exit 0
    }
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
        # Solo agregar a Windows Defender si no estÃ¡ ya en las exclusiones globales de Defender
        if (-not $CurrentExclusionsList.Contains($DirLower)) {
            try {
                Add-MpPreference -ExclusionPath $Dir -ErrorAction Stop
                Write-Host "    [+] Ruta excluida en Windows Defender: $Dir"
                
                # Registrar en nuestro backup que Overlord gestiona esta exclusión
                if (-not $NewAddedPaths.Contains($Dir)) {
                    $NewAddedPaths.Add($Dir)
                }
            } catch {
                throw "Defender bloqueó la adición de la exclusión para ${Dir}: $_"
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
