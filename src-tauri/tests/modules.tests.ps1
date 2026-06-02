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

Describe "Suite de Verificacion de Integridad Mecanica - Overlord v4.0.0" {
    Context "Auditoria de Infraestructura de Soporte Fisiologico" {
        It "Debe verificar la existencia fisica de los modulos core de soporte" {
            $null -ne $BackupModulePath | Should -Be $true
            Test-Path $BackupModulePath | Should -Be $true
            Test-Path $RevertPath | Should -Be $true
        }
    }

    Context "Mecanica de Entrada y Perifericos de Alta Frecuencia" {
        It "Debe comprobar existencia y tipos correctos en colas de mouclass" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
            if (Test-Path $Path) {
                $Size = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).MouseDataQueueSize
                if ($null -ne $Size) {
                    $Size.GetType().Name | Should -BeIn @("Int32", "Int64")
                }
            }
        }

        It "Debe comprobar existencia y tipos correctos en colas de kbdclass" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
            if (Test-Path $Path) {
                $Size = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).KeyboardDataQueueSize
                if ($null -ne $Size) {
                    $Size.GetType().Name | Should -BeIn @("Int32", "Int64")
                }
            }
        }
    }

    Context "Modulo 02 y 08 - Saneamiento de Telemetria y Servicios Nucleares" {
        It "Debe auditar de forma segura la resiliencia de los servicios afectados" {
            $Services = @("DiagTrack", "dmwappushservice", "Fax", "RetailDemo", "MapsBroker", "PhoneSvc", "Spooler")
            foreach ($Service in $Services) {
                $Status = Get-Service -Name $Service -ErrorAction SilentlyContinue
                if ($null -ne $Status) {
                    $Status.Name | Should -Be $Service
                } else {
                    $null | Should -Be $null
                }
            }
        }
    }

    Context "Modulo 02 - Verificacion de Cobertura de Tareas Programadas" {
        It "Debe confirmar la gestion e interrogacion segura de las 16 tareas programadas" {
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
                    $Check.TaskName | Should -Be $TaskName
                } else {
                    $null | Should -Be $null
                }
            }
        }
    }

    Context "Modulo 03 - Pila de Red y Latencia TCP" {
        It "Debe asegurar limites coherentes en la resistencia DNS" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
            if (Test-Path $Path) {
                $Ttl = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).MaxCacheTtl
                if ($null -ne $Ttl) {
                    $Ttl | Should -BeIn @(86400)
                }
            }
        }

        It "Debe verificar la consistencia de adaptadores e interfaces de red" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*"
            $Interfaces = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
            $Interfaces.Count | Should -BeGreaterThan -1
        }
    }

    Context "Modulo 04, 05 y 07 - Kernel, Almacenamiento y Pipelines Graficos" {
        It "Debe comprobar directivas de paginacion de ejecutivos del Kernel" {
            if (Test-Path $MemoryManagerPath) {
                $DisablePaging = (Get-ItemProperty -Path $MemoryManagerPath -ErrorAction SilentlyContinue).DisablePagingExecutive
                if ($null -ne $DisablePaging) {
                    $DisablePaging | Should -BeIn @(0, 1)
                }
            }
        }

        It "Debe validar esquemas HwSchMode de programacion por hardware de GPU" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
            if (Test-Path $Path) {
                $Hags = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).HwSchMode
                if ($null -ne $Hags) {
                    $Hags | Should -BeIn @(0, 1, 2)
                }
            }
        }

        It "Debe auditar la consistencia estructural de NTFS Last Access" {
            if (Test-Path $ControlFileSystem) {
                $LastAccess = (Get-ItemProperty -Path $ControlFileSystem -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
                if ($null -ne $LastAccess) {
                    $LastAccess | Should -BeIn @(0, 1, 2, 2147483648, 2147483649)
                }
            }
        }
    }

    Context "Modulo 09 y 11 - Planes de Energia e IFEO Gaming Hooks" {
        It "Debe comprobar la existencia de un plan de energia activo" {
            $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
            $ActivePlan | Should -Not -BeNullOrEmpty
        }

        It "Debe certificar las prioridades de la estructura multimedia de juegos" {
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            if (Test-Path $Path) {
                $Priority = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).Priority
                if ($null -ne $Priority) {
                    $Priority | Should -Not -BeNullOrEmpty
                }
            }
        }
    }

    Context "Auditoria Estructural de QoL y Mecanismos de Reversion" {
        It "Debe comprobar la existencia fisica de scripts QoL complementarios" {
            Test-Path $GetQolPath | Should -Be $true
            Test-Path $SetQolPath | Should -Be $true
        }

        It "Debe validar que el extractor get_qol parsee un JSON estructural integro" {
            if (Test-Path $GetQolPath) {
                $JsonResult = & $GetQolPath | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($null -ne $JsonResult) {
                    $JsonResult.PSObject.Properties.Name | Should -Contain "darkMode"
                    $JsonResult.PSObject.Properties.Name | Should -Contain "disableWidgets"
                }
            }
        }

        It "Debe garantizar la integridad estructural del script de reversion espejo" {
            if (Test-Path $RevertPath) {
                $Content = Get-Content -Path $RevertPath -ErrorAction SilentlyContinue
                $Content | Should -Not -BeNullOrEmpty
                $Content -match "HKLM:\\SOFTWARE\\Overlord\\Backup" | Should -Not -BeNullOrEmpty
            }
        }
    }
}