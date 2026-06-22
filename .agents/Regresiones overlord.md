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

### 9. Justificaciones técnicas inventadas para tweaks ya removidos

En una iteración de este mismo documento de reglas, se escribieron razones técnicas específicas para 6 tweaks en una "lista negra" — pero al menos 3 de esas razones resultaron ser inexactas o no verificadas: se afirmó que FTH causaba "overhead en la asignación de RAM" (la razón real discutida fue remoción de una red de seguridad ante corrupción de memoria, dirección distinta); se afirmó que `MouseDataQueueSize`/`KeyboardDataQueueSize` "provocan stutters a tasas altas" (la razón original del tweak era exactamente la contraria: prevenir drops de input a tasas altas; no hay evidencia de por qué se quitó); se afirmó que `disabledynamictick` "genera problemas de temporización" llamándolo placebo (es un mecanismo real y documentado con un tradeoff de energía vs. consistencia de timer, no un placebo). Regla: nunca inventes un mecanismo técnico plausible para justificar una decisión pasada sin verificarlo. Es preferible escribir "removido sin razón documentada, no reintroducir sin investigar" que inventar una causa falsa.

---

## Cómo usar este archivo

Antes de declarar cualquier tarea completa, recorre esta lista y confirma explícitamente, citando archivo y línea del código **actual** (no de este documento), que ninguno de estos 9 patrones reapareció. Si encuentras un patrón nuevo de la misma familia, agrégalo aquí como entrada 10, 11, etc. — este archivo solo es útil si crece con cada hallazgo nuevo.
