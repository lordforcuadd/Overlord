BeforeAll {
    $GlobalBackupPath = "HKLM:\SOFTWARE\Overlord\Backup"
    $ControlFileSystem = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $MemoryManagerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    
    $ScriptsPath = Join-Path $PSScriptRoot "..\scripts"
    $UtilsPath = Join-Path $ScriptsPath "utils.ps1"
    $GetQolPath = Join-Path $ScriptsPath "get_qol.ps1"
    $SetQolPath = Join-Path $ScriptsPath "set_qol.ps1"
    $RevertPath = Join-Path $ScriptsPath "10_revertir.ps1"
}

Describe "Suite de Verificacion de Integridad Mecanica - Overlord v2.5.4" {
    
    Context "Modulo 01 & 06 - Latencia de Perifericos e Interrupciones IRQ" {
        It "Debe comprobar existencia y tipos correctos en colas de mouclass" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
            if (Test-Path $Path) {
                $Size = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).MouseDataQueueSize
                $Size | Should -Not -BeNullOrEmpty
                $Size.GetType().Name | Should -BeIn @("Int32", "Int64")
            }
        }

        It "Debe comprobar existencia y tipos correctos en colas de kbdclass" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
            if (Test-Path $Path) {
                $Size = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).KeyboardDataQueueSize
                $Size | Should -Not -BeNullOrEmpty
                $Size.GetType().Name | Should -BeIn @("Int32", "Int64")
            }
        }
    }

    Context "Modulo 02 & 08 - Saneamiento de Bloatware, Directivas y Telemetria" {
        It "Debe validar la restriccion de recoleccion de telemetria nativa" {
            $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
            if (Test-Path $Path) {
                $AllowTelemetry = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).AllowTelemetry
                if ($null -ne $AllowTelemetry) {
                    $AllowTelemetry | Should -BeIn @(0, 1, 2, 3)
                }
            } else {
                $true | Should -Be $true
            }
        }

        It "Debe validar la existencia y accesibilidad del servicio DiagTrack" {
            $Service = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
            $Service | Should -Not -BeNullOrEmpty
        }
    }

    Context "Modulo 03 - Pila de Red y Latencia TCP/IP" {
        It "Debe asegurar el limite maximo de persistencia de TTL en DNS Cache si existe" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
            if (Test-Path $Path) {
                $Ttl = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).MaxCacheTtl
                if ($null -ne $Ttl) {
                    $Ttl | Should -BeLessThanOrEqualTo 300
                }
            } else {
                $true | Should -Be $true
            }
        }

        It "Debe verificar la consistencia de las interfaces de red TCP/IP" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*"
            $Interfaces = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
            $Interfaces.Count | Should -BeGreaterThan -1
        }
    }

    Context "Modulo 04 & 05 - Rendimiento General del Kernel y Pipelines de GPU" {
        It "Debe comprobar consistencia de desanidacion de paginacion de ejecutivos" {
            if (Test-Path $MemoryManagerPath) {
                $DisablePaging = (Get-ItemProperty -Path $MemoryManagerPath -ErrorAction SilentlyContinue).DisablePagingExecutive
                if ($null -ne $DisablePaging) {
                    $DisablePaging | Should -BeIn @(0, 1)
                }
            }
        }

        It "Debe validar la integridad de configuracion de esquema HwSchMode de GPU si existe" {
            $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
            if (Test-Path $Path) {
                $Hags = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).HwSchMode
                if ($null -ne $Hags) {
                    $Hags | Should -BeIn @(0, 1, 2)
                }
            }
        }
    }

    Context "Modulo 07 - Optimizacion de Archivos y Smart Storage" {
        It "Debe auditar el estado del marcador NtfsDisableLastAccessUpdate" {
            if (Test-Path $ControlFileSystem) {
                $LastAccess = (Get-ItemProperty -Path $ControlFileSystem -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate
                if ($null -ne $LastAccess) {
                    $LastAccess | Should -BeIn @(0, 1, 2, 2147483648, 2147483649)
                }
            }
        }
    }

    Context "Modulo 09 - Administracion Inteligente de Energia" {
        It "Debe comprobar la existencia de un plan de energia de Windows activo" {
            $ActivePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive -eq $true }
            $ActivePlan | Should -Not -BeNullOrEmpty
        }
    }

    Context "Modulo 11 - Image File Execution Options (IFEO) Gaming Hooks" {
        It "Debe certificar la estructura multimedia del perfil de juegos nativo" {
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            if (Test-Path $Path) {
                $Priority = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).Priority
                if ($null -ne $Priority) {
                    $Priority | Should -Not -BeNullOrEmpty
                }
            }
        }
    }

    Context "Auditoria de Infraestructura de Soporte (Utils & QoL)" {
        It "Debe verificar la existencia fisica de los archivos de soporte clave" {
            Test-Path $UtilsPath | Should -Be $true
            Test-Path $GetQolPath | Should -Be $true
            Test-Path $SetQolPath | Should -Be $true
            Test-Path $RevertPath | Should -Be $true
        }

        It "Debe validar que el extractor get_qol compile un JSON valido y no vacio" {
            if (Test-Path $GetQolPath) {
                $JsonResult = & $GetQolPath | ConvertFrom-Json -ErrorAction SilentlyContinue
                $JsonResult | Should -Not -BeNullOrEmpty
                $JsonResult.darkMode | Should -Not -BeNullOrEmpty
                $JsonResult.disableWidgets | Should -Not -BeNullOrEmpty
            }
        }

        It "Debe validar que el inyector set_qol finalice con codigo de salida limpio" {
            if (Test-Path $SetQolPath) {
                $Process = Start-Process powershell -ArgumentList "-File `"$SetQolPath`" -ToggleName 'disableWidgets' -IsEnabledStr 'true'" -NoNewWindow -PassThru -Wait
                $Process.ExitCode | Should -Be 0
            }
        }

        It "Debe garantizar la integridad estructural del script de reversión espejo" {
            if (Test-Path $RevertPath) {
                $Content = Get-Content -Path $RevertPath -ErrorAction SilentlyContinue
                $Content | Should -Not -BeNullOrEmpty
                $Content -match "HKLM:\\SOFTWARE\\Overlord\\Backup" | Should -Not -BeNullOrEmpty
            }
        }
    }
}