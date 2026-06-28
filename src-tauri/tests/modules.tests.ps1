$ScriptsDir = $null
$ManifestPath = $null

if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne "") {
    $ScriptsDir = Join-Path $PSScriptRoot "..\scripts"
    $ManifestPath = Join-Path $PSScriptRoot "..\Cargo.toml"
} elseif ($null -ne $MyInvocation -and $null -ne $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path -ne "") {
    $Parent = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ScriptsDir = Join-Path $Parent "..\scripts"
    $ManifestPath = Join-Path $Parent "..\Cargo.toml"
} elseif (Test-Path "src-tauri/scripts") {
    $ScriptsDir = (Get-Item "src-tauri/scripts").FullName
    $ManifestPath = (Get-Item "src-tauri/Cargo.toml").FullName
} elseif (Test-Path "scripts") {
    $ScriptsDir = (Get-Item "scripts").FullName
    $ManifestPath = (Get-Item "Cargo.toml").FullName
} else {
    $ScriptsDir = "..\scripts"
    $ManifestPath = "..\Cargo.toml"
}

Write-Host "--- DEBUG PATH INFO ---"
Write-Host "PSScriptRoot: '$PSScriptRoot'"
Write-Host "CWD: '$(Get-Location)'"
Write-Host "MyInvocation Path: '$($MyInvocation.MyCommand.Path)'"
Write-Host "Test-Path src-tauri/scripts: '$(Test-Path src-tauri/scripts)'"
Write-Host "ScriptsDir: '$ScriptsDir'"
Write-Host "ManifestPath: '$ManifestPath'"
Write-Host "------------------------"

$Version = "Unknown"
if (Test-Path $ManifestPath) {
    $Manifest = Get-Content -Path $ManifestPath -Raw
    if ($Manifest -match 'version\s*=\s*"([^"]+)"') {
        $Version = $Matches[1]
    }
}
$global:OverlordScriptsPath = $ScriptsDir

Describe "Suite de Verificacion de Integridad Mecanica - Overlord v$Version" {
    BeforeAll {
        Write-Host "--- BEFOREALL DEBUG ---"
        Write-Host "BeforeAll global path: '$($global:OverlordScriptsPath)'"
        Write-Host "------------------------"
        $GlobalBackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
        $ControlFileSystem = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        $MemoryManagerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        $ScriptsPath = $global:OverlordScriptsPath
        $GetQolPath = Join-Path $ScriptsPath "get_qol.ps1"
        $SetQolPath = Join-Path $ScriptsPath "set_qol.ps1"
        $RevertPath = Join-Path $ScriptsPath "10_revertir.ps1"
        $BackupModulePath = Join-Path $ScriptsPath "backup_manager.psm1"
    }

    Context "Auditoria de Infraestructura de Soporte Fisiologico" {
        It "Debe verificar la existencia fisica de los modulos core de soporte" {
            $null -ne $BackupModulePath | Should Be $true
            Test-Path $BackupModulePath | Should Be $true
            Test-Path $RevertPath | Should Be $true
        }
    }

    Context "Mecanica de Entrada y Perifericos de Alta Frecuencia" {
        It "Debe comprobar el quantum de CPU optimizado Win32PrioritySeparation" -Skip:($env:CI -eq "true") {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
            if (Test-Path $Path) {
                $Separation = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).Win32PrioritySeparation
                $Separation | Should Be 26
            }
        }

        It "Debe comprobar el desacoplamiento lineal de la aceleracion de raton de usuario" -Skip:($env:CI -eq "true") {
            $Path = "HKCU:\Control Panel\Mouse"
            $Speed = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).MouseSpeed
            $Th1 = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).MouseThreshold1
            $Th2 = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).MouseThreshold2
            $Speed | Should Be "0"
            $Th1 | Should Be "0"
            $Th2 | Should Be "0"
        }
    }

    Context "Modulo 02 y 08 - Saneamiento de Telemetria y Servicios Nucleares" {
        It "Debe verificar el estado deshabilitado de los servicios residuales bloqueados" -Skip:($env:CI -eq "true") {
            $Services = @("DiagTrack", "Fax", "RetailDemo", "MapsBroker", "PhoneSvc")
            foreach ($Service in $Services) {
                $Svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
                if ($null -ne $Svc) {
                    $Svc.StartType | Should Be "Disabled"
                }
            }
        }

        It "Debe verificar el estado de coexistencia manual para servicios de Windows Update y Diagnostico" -Skip:($env:CI -eq "true") {
            $Services = @("dmwappushservice", "WdiServiceHost", "WdiSystemHost", "WerSvc")
            foreach ($Service in $Services) {
                $Svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
                if ($null -ne $Svc) {
                    $Svc.StartType | Should Be "Manual"
                }
            }
        }

        It "Debe verificar que la directiva de Windows Error Reporting este deshabilitada" -Skip:($env:CI -eq "true") {
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
            if (Test-Path $Path) {
                $Disabled = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).Disabled
                $Disabled | Should Be 1
            }
        }
    }

    Context "Modulo 02 - Verificacion de Cobertura de Tareas Programadas" {
        It "Debe ratificar la inhabilitacion estructural de las tareas de telemetria" -Skip:($env:CI -eq "true") {
            $Tasks = @(
                "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                "Microsoft\Windows\Application Experience\ProgramDataUpdater",
                "Microsoft\Windows\Autochk\Proxy",
                "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                "Microsoft\Windows\Application Experience\StartupAppTask",
                "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
                "Microsoft\Windows\Feedback\Siuf\DmClient",
                "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
                "Microsoft\Windows\Windows Error Reporting\QueueReporting",
                "Microsoft\Windows\DiskFootprint\Diagnostics",
                "Microsoft\Windows\Maps\MapsToastTask",
                "Microsoft\Windows\Maps\MapsUpdateTask",
                "Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
                "Microsoft\Windows\Shell\FamilySafetyMonitor",
                "Microsoft\Windows\Shell\FamilySafetyRefreshTask"
            )
            foreach ($Task in $Tasks) {
                $TaskName = Split-Path $Task -Leaf
                $Check = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                if ($null -ne $Check) {
                    $Check.State | Should Be "Disabled"
                }
            }
        }
    }

    Context "Modulo 03 - Pila de Red y Latencia TCP" {
        It "Debe verificar la remocion del estrangulamiento, responsividad y retardo de cola TCP" -Skip:($env:CI -eq "true") {
            $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            
            $Throttling = (Get-ItemProperty -Path $ProfilePath -ErrorAction SilentlyContinue).NetworkThrottlingIndex
            $SysResp = (Get-ItemProperty -Path $ProfilePath -ErrorAction SilentlyContinue).SystemResponsiveness
            
            (@(4294967295, -1) -contains $Throttling) | Should Be $true
            $SysResp | Should Be 10
        }

        It "Debe comprobar la desactivacion de coalescencia de paquetes en adaptadores de red" -Skip:($env:CI -eq "true") {
            $NetClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
            if (Test-Path $NetClassPath) {
                $EthernetGuids = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
                    $_.Virtual -eq $false -and 
                    $_.NdisPhysicalMedium -eq 14 
                } | ForEach-Object { "$($_.InterfaceGuid)" }
                
                $NetAdapters = Get-ChildItem -Path $NetClassPath -ErrorAction SilentlyContinue
                foreach ($Adapter in $NetAdapters) {
                    if ($Adapter.PSChildName -match "^\d{4}$") {
                        $Props = Get-ItemProperty -Path $Adapter.PSPath -ErrorAction SilentlyContinue
                        if ($null -ne $Props -and $EthernetGuids -contains $Props.NetCfgInstanceId) {
                            if ($null -ne $Props."*PacketCoalescing") { $Props."*PacketCoalescing" | Should Be "0" }
                            if ($null -ne $Props.PacketCoalescing) { $Props.PacketCoalescing | Should Be "0" }
                        }
                    }
                }
            }
        }
    }

    Context "Modulo 04, 05 y 07 - Kernel, Almacenamiento y Pipelines Graficos" {
        It "Debe validar esquemas HwSchMode de programación por hardware de GPU" -Skip:($env:CI -eq "true") {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
            if (Test-Path $Path) {
                $Hags = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).HwSchMode
                $Hags | Should Be 2
            }
        }

        It "Debe verificar que MPO (Multiplane Overlay) permanezca en su estado por defecto" -Skip:($env:CI -eq "true") {
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
            if (Test-Path $Path) {
                $Mpo = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).OverlayTestMode
                $Mpo | Should Be $null
            }
        }

        It "Debe comprobar el desacoplamiento de la marca de tiempo NTFS Last Access" -Skip:($env:CI -eq "true") {
            if (Test-Path $ControlFileSystem) {
                $LastAccess = (Get-ItemProperty -Path $ControlFileSystem -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
                (@(1, 2, 3, 2147483649, 2147483650, 2147483651) -contains $LastAccess) | Should Be $true
            }
        }
        # Se removieron aserciones obsoletas de TdrDelay y SwapEffectUpgradeDisable
    }

    Context "Modulo 09 y 11 - Planes de Energia e IFEO Gaming Hooks" {
        It "Debe certificar la inyeccion de la maxima prioridad multimedia de hilos" -Skip:($env:CI -eq "true") {
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            if (Test-Path $Path) {
                $Sched = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue)."Scheduling Category"
                $Sfio = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue)."SFIO Priority"
                
                $Sched | Should Be "High"
                $Sfio | Should Be "High"
            }
        }

        It "Debe asegurar la aplicacion de HIGHDPI_SCALING_OVERRIDE_APPLICATION en AppCompatFlags Layers" -Skip:($env:CI -eq "true") {
            $GameHooksBackup = "HKLM:\SOFTWARE\Overlord\Backup\GameHooks"
            if (Test-Path $GameHooksBackup) {
                $SubKeys = Get-ChildItem -Path $GameHooksBackup -ErrorAction SilentlyContinue
                foreach ($Key in $SubKeys) {
                    $PathVal = Get-ItemPropertyValue -Path $Key.PSPath -Name "Path" -ErrorAction SilentlyContinue
                    if (![string]::IsNullOrWhiteSpace($PathVal)) {
                        $LayersPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
                        $CurrentFlags = (Get-ItemProperty -Path $LayersPath -Name $PathVal -ErrorAction SilentlyContinue).$PathVal
                        $CurrentFlags -match "HIGHDPI_SCALING_OVERRIDE_APPLICATION" | Should Be $true
                    }
                }
            }
        }
    }

    Context "Auditoria Estructural de QoL y Mecanismos de Reversion" {
        It "Debe comprobar la existencia fisica de scripts QoL complementarios" {
            Test-Path $GetQolPath | Should Be $true
            Test-Path $SetQolPath | Should Be $true
        }

        It "Debe validar que el extractor get_qol parsee un JSON estructural integro" {
            if (Test-Path $GetQolPath) {
                $JsonResult = & $GetQolPath | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($null -ne $JsonResult) {
                    ($JsonResult.PSObject.Properties.Name -contains "darkMode") | Should Be $true
                    ($JsonResult.PSObject.Properties.Name -contains "disableWidgets") | Should Be $true
                }
            }
        }

        It "Debe garantizar la integridad estructural del script de reversion espejo" {
            if (Test-Path $RevertPath) {
                $Content = Get-Content -Path $RevertPath -ErrorAction SilentlyContinue
                ([string]::IsNullOrEmpty($Content)) | Should Be $false
                ([string]::IsNullOrEmpty(($Content -match 'HKLM:\\SOFTWARE\\Overlord\\Backup'))) | Should Be $false
            }
        }
    }

    Context "Analisis Estatico de Simetria de Backups y Reversion" {
        BeforeAll {
            $RevertContent = (Get-Content -Path $RevertPath -Raw) -replace '`\r?\n\s*', ' '
        }

        It "Debe comprobar que cada Backup-OverlordRegistryValue en scripts de aplicacion tenga un restaurador simetrico en la reversion" {
            $ModuleFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" | Where-Object {
                $_.Name -match '^\d{2}_' -or $_.Name -eq 'disable_mitigations.ps1' -or $_.Name -eq 'crear_respaldo.ps1' -or $_.Name -eq 'set_qol.ps1'
            } | Where-Object { $_.Name -ne '10_revertir.ps1' }

            foreach ($File in $ModuleFiles) {
                $Content = (Get-Content -Path $File.FullName -Raw) -replace '`\r?\n\s*', ' '
                $Calls = [regex]::Matches($Content, 'Backup-OverlordRegistryValue\s+[^|\n;]+')
                foreach ($Call in $Calls) {
                    $Text = $Call.Value
                    $ValueName = $null
                    $SubFolder = $null
                    if ($Text -match '-ValueName\s+[\x22\x27]?([^\x22\x27\s]+)[\x22\x27]?') { $ValueName = $Matches[1].Trim() }
                    if ($Text -match '-BackupSubFolder\s+[\x22\x27]?([^\x22\x27\s]+)[\x22\x27]?') { $SubFolder = $Matches[1].Trim() }
                    
                    # Excluir subcarpetas de servicios y HibernateEnabled porque se restauran de forma personalizada
                    if ($null -ne $ValueName -and $null -ne $SubFolder -and $SubFolder -notmatch '^Services\\' -and $ValueName -ne 'HibernateEnabled') {
                        $EscapedVal = [regex]::Escape($ValueName)
                        $EscapedSub = [regex]::Escape($SubFolder)
                        
                        $Found = $false
                        if ($RevertContent -match "-ValueName\s+[\x22\x27]?$EscapedVal[\x22\x27]?[^|;\n]*?-BackupSubFolder\s+[\x22\x27]?$EscapedSub[\x22\x27]?") {
                            $Found = $true
                        } elseif ($RevertContent -match "-BackupSubFolder\s+[\x22\x27]?$EscapedSub[\x22\x27]?[^|;\n]*?-ValueName\s+[\x22\x27]?$EscapedVal[\x22\x27]?") {
                            $Found = $true
                        }
                        
                        # Fallback para variables o loops (ej. $PKey)
                        if (!$Found -and ($ValueName -match '^\$' -or $SubFolder -match '^\$')) {
                            if ($RevertContent -match "-ValueName\s+[\x22\x27]?$EscapedVal[\x22\x27]?") {
                                $Found = $true
                            }
                        }
                        
                        if (-not $Found) {
                            Write-Host "[-] ERROR SIMETRIA BACKUP -> REVERT: No se encontro restauracion para ValueName = '$ValueName', SubFolder = '$SubFolder' (Origen: $($File.Name))" -ForegroundColor Red
                        }
                        $Found | Should Be $true
                    }
                }
            }
        }

        It "Debe comprobar que cada restaurador de registro en la reversion tenga un Backup-OverlordRegistryValue en algun script de aplicacion" {
            $RevertCalls = [regex]::Matches($RevertContent, '(Invoke-OverlordSafeRestore|Restore-OverlordRegistryValue)\s+[^|\n;]+')
            
            $ModuleFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" | Where-Object {
                $_.Name -match '^\d{2}_' -or $_.Name -eq 'disable_mitigations.ps1' -or $_.Name -eq 'crear_respaldo.ps1' -or $_.Name -eq 'set_qol.ps1'
            } | Where-Object { $_.Name -ne '10_revertir.ps1' }
            
            $AppScriptsContent = ""
            foreach ($File in $ModuleFiles) {
                $AppScriptsContent += (Get-Content -Path $File.FullName -Raw) -replace '`\r?\n\s*', ' '
            }
            
            foreach ($Call in $RevertCalls) {
                $Text = $Call.Value
                $ValueName = $null
                $SubFolder = $null
                if ($Text -match '-ValueName\s+[\x22\x27]?([^\x22\x27\s]+)[\x22\x27]?') { $ValueName = $Matches[1].Trim() }
                if ($Text -match '-BackupSubFolder\s+[\x22\x27]?([^\x22\x27\s]+)[\x22\x27]?') { $SubFolder = $Matches[1].Trim() }
                
                # Omitir los parámetros genéricos del helper definidos en la firma de Invoke-OverlordSafeRestore
                if ($null -ne $ValueName -and $null -ne $SubFolder -and $ValueName -ne '$ValueName' -and $SubFolder -ne '$BackupSubFolder') {
                    $EscapedVal = [regex]::Escape($ValueName)
                    $EscapedSub = [regex]::Escape($SubFolder)
                    
                    $Found = $false
                    if ($AppScriptsContent -match "Backup-OverlordRegistryValue[^|;\n]*?-ValueName\s+[\x22\x27]?$EscapedVal[\x22\x27]?[^|;\n]*?-BackupSubFolder\s+[\x22\x27]?$EscapedSub[\x22\x27]?") {
                        $Found = $true
                    } elseif ($AppScriptsContent -match "Backup-OverlordRegistryValue[^|;\n]*?-BackupSubFolder\s+[\x22\x27]?$EscapedSub[\x22\x27]?[^|;\n]*?-ValueName\s+[\x22\x27]?$EscapedVal[\x22\x27]?") {
                        $Found = $true
                    }
                    
                    # Fallback para variables o loops (ej. $PKey)
                    if (!$Found -and ($ValueName -match '^\$' -or $SubFolder -match '^\$')) {
                        if ($AppScriptsContent -match "Backup-OverlordRegistryValue[^|;\n]*?-ValueName\s+[\x22\x27]?$EscapedVal[\x22\x27]?") {
                            $Found = $true
                        }
                    }
                    
                    if (-not $Found) {
                        Write-Host "[-] ERROR SIMETRIA REVERT -> BACKUP: No se encontro backup para ValueName = '$ValueName', SubFolder = '$SubFolder' en los scripts de aplicacion" -ForegroundColor Red
                    }
                    $Found | Should Be $true
                }
            }
        }

        It "Debe certificar que ninguna llamada SETACVALUEINDEX o SETDCVALUEINDEX en scripts de aplicacion carezca de su correspondiente backup/query" {
            $ModuleFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" | Where-Object {
                $_.Name -match '^\d{2}_' -or $_.Name -eq 'disable_mitigations.ps1'
            } | Where-Object { $_.Name -ne '10_revertir.ps1' }

            foreach ($File in $ModuleFiles) {
                $Content = (Get-Content -Path $File.FullName -Raw) -replace '`\r?\n\s*', ' '
                if ($Content -match "SETACVALUEINDEX|SETDCVALUEINDEX") {
                    ($Content -match "powercfg\s+/q" -or $Content -match "Backup-OverlordPowerSetting" -or $Content -match "Backup-OverlordRegistryValue") | Should Be $true
                    
                    # Conteo exacto: por cada SETAC/SETDC debe haber una consulta de respaldo previa
                    $SetCalls = [regex]::Matches($Content, "SETACVALUEINDEX|SETDCVALUEINDEX").Count
                    $BackupCalls = [regex]::Matches($Content, "Backup-OverlordPowerSetting|Backup-OverlordRegistryValue|powercfg\s+/q").Count
                    ($BackupCalls -ge $SetCalls) | Should Be $true
                }
            }
        }

        It "Debe verificar que get_modules_status.ps1 no use Test-Path sobre carpetas de backup como proxy de estado sin validacion real" {
            $StatusContent = (Get-Content -Path (Join-Path $ScriptsPath "get_modules_status.ps1") -Raw) -replace '`\r?\n\s*', ' '
            
            # Variables de backup
            $TestPathCalls = [regex]::Matches($StatusContent, 'Test-Path\s+\$(\w+Backup\w*|\w*Backup\w*)')
            foreach ($Call in $TestPathCalls) {
                $VarName = $Call.Groups[1].Value
                if ($VarName -ne "GameHooksBackup") {
                    throw "Se detecto un Test-Path sobre la variable de backup `$$VarName` en get_modules_status.ps1, lo cual viola la Regla 8 de AGENTS.md"
                }
            }
            
            # Rutas de backup literales
            $LiteralBackupCalls = [regex]::Matches($StatusContent, 'Test-Path\s+["''][^"'']*Overlord\\Backup[^"'']*["'']')
            if ($LiteralBackupCalls.Count -gt 0) {
                throw "Se detecto un Test-Path sobre una ruta de backup literal en get_modules_status.ps1, lo cual viola la Regla 8 de AGENTS.md"
            }
        }

        It "Debe verificar que todos los servicios desactivados en el debloat o la telemetria esten en la tabla de restauracion del revert" {
            $DebloatContent = (Get-Content -Path (Join-Path $ScriptsPath "02_debloat.ps1") -Raw) -replace '`\r?\n\s*', ' '
            $TelemetryContent = (Get-Content -Path (Join-Path $ScriptsPath "08_telemetria.ps1") -Raw) -replace '`\r?\n\s*', ' '
            
            $KnownServices = @("DiagTrack", "dmwappushservice", "Fax", "RetailDemo", "MapsBroker", "PhoneSvc", "AJRouter", "WpcMonSvc", "SensorService", "TrkWks", "RemoteRegistry", "WdiServiceHost", "WdiSystemHost", "WerSvc")
            
            foreach ($Svc in $KnownServices) {
                ($RevertContent -match "\b$Svc\b") | Should Be $true
                ($RevertContent -match "[\x22\x27]$Svc[\x22\x27]\s*=") | Should Be $true
            }
        }

        It "Debe comprobar que todas las tareas programadas desactivadas en debloat o telemetria se vuelvan a habilitar en la reversion" {
            $DebloatContent = Get-Content -Path (Join-Path $ScriptsPath "02_debloat.ps1") -Raw
            $TelemetryContent = Get-Content -Path (Join-Path $ScriptsPath "08_telemetria.ps1") -Raw
            
            $TaskMatches = [regex]::Matches($DebloatContent + $TelemetryContent, '["''](Microsoft\\Windows\\[^"'']+)["'']')
            foreach ($m in $TaskMatches) {
                $FullPath = $m.Groups[1].Value
                ($RevertContent -match "[\x22\x27]$([regex]::Escape($FullPath))[\x22\x27]") | Should Be $true
            }
        }

        It "Debe comprobar que todos los Autologgers desactivados en telemetria tengan su revert en el desinstalador" {
            $TelemetryContent = Get-Content -Path (Join-Path $ScriptsPath "08_telemetria.ps1") -Raw
            $LoggerMatches = [regex]::Matches($TelemetryContent, '(AutoLogger-[a-zA-Z0-9-]+|SQMLogger|DiagLog|AitEventLog)')
            foreach ($m in $LoggerMatches) {
                $LoggerName = $m.Groups[1].Value
                ($RevertContent -match "\b$LoggerName\b") | Should Be $true
            }
        }
    }
}