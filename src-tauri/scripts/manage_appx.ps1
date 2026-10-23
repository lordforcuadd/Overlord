# Script de Gestion y Remocion Curada de Paquetes AppX Bloatware - Overlord
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GameListVal = if (Get-Variable -Name "GameList" -Scope "global" -ErrorAction SilentlyContinue) { $global:GameList } elseif (Get-Variable -Name "GameList" -Scope "local" -ErrorAction SilentlyContinue) { $GameList } else { $null }
$ActionIdVal = if (Get-Variable -Name "ActionId" -Scope "global" -ErrorAction SilentlyContinue) { $global:ActionId } elseif (Get-Variable -Name "ActionId" -Scope "local" -ErrorAction SilentlyContinue) { $ActionId } else { $null }
$Action = if (![string]::IsNullOrWhiteSpace($GameListVal)) { $GameListVal } elseif (![string]::IsNullOrWhiteSpace($ActionIdVal)) { $ActionIdVal } else { "list" }

$Catalog = @(
    # SEGUROS (SAFE): Bloatware publicitario, promocional y apps prescindibles
    @{ Id = "Microsoft.BingNews"; Name = "Microsoft Noticias"; Category = "safe"; Description = "Feed de noticias de MSN y Bing" },
    @{ Id = "Microsoft.BingWeather"; Name = "El Tiempo"; Category = "safe"; Description = "Pronostico del clima MSN" },
    @{ Id = "Microsoft.BingFinance"; Name = "MSN Dinero"; Category = "safe"; Description = "Cotizaciones financieras y noticias de mercado" },
    @{ Id = "Microsoft.BingSports"; Name = "MSN Deportes"; Category = "safe"; Description = "Resultados y noticias deportivas" },
    @{ Id = "Microsoft.BingSearch"; Name = "Busqueda Bing"; Category = "safe"; Description = "Integracion de busqueda web Bing" },
    @{ Id = "Microsoft.GetHelp"; Name = "Obtener Ayuda"; Category = "safe"; Description = "Asistente basico de soporte tecnico" },
    @{ Id = "Microsoft.Getstarted"; Name = "Sugerencias y Consejos"; Category = "safe"; Description = "Consejos promocionales de Windows" },
    @{ Id = "Microsoft.Messaging"; Name = "Mensajes"; Category = "safe"; Description = "Servicio heredado de mensajeria SMS/MMS" },
    @{ Id = "Microsoft.3DBuilder"; Name = "3D Builder"; Category = "safe"; Description = "Modelado e impresion 3D basico" },
    @{ Id = "Microsoft.Microsoft3DViewer"; Name = "Visor 3D"; Category = "safe"; Description = "Visor de modelos 3D y realidad aumentada" },
    @{ Id = "Microsoft.Print3D"; Name = "Print 3D"; Category = "safe"; Description = "Herramienta de envio a impresion 3D" },
    @{ Id = "Microsoft.People"; Name = "Contactos (People)"; Category = "safe"; Description = "Libreta de contactos y sincronizacion social" },
    @{ Id = "Microsoft.SkypeApp"; Name = "Skype"; Category = "safe"; Description = "Cliente UWP de mensajeria y videollamadas" },
    @{ Id = "Microsoft.Wallet"; Name = "Microsoft Pay / Cartera"; Category = "safe"; Description = "Pasarela de pagos en aplicaciones UWP" },
    @{ Id = "Microsoft.MixedReality.Portal"; Name = "Portal Realidad Mixta"; Category = "safe"; Description = "Entorno VR de Windows Mixed Reality" },
    @{ Id = "Microsoft.549981C3F5F10"; Name = "Cortana"; Category = "safe"; Description = "Asistente virtual discontinuado" },
    @{ Id = "Microsoft.Windows.Ai.Copilot.Provider"; Name = "Proveedor Copilot"; Category = "safe"; Description = "Componente de integracion de Copilot" },
    @{ Id = "Clipchamp.Clipchamp"; Name = "Clipchamp"; Category = "safe"; Description = "Editor de video en la nube" },
    @{ Id = "Microsoft.MicrosoftSolitaireCollection"; Name = "Solitario"; Category = "safe"; Description = "Coleccion de juegos Solitaire con publicidad" },
    @{ Id = "Microsoft.MicrosoftMahjong"; Name = "Mahjong"; Category = "safe"; Description = "Juego Mahjong casual con anuncios" },
    @{ Id = "Microsoft.PowerAutomateDesktop"; Name = "Power Automate"; Category = "safe"; Description = "Automatizacion RPA empresarial" },
    @{ Id = "Microsoft.WindowsFeedbackHub"; Name = "Centro de Comentarios"; Category = "safe"; Description = "Envio de telemetria y opiniones a Microsoft" },
    @{ Id = "Microsoft.WindowsMaps"; Name = "Mapas de Windows"; Category = "safe"; Description = "Mapas basados en Bing Maps" },
    @{ Id = "Microsoft.Todos"; Name = "Microsoft To Do"; Category = "safe"; Description = "Gestor de tareas y recordatorios" },

    # CUIDADO (CAUTION): Apps que algunos usuarios utilizan cotidianamente
    @{ Id = "Microsoft.YourPhone"; Name = "Enlace Movil"; Category = "caution"; Description = "Sincronizacion de telefono movil con Windows" },
    @{ Id = "Microsoft.ZuneVideo"; Name = "Peliculas y TV"; Category = "caution"; Description = "Reproductor de video tradicional de Windows" },
    @{ Id = "Microsoft.ZuneMusic"; Name = "Reproductor Multimedia"; Category = "caution"; Description = "Reproductor de audio y musica (Media Player)" },
    @{ Id = "Microsoft.MicrosoftStickyNotes"; Name = "Notas Rapidas"; Category = "caution"; Description = "Notas rapidas de escritorio (Sticky Notes)" },
    @{ Id = "Microsoft.WindowsSoundRecorder"; Name = "Grabadora de Sonido"; Category = "caution"; Description = "Grabadora de voz de Windows" },
    @{ Id = "Microsoft.XboxApp"; Name = "Aplicacion Xbox"; Category = "caution"; Description = "Cliente de Xbox PC y Game Pass" },
    @{ Id = "Microsoft.XboxGamingOverlay"; Name = "Barra de Juegos Xbox"; Category = "caution"; Description = "Game Bar (superposicion Win+G para capturas)" },
    @{ Id = "Microsoft.XboxIdentityProvider"; Name = "Identidad Xbox"; Category = "caution"; Description = "Autenticacion para juegos de Xbox Live" },
    @{ Id = "Microsoft.XboxSpeechToTextOverlay"; Name = "Xbox Texto a Voz"; Category = "caution"; Description = "Accesibilidad en juegos de Xbox" },

    # PROTEGIDOS (SYSTEM): Componentes esenciales que NUNCA deben removerse
    @{ Id = "Microsoft.WindowsStore"; Name = "Microsoft Store"; Category = "system"; Description = "Tienda oficial de aplicaciones de Windows" },
    @{ Id = "Microsoft.DesktopAppInstaller"; Name = "Instalador de Paquetes"; Category = "system"; Description = "Motor WinGet y manejador AppX/MSIX" },
    @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal"; Category = "system"; Description = "Consola moderna de comandos del sistema" },
    @{ Id = "Microsoft.WindowsCalculator"; Name = "Calculadora"; Category = "system"; Description = "Calculadora basica y cientifica de Windows" },
    @{ Id = "Microsoft.WindowsCamera"; Name = "Camara"; Category = "system"; Description = "Camara integrada del sistema" },
    @{ Id = "Microsoft.Paint"; Name = "Paint"; Category = "system"; Description = "Editor grafico nativo de Windows" },
    @{ Id = "Microsoft.WindowsNotepad"; Name = "Bloc de Notas"; Category = "system"; Description = "Editor de texto basico del sistema" },
    @{ Id = "Microsoft.SecHealthUI"; Name = "Seguridad de Windows"; Category = "system"; Description = "Centro de seguridad y Windows Defender" }
)

$ProtectedIds = @(
    "Microsoft.WindowsStore",
    "Microsoft.DesktopAppInstaller",
    "Microsoft.WindowsTerminal",
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsCamera",
    "Microsoft.Paint",
    "Microsoft.WindowsNotepad",
    "Microsoft.SecHealthUI"
)

$BackupBase = "HKLM:\SOFTWARE\Overlord\Backup\Debloat\Appx"

function Get-InstalledAppxData {
    $InstalledPackages = try {
        Get-AppxPackage -AllUsers -ErrorAction Stop
    } catch {
        Get-AppxPackage -ErrorAction SilentlyContinue
    }
    $InstalledMap = @{}
    if ($null -ne $InstalledPackages) {
        foreach ($pkg in $InstalledPackages) {
            $InstalledMap[$pkg.Name] = $pkg
        }
    }

    $ProvisionedPackages = try {
        Get-AppxProvisionedPackage -Online -ErrorAction Stop
    } catch {
        @()
    }
    $ProvisionedMap = @{}
    if ($null -ne $ProvisionedPackages) {
        foreach ($prov in $ProvisionedPackages) {
            $ProvisionedMap[$prov.DisplayName] = $prov
        }
    }

    $Result = @()
    foreach ($entry in $Catalog) {
        $id = $entry.Id
        $isInstalled = $InstalledMap.ContainsKey($id)
        $isProvisioned = $ProvisionedMap.ContainsKey($id)

        $pkgObj = if ($isInstalled) { $InstalledMap[$id] } else { $null }
        $version = if ($null -ne $pkgObj) { $pkgObj.Version } else { "" }
        $pkgFullName = if ($null -ne $pkgObj) { $pkgObj.PackageFullName } else { "" }
        $installLocation = if ($null -ne $pkgObj) { $pkgObj.InstallLocation } else { "" }

        $isBackedUp = $false
        $backupKey = Join-Path $BackupBase $id
        if (Test-Path $backupKey) {
            $isBackedUp = $true
        }

        $Result += [PSCustomObject]@{
            id = $id
            name = $entry.Name
            category = $entry.Category
            description = $entry.Description
            installed = $isInstalled
            provisioned = $isProvisioned
            backedUp = $isBackedUp
            version = $version
            packageFullName = $pkgFullName
            installLocation = $installLocation
        }
    }

    return $Result
}

Try {
    if ($Action -eq "list" -or $Action.StartsWith("list:")) {
        $data = Get-InstalledAppxData
        $json = $data | ConvertTo-Json -Compress
        Write-Output $json
        exit 0
    }

    if ($Action.StartsWith("remove:")) {
        $targets = $Action.Substring(7).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { !([string]::IsNullOrWhiteSpace($_)) }
        if (!(Test-Path $BackupBase)) {
            New-Item -Path $BackupBase -Force | Out-Null
        }

        $AllProvisioned = try { Get-AppxProvisionedPackage -Online -ErrorAction Stop } catch { @() }
        $removed = @()
        $failed = @()

        foreach ($target in $targets) {
            if ($ProtectedIds -contains $target) {
                Write-Warning "El paquete $target es critico del sistema y esta protegido contra remocion."
                continue
            }

            $pkg = Get-AppxPackage -Name $target -AllUsers -ErrorAction SilentlyContinue
            if ($null -ne $pkg) {
                $targetBackup = Join-Path $BackupBase $target
                if (!(Test-Path $targetBackup)) {
                    New-Item -Path $targetBackup -Force | Out-Null
                }

                $manifestPath = if (![string]::IsNullOrWhiteSpace($pkg.InstallLocation)) {
                    Join-Path $pkg.InstallLocation "AppXManifest.xml"
                } else {
                    ""
                }

                Set-ItemProperty -Path $targetBackup -Name "PackageFullName" -Value $pkg.PackageFullName -Force -ErrorAction SilentlyContinue | Out-Null
                Set-ItemProperty -Path $targetBackup -Name "InstallLocation" -Value $pkg.InstallLocation -Force -ErrorAction SilentlyContinue | Out-Null
                Set-ItemProperty -Path $targetBackup -Name "ManifestPath" -Value $manifestPath -Force -ErrorAction SilentlyContinue | Out-Null
                Set-ItemProperty -Path $targetBackup -Name "Timestamp" -Value (Get-Date -Format "o") -Force -ErrorAction SilentlyContinue | Out-Null

                try {
                    Get-AppxPackage -Name $target -AllUsers -ErrorAction Stop | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    if ($null -ne $AllProvisioned) {
                        $AllProvisioned | Where-Object { $_.DisplayName -eq $target -or $_.PackageName -match $target } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
                    }
                    $removed += $target
                } catch {
                    Write-Warning "Fallo al remover ${target}: $_"
                    $failed += $target
                }
            } else {
                # Ya no estaba instalado como paquete de usuario, intentar desprovisionar si existia
                if ($null -ne $AllProvisioned) {
                    $AllProvisioned | Where-Object { $_.DisplayName -eq $target -or $_.PackageName -match $target } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
                }
                $removed += $target
            }
        }

        $resObj = [PSCustomObject]@{
            success = $true
            action = "remove"
            removed = $removed
            failed = $failed
        }
        Write-Output ($resObj | ConvertTo-Json -Compress)
        exit 0
    }

    if ($Action.StartsWith("restore:")) {
        $targets = $Action.Substring(8).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { !([string]::IsNullOrWhiteSpace($_)) }
        $restored = @()
        $failed = @()
        $WindowsAppsPath = Join-Path $env:ProgramFiles "WindowsApps"

        if ($targets.Count -eq 1 -and $targets[0] -eq "all") {
            if (Test-Path $BackupBase) {
                $targets = Get-ChildItem -Path $BackupBase | Select-Object -ExpandProperty Name
            } else {
                $targets = @()
            }
        }

        foreach ($target in $targets) {
            $targetBackup = Join-Path $BackupBase $target
            $manifestFound = $null

            if (Test-Path $targetBackup) {
                $savedManifest = (Get-ItemProperty -Path $targetBackup -Name "ManifestPath" -ErrorAction SilentlyContinue).ManifestPath
                if (![string]::IsNullOrWhiteSpace($savedManifest) -and (Test-Path $savedManifest)) {
                    $manifestFound = $savedManifest
                }
            }

            if ([string]::IsNullOrWhiteSpace($manifestFound) -and (Test-Path $WindowsAppsPath)) {
                $dirs = Get-ChildItem -Path $WindowsAppsPath -Directory -Filter "$target*" -ErrorAction SilentlyContinue
                foreach ($d in $dirs) {
                    $mPath = Join-Path $d.FullName "AppXManifest.xml"
                    if (Test-Path $mPath) {
                        $manifestFound = $mPath
                        break
                    }
                }
            }

            if (![string]::IsNullOrWhiteSpace($manifestFound)) {
                try {
                    Add-AppxPackage -DisableDevelopmentMode -Register $manifestFound -ErrorAction Stop | Out-Null
                    $restored += $target
                    if (Test-Path $targetBackup) {
                        Remove-Item -Path $targetBackup -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                } catch {
                    Write-Warning "Fallo al restaurar ${target} con manifiesto ${manifestFound}: $_"
                    $failed += $target
                }
            } else {
                Write-Warning "No se encontro manifiesto valido para restaurar $target"
                $failed += $target
            }
        }

        $resObj = [PSCustomObject]@{
            success = $true
            action = "restore"
            restored = $restored
            failed = $failed
        }
        Write-Output ($resObj | ConvertTo-Json -Compress)
        exit 0
    }

    throw "Accion no soportada en manage_appx: '$Action'"
} Catch {
    Write-Error "[-] Error critico en manage_appx.ps1: $_"
    exit 1
}
