# REGRESIONES_OVERLORD.md — Catálogo de bugs confirmados con evidencia de código

Este archivo es la memoria persistente entre sesiones de Antigravity, que no recuerda nada por sí mismo de una sesión a otra. Cada entrada fue encontrada con evidencia directa del código real, no por inferencia ni por descripción de README. Antes de tocar `src-tauri/scripts/`, lee esto completo.

---

### 1. `get_modules_status.ps1` usando existencia de carpeta de backup compartida como proxy de estado

`06_irq_affinity.ps1` crea `HKLM:\SOFTWARE\Overlord\Backup\CPU` incondicionalmente, **antes** de revisar `$IsLaptop`. En laptop, el pinning real de IRQ nunca se ejecuta (`if ($IsLaptop) { exit 0 }`), pero la carpeta ya existe. `get_modules_status.ps1` tenía `if ($IsSystemLaptop -and (Test-Path $CpuBackup)) { $Status['irqAffinity'] = $true }` — esto reporta `true` en toda laptop, mienta el funcione o no. Confirmado en dos rondas de "fix" distintas sin corregirse. Regla violada si reaparece: punto 8 de AGENTS.md.

### 2. Eliminar un tweak de aplicación sin eliminar su contraparte en el revert

`SmoothMouseXCurve`/`SmoothMouseYCurve` se quitaron de `01_perifericos.ps1` en un refactor, pero las líneas `Remove-ItemProperty -Path $MousePath -Name "SmoothMouseXCurve"` quedaron huérfanas en `10_revertir.ps1`. Inofensivo en este caso puntual (es un no-op si la clave no existe), pero es el patrón exacto que en otro valor sí causaría error.

### 3. Backup condicionado a que la clave de destino ya exista

`04_rendimiento.ps1` tenía `if (Test-Path $StorePath) { Backup-OverlordRegistryValue ... }` para `GameDVR_Enabled`. En un perfil de usuario nuevo donde `HKCU:\System\GameConfigStore` no existe todavía, el backup se salta por completo — ni siquiera se guarda `_ABSENT_`. El revert no tiene nada que restaurar, el valor queda en `0` para siempre. `Backup-OverlordRegistryValue` ya maneja internamente el caso de clave inexistente (escribe `_ABSENT_`); envolver la llamada en `if (Test-Path...)` rompe esa garantía.

### 4. Sobreescribir un valor dentro de un archivo de usuario sin respaldar el original

`11_game_hooks.ps1` sobreescribe `FullscreenMode`/`LastConfirmedFullscreenMode`/`PreferredFullscreenMode` a `0` en archivos `GameUserSettings.ini` de juegos Unreal Engine, sin guardar el valor original en ningún lado. `10_revertir.ps1` solo restauraba el atributo `IsReadOnly` del archivo, nunca el valor real — pérdida permanente de la preferencia de pantalla del usuario (ventana sin bordes, por ejemplo) incluso después de "Revertir".

### 5. Modificar `powercfg` directamente sobre `SCHEME_CURRENT` sin backup por-ajuste

`09_energia.ps1` aplica 7+ ajustes vía `SETACVALUEINDEX` (PCIe Link State Power Management, USB-related x2, Processor min state x2, disk timeout, EPP, Boost Mode) directamente sobre el plan activo en ese momento, sin consultar ni guardar el valor original de ninguno. Se duplicó parcialmente en `01_perifericos.ps1` (USB Selective Suspend repetido con el mismo GUID que ya estaba en `09_energia.ps1`, sin backup en ninguna de las dos ubicaciones). Funciona sin pérdida SOLO cuando el ajuste se aplica sobre un plan que Overlord duplicó y luego borra entero en el revert. Falla en el plan por defecto de laptop y en el caso donde "Ultimate Performance" ya existía antes de instalar Overlord.

### 6. GUID sin identificar dejado en una condición de detección

`get_modules_status.ps1` tenía un match contra el substring `"77777777"` en la detección de `powerProfiles`, que no corresponde a ningún GUID real de Windows conocido (Balanced=`381b4222`, High Performance=`8c5e7fda`, Ultimate Performance=`e9a42b02`). Parece un residuo de prueba. Si reaparece algo similar, pide explicación antes de aceptarlo.

### 7. Rutas absolutas de entorno de desarrollo local compiladas en producción

`lib.rs` tenía `fetch_hardware()` and `log_from_js()` escribiendo a `c:/laragon/www/Overlord/...` — la ruta del entorno de desarrollo local del propio desarrollador (Laragon), ejecutándose (y fallando silenciosamente) en la máquina de cada usuario final. Ya corregido. Vigilar que no reaparezcan rutas con `laragon`, nombres de usuario del desarrollador, o cualquier ruta absoluta de un entorno de desarrollo en archivos `.rs`.

### 8. Documentación describiendo funciones que el código ya no implementa

`README.md` describió durante varias versiones `FTH`, `SvcHostSplitThresholdInKB`, `disabledynamictick`, `MouseDataQueueSize`/`KeyboardDataQueueSize`, `MaxCacheTtl`/`TcpTimedWaitDelay`, `TdrDelay`/`SwapEffectUpgradeDisable` — todas funciones que ya habían sido eliminadas del código real. `src/data/tweaksMetadata.ts` (lo que el usuario ve dentro de la app) se mantuvo correctamente sincronizado en paralelo — el README es el que se desincronizó. Ambos deben actualizarse en el mismo commit que añade o quita un tweak.

### 10. PowerShell Strict-Mode array casting mismatch en `11_game_hooks.ps1`

Al habilitar el modo estricto en PowerShell, la conversión explícita o asignación de variables de tipo array puede fallar si no se declara adecuadamente. Específicamente, en `11_game_hooks.ps1`, PowerShell fallaba con excepciones de tipo Strict-Mode al realizar `AddRange` de un valor escalar convertido a `[string[]]` si no se manejaba explícitamente, impidiendo que el módulo de prioridades de juegos se cargue correctamente.

### 11. Salida anticipada (early exit) en la purga de RAM nativa (`purge_ram_native` en Rust)

La función nativa de Rust `purge_ram_native` en `src-tauri/src/memory.rs` fallaba o salía de forma prematura en ciertas versiones de Windows debido a problemas de privilegios o a que no ejecutaba ambas fases del vaciado (vaciar la lista de standby y el working set de todos los procesos). Esto causaba que la liberación de memoria RAM no fuera efectiva o diera falsos positivos en el frontend.

### 12. Detección mentirosa (falsos positivos) en `get_modules_status.ps1` al usar proxy de carpetas

El lector de estado reportaba falsos positivos (`true`) para módulos como `peripheralLatency`, `smartStorage` y `gpuDisplay` simplemente verificando la existencia de la ruta de la carpeta de backup en el Registro en lugar de verificar los valores reales activos en el sistema (por ejemplo, el valor real de `Win32PrioritySeparation` para periféricos, o `NtfsDisableLastAccessUpdate` en el sistema de archivos para almacenamiento). Esto fue solucionado para asegurar que `get_modules_status.ps1` siempre consulte el estado real activo del sistema.

### 13. Excepciones por variables no declaradas o nulas bajo Strict Mode

Varios scripts de Overlord fallaron en producción al intentar acceder a propiedades nulas o variables no definidas globalmente (como usar `$RamGB` o `$IsLaptop` en `get_modules_status.ps1` sin declararlas en un bloque `param(...)` o sin validación de nulos previa). Esto provocaba que los scripts de PowerShell terminaran abruptamente con errores críticos bajo strict mode.

### 14. Revertir Windows Error Reporting (`WER\Disabled`) con valor por defecto `$null`

En `10_revertir.ps1`, la llamada a `Invoke-OverlordSafeRestore` para `Windows Error Reporting\Disabled` usaba un valor de restauración por defecto de `$null`. Si el usuario no tenía un backup previo, la restauración con `$null` simplemente no hacía nada (ya que la función omitía valores nulos de restauración), dejando el reporte de errores de Windows permanentemente desactivado (`Disabled = 1`) en lugar de eliminar el valor o restaurarlo a `0`. Se solucionó especificando un valor por defecto apropiado o eliminando físicamente la propiedad si no existía el backup (`_ABSENT_`).

### 15. Desinstalación incompleta del daemon en `manage_priority_service.ps1`

La sección de desinstalación (`uninstall`) del daemon de prioridad de juegos desregistraba la tarea programada con `Unregister-ScheduledTask`, pero no detenía de forma garantizada el proceso en ejecución de PowerShell en segundo plano (el cual corre en un ciclo infinito `while ($true)`) ni borraba la carpeta de instalación `InstallDir`, dejando el script y los logs remanentes en el sistema del usuario final.

### 16. Claves de energía huérfanas en la restauración de configuraciones `powercfg` (`_ABSENT_`)

Al restaurar ajustes de energía que inicialmente estaban ausentes (guardados con el marcador `_ABSENT_`), `10_revertir.ps1` solo eliminaba la propiedad específica `ACSettingIndex` / `DCSettingIndex` usando `Remove-ItemProperty`, pero dejaba la subclave del GUID del ajuste de energía vacía en el registro como un elemento huérfano. Para mantener la simetría matemática 1:1 estricta, la reversión ahora elimina la subclave completa si ya no contiene propiedades asociadas y no existía originalmente.

### 17. Claves de módulos huérfanas al agregar nuevos componentes (Falta de reactividad en perfiles)

Al agregar un nuevo módulo (como `defenderExclusions`), este debe ser registrado explícitamente en el estado inicial de `modules` dentro de `overlordStore.ts` y en la plantilla de claves esperadas de `buildExpectedProfileState` en `profileLogic.ts`. De lo contrario, al aplicar perfiles de optimización que no contengan dicho módulo, el toggle correspondiente no se reseteará a `false`, quedando permanentemente activo.

### 18. Sensibilidad a mayúsculas/minúsculas al clasificar la gama de CPU (`cpuBrand`)

Comparar el nombre comercial del procesador (`cpuBrand`) directamente contra cadenas de texto con capitalizaciones específicas (ej. "Ryzen 9", "Ultra 9") causa que fallos en caliente de WMI de Windows (o diferencias del sistema operativo) que retornen la marca en otra capitalización fallen en clasificar el equipo como Gama Alta, desactivando accidentalmente optimizaciones como `disableMitigations`. Es mandatorio normalizar `cpuBrand` a minúsculas antes de evaluar.

### 19. Duplicación de lógica de resolución de SID de usuario

La resolución de SID del usuario interactivo y la construcción de `$HKCU_Path` deben centralizarse en un script único (`sid_resolver.ps1`) que el executor en Rust inyecta al inicio de todo payload de ejecución de PowerShell. Delegar en un script dot-sourced/inyectado evita tener tres niveles de fallbacks diferentes y divergentes entre scripts de lectura y escritura.

### 20. Uso de constantes mágicas en la creación de procesos en Rust

Utilizar literales numéricos como `0x08000000` en lugar de una constante autoexplicativa en Rust para definir flags de creación de procesos (`CREATE_NO_WINDOW`). Se corrigió declarando de forma explícita `const CREATE_NO_WINDOW: u32 = 0x0800_0000` en `executor.rs` y `hardware.rs` para alinearse a la legibilidad y mantenimiento del código.

### 21. Declaración de variables y parámetros obsoletos no consumidos

Mantener firmas obsoletas en scripts PowerShell (como la variable `[string]$Arguments` en `shutdown.ps1`) que nunca son leídas ni procesadas en el cuerpo. Esto introduce confusión y ruido en el linter estático de código.

### 22. Rutas e instalaciones de juego hardcodeadas en el backend

Realizar búsquedas estáticas de instalaciones de juegos apuntando directamente a unidades específicas (como `"D:\\Epic Games"` o `"D:\\XboxGames"`). Si el usuario cambia las letras de unidad o las monta de otra forma, la detección falla. Se corrigió escaneando dinámicamente el listado de unidades montadas del sistema (de la `C:` a la `Z:`) usando la API de Rust.

### 23. Caché estática del sistema de hardware no invalidable

El uso de `OnceCell` para almacenar el inventario de hardware de la máquina provocaba que cambios en caliente (eGPU, RAM conectada por Thunderbolt) no se reflejaran en la UI hasta que el usuario reiniciara físicamente la aplicación. Se solucionó migrando a un `RwLock<Option<HardwareResponse>>` que admite refresco e invalidación explícita mediante la bandera `force_refresh`.

### 24. Carga inútil de dependencias de escritura en consultas rápidas de lectura

Concatenar el script completo de soporte de backups `backup_manager.psm1` (~10KB) en comandos asíncronos y rápidos de lectura como `get_qol` y `get_modules_status` sobrecarga el canal de stdin. Se corrigió implementando carga condicional de dependencias según la bandera `is_readonly` en `executor.rs`.

### 25. Redundancia de buscadores recursivos de archivos (`Find-FileFaster`)

Duplicar la declaración e implementación local de la función recursiva `Find-FileFaster` en múltiples scripts de optimización. Se centralizó la lógica en el archivo global `backup_manager.psm1` para evitar código redundante y divergente en el mantenimiento de scripts.

### 26. Verificación de existencia del registro como proxy de tarea activa en Rust

La existencia de una clave en el registro `TaskCache\Tree\OverlordPriorityMonitor` solo denota que la tarea existe en el programador, no que está activa. Si el usuario la deshabilita manualmente, el monitor en Rust se apagaba en silencio pensando que la tarea lo respaldaba. Se corrigió consultando directamente la propiedad `.State` mediante `Get-ScheduledTask` para verificar de forma inequívoca el estado activo (`Ready` o `Running`).

### 27. Reversión completa de seguridad ante fallos en lugar de rollback selectivo

En caso de que una optimización falle a mitad de camino, el orquestador ejecuta una reversión completa de seguridad llamando a `10_revertir.ps1` en lugar de una reversión selectiva parcial. Esto constituye un diseño deliberado para evitar dejar al sistema operativo del usuario en un estado inestable híbrido (Frankenstein). La documentación debe reflejar con honestidad esta reversión total.

### 28. Bloqueo de hilos de Tokio con `std::sync::Mutex` en contexto asíncrono

El uso de exclusiones mutuas síncronas (`std::sync::Mutex`) dentro de funciones asíncronas de Rust en Tauri (`lib.rs`) bloqueaba el runtime thread al esperar por canales `oneshot`. Se solucionó migrando a `tokio::sync::Mutex` para asegurar un comportamiento asíncrono no bloqueante.

### 29. Serialización global innecesaria de scripts de lectura y escritura (`EXECUTION_LOCK`)

Tener un único lock exclusivo global (`EXECUTION_LOCK`) serializaba comandos rápidos e independientes como `get_modules_status.ps1` y `crear_respaldo`. Se rediseñó el executor en Rust para permitir que los scripts de solo lectura se ejecuten concurrentemente, evitando retrasos en la respuesta de la UI.

### 30. Supresión de stderr sin control del código de salida en `powercfg`

El redireccionamiento `2>$null` en llamadas de cambio de plan de energía en portátiles (`09_energia.ps1`) ocultaba errores críticos si el plan no se podía establecer. Se corrigió agregando la verificación del código de salida `$LASTEXITCODE` después de cada invocación para abortar de manera controlada.

### 31. Fuga de servicios del sistema por interrupción abrupta de scripts de larga duración

La ejecución de comandos de diagnóstico (`quick_actions.ps1`) puede tomar mucho tiempo y ser interrumpida por el timeout del backend de Rust (1200s), dejando el servicio de Windows Update (`wuauserv`) iniciado de manera persistente. Se envolvió la lógica en bloques `try/finally` para asegurar que el estado del servicio se restaure incondicionalmente al valor original de inicio.

### 32. Detección incompleta de instancias y ejecutables de Minecraft moddeados

La lógica de exclusiones y prioridades de juego solo buscaba la carpeta original Vanilla `%APPDATA%\.minecraft`, omitiendo directorios donde corren instancias independientes de CurseForge, Prism Launcher, Modrinth o TLauncher. Se amplió el escaneo dinámico en Rust para incluir estas rutas moddeadas y resolver dinámicamente los binarios de `javaw.exe`.

---

## Cómo usar este archivo

Antes de declarar cualquier tarea completa, recorre esta lista y confirma explícitamente, citando archivo y línea del código **actual** (no de este documento), que ninguno de estos 33 patrones reapareció. Si encuentras un patrón nuevo de la misma familia, agrégalo aquí como entrada 10, 11, etc. — este archivo solo es útil si crece con cada hallazgo nuevo.

### 33. Corrupción de macros de Rust (include_str!) por cambio silencioso de codificación en PowerShell

Al modificar archivos .ps1 mediante Set-Content u otras herramientas desde Windows PowerShell 5.1, la codificación por defecto se cambia a Windows-1252 o UTF-8 con BOM. Esto rompe instantáneamente la compilación del backend en Rust, ya que macros como include_str! exigen archivos estrictamente en UTF-8 puro (sin BOM). Se corrigió iterando sobre los archivos modificados e inyectando un objeto [System.Text.UTF8Encoding] False para forzar la escritura en UTF-8 sin BOM, asegurando compatibilidad con el compilador de Rust.
