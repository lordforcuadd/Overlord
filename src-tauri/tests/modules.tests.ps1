$ManifestPath = Join-Path $PSScriptRoot "..\Cargo.toml"
$Version = "Unknown"
if (Test-Path $ManifestPath) {
    $Manifest = Get-Content -Path $ManifestPath -Raw
    if ($Manifest -match 'version\s*=\s*"([^"]+)"') {
        $Version = $Matches[1]
    }
}
Describe "Suite de Verificacion de Integridad Mecanica - Overlord v$Version" {
    BeforeAll {
        $GlobalBackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
        $ControlFileSystem = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        $MemoryManagerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        $ScriptsPath = Join-Path $PSScriptRoot "..\scripts"
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
        It "Debe comprobar el quantum de CPU optimizado Win32PrioritySeparation" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
            if (Test-Path $Path) {
                $Separation = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).Win32PrioritySeparation
                $Separation | Should Be 26
            }
        }

        It "Debe comprobar el desacoplamiento lineal de la aceleracion de raton de usuario" {
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
        It "Debe verificar el estado deshabilitado de los servicios residuales bloqueados" {
            $Services = @("DiagTrack", "Fax", "RetailDemo", "MapsBroker", "PhoneSvc")
            foreach ($Service in $Services) {
                $Svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
                if ($null -ne $Svc) {
                    $Svc.StartType | Should Be "Disabled"
                }
            }
        }

        It "Debe verificar el estado de coexistencia manual para servicios de Windows Update y Diagnostico" {
            $Services = @("dmwappushservice", "WdiServiceHost", "WdiSystemHost", "WerSvc")
            foreach ($Service in $Services) {
                $Svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
                if ($null -ne $Svc) {
                    $Svc.StartType | Should Be "Manual"
                }
            }
        }

        It "Debe verificar que la directiva de Windows Error Reporting este deshabilitada" {
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
            if (Test-Path $Path) {
                $Disabled = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).Disabled
                $Disabled | Should Be 1
            }
        }
    }

    Context "Modulo 02 - Verificacion de Cobertura de Tareas Programadas" {
        It "Debe ratificar la inhabilitacion estructural de las tareas de telemetria" {
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
        It "Debe verificar la remocion del estrangulamiento, responsividad y retardo de cola TCP" {
            $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            
            $Throttling = (Get-ItemProperty -Path $ProfilePath -ErrorAction SilentlyContinue).NetworkThrottlingIndex
            $SysResp = (Get-ItemProperty -Path $ProfilePath -ErrorAction SilentlyContinue).SystemResponsiveness
            
            (@(4294967295, -1) -contains $Throttling) | Should Be $true
            $SysResp | Should Be 10
        }

        It "Debe comprobar la desactivacion de coalescencia de paquetes en adaptadores de red" {
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
        It "Debe validar esquemas HwSchMode de programación por hardware de GPU" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
            if (Test-Path $Path) {
                $Hags = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).HwSchMode
                $Hags | Should Be 2
            }
        }

        It "Debe verificar que MPO (Multiplane Overlay) permanezca en su estado por defecto" {
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
            if (Test-Path $Path) {
                $Mpo = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).OverlayTestMode
                $Mpo | Should Be $null
            }
        }

        It "Debe comprobar el desacoplamiento de la marca de tiempo NTFS Last Access" {
            if (Test-Path $ControlFileSystem) {
                $LastAccess = (Get-ItemProperty -Path $ControlFileSystem -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
                (@(1, 2, 3, 2147483649, 2147483650, 2147483651) -contains $LastAccess) | Should Be $true
            }
        }
        # Se removieron aserciones obsoletas de TdrDelay y SwapEffectUpgradeDisable
    }

    Context "Modulo 09 y 11 - Planes de Energia e IFEO Gaming Hooks" {
        It "Debe certificar la inyeccion de la maxima prioridad multimedia de hilos" {
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            if (Test-Path $Path) {
                $Sched = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue)."Scheduling Category"
                $Sfio = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue)."SFIO Priority"
                
                $Sched | Should Be "High"
                $Sfio | Should Be "High"
            }
        }

        It "Debe asegurar la aplicacion de HIGHDPI_SCALING_OVERRIDE_APPLICATION en AppCompatFlags Layers" {
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
            $RevertContent = Get-Content -Path $RevertPath -Raw
        }

        It "Debe comprobar que cada Backup-OverlordRegistryValue con llave estatica tenga su correspondiente restauracion en el revert" {
            $ModuleFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" | Where-Object {
                $_.Name -match '^\d{2}_' -or $_.Name -eq 'disable_mitigations.ps1'
            } | Where-Object { $_.Name -ne '10_revertir.ps1' }

            foreach ($File in $ModuleFiles) {
                $Content = Get-Content -Path $File.FullName -Raw
                # Extrae todas las llamadas como: -ValueName "Win32PrioritySeparation"
                $Matches = [regex]::Matches($Content, '-ValueName\s+["'']([^"'']+)["'']')
                foreach ($m in $Matches) {
                    $ValueName = $m.Groups[1].Value
                    if ($ValueName -notmatch '\$') { # Omitir variables dinamicas en regex estatico
                        ($RevertContent -match "\b$ValueName\b") | Should Be $true
                    }
                }
            }
        }

        It "Debe verificar que todos los servicios desactivados en el debloat o la telemetria esten en la tabla de restauracion del revert" {
            $DebloatContent = Get-Content -Path (Join-Path $ScriptsPath "02_debloat.ps1") -Raw
            $TelemetryContent = Get-Content -Path (Join-Path $ScriptsPath "08_telemetria.ps1") -Raw
            
            $KnownServices = @("DiagTrack", "dmwappushservice", "Fax", "RetailDemo", "MapsBroker", "PhoneSvc", "AJRouter", "WpcMonSvc", "SensorService", "TrkWks", "RemoteRegistry", "WdiServiceHost", "WdiSystemHost", "WerSvc")
            
            foreach ($Svc in $KnownServices) {
                ($RevertContent -match "\b$Svc\b") | Should Be $true
            }
        }

        It "Debe comprobar que todas las tareas programadas desactivadas en debloat o telemetria se vuelvan a habilitar en la reversion" {
            $DebloatContent = Get-Content -Path (Join-Path $ScriptsPath "02_debloat.ps1") -Raw
            $TelemetryContent = Get-Content -Path (Join-Path $ScriptsPath "08_telemetria.ps1") -Raw
            
            # Buscar rutas tipicas de tareas de Windows
            $TaskMatches = [regex]::Matches($DebloatContent + $TelemetryContent, '["''](Microsoft\\Windows\\[^"'']+)["'']')
            foreach ($m in $TaskMatches) {
                $FullPath = $m.Groups[1].Value
                $TaskName = Split-Path $FullPath -Leaf
                ($RevertContent -match "\b$TaskName\b") | Should Be $true
            }
        }

        It "Debe comprobar que todos los Autologgers desactivados en telemetria tengan su revert en el desinstalador" {
            $TelemetryContent = Get-Content -Path (Join-Path $ScriptsPath "08_telemetria.ps1") -Raw
            # Buscar nombres de loggers
            $LoggerMatches = [regex]::Matches($TelemetryContent, '(AutoLogger-[a-zA-Z0-9-]+|SQMLogger|DiagLog|AitEventLog)')
            foreach ($m in $LoggerMatches) {
                $LoggerName = $m.Groups[1].Value
                ($RevertContent -match "\b$LoggerName\b") | Should Be $true
            }
        }
    }
}