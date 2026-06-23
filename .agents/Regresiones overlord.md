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

`lib.rs` tenía `fetch_hardware()` y `log_from_js()` escribiendo a `c:/laragon/www/Overlord/...` — la ruta del entorno de desarrollo local del propio desarrollador (Laragon), ejecutándose (y fallando silenciosamente) en la máquina de cada usuario final. Ya corregido. Vigilar que no reaparezcan rutas con `laragon`, nombres de usuario del desarrollador, o cualquier ruta absoluta de un entorno de desarrollo en archivos `.rs`.

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

---

## Cómo usar este archivo

Antes de declarar cualquier tarea completa, recorre esta lista y confirma explícitamente, citando archivo y línea del código **actual** (no de este documento), que ninguno de estos 16 patrones reapareció. Si encuentras un patrón nuevo de la misma familia, agrégalo aquí como entrada 10, 11, etc. — este archivo solo es útil si crece con cada hallazgo nuevo.

