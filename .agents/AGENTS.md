# Reglas de Calidad y Auditoría Cero-Complacencia — Proyecto Overlord

Estas reglas se aplican a todas las interacciones con el repositorio de **Overlord**. El objetivo es eliminar errores de autocomplacencia y asegurar código de grado industrial, sin deuda técnica, 100% simétrico.

Antes de tocar cualquier archivo en `src-tauri/scripts/`, lee @REGRESIONES_OVERLORD.md. Contiene el historial exacto de bugs ya encontrados con evidencia de código real. Si tu cambio reintroduce alguno de esos patrones, la tarea falló, no importa qué tan bien se vea el resto.

---

## 1. Tolerancia Cero a la Autocomplacencia

- **No asumas**: nunca digas que un cambio está "perfecto", "completado" o "listo" sin haber trazado la ruta de ejecución de extremo a extremo (Rust → PowerShell → Registro/BCD/powercfg/archivo → Reversión).
- **Verificación de caja blanca**: revisa las implicaciones y efectos secundarios de cada cambio, no solo el caso feliz.
- **Prohibido declarar "perfecto" o "10/10" sin evidencia**: solo puedes decirlo si (a) el chequeo de simetría de Pester (sección Protocolo) corrió limpio en esta sesión sobre el código actual, (b) el parser de PowerShell (regla 14) corrió limpio sobre todos los `.ps1`/`.psm1` tocados, y (c) releíste @REGRESIONES_OVERLORD.md y confirmaste, citando archivo y línea, que ninguna regresión reapareció. Si no cumpliste las tres, dilo explícitamente: "no verificado al 100%, esto confirmé y esto falta."

## 2. Simetría Matemática Obligatoria (1:1)

- Cualquier optimización que modifique un valor de Registro, un ajuste de `powercfg`, un servicio de Windows, un valor de BCD, o un archivo de configuración de usuario, debe respaldar su estado inicial antes de tocarlo.
- Si un valor no existía de fábrica, el respaldo debe guardar el marcador `_ABSENT_`, y la reversión debe eliminar físicamente la propiedad.
- Prohibido usar valores fijos/hardcoded en la reversión que sobrescriban configuraciones personalizadas del usuario. La reversión usa siempre el dato del backup, con fallback al default real documentado de Microsoft solo si no existe backup — y ese default real tiene que coincidir con lo que el propio script de aplicación usa como valor objetivo, no con un valor distinto elegido a último momento (esto ya pasó: un revert cayó en un valor de fallback que no coincidía con ninguno de los dos, ni el original ni el aplicado).

## 3. Sincronización Estricta entre Componentes

Cada vez que se optimice, modifique, o **elimine** un tweak, sincroniza en el mismo cambio:

1. El script de optimización (`01_perifericos.ps1` … `12_defender_exclusions.ps1`, `disable_mitigations.ps1`, `manage_priority_service.ps1`).
2. El script de reversión (`10_revertir.ps1`).
3. El script de chequeo de estado (`get_modules_status.ps1`).
4. El mapeo de metadatos del frontend (`tweaksMetadata.ts`) — lo que el usuario ve dentro de la app. El texto tiene que describir lo que el código hace _de verdad_ (si un cambio queda persistente hasta que el usuario revierta, no lo llames "Pausado"; si un tweak solo borra propiedades específicas de una clave, no digas que la elimina "por completo").
5. La documentación pública (`README.md`).
6. La suite de pruebas de Pester (`modules.tests.ps1`).

Si eliminas un tweak del script de aplicación y no tocas los otros cinco, dejaste código fantasma, un status mentiroso, o documentación falsa. Esto ya pasó en este proyecto más de una vez.

## 4. Normalización de Nombres de Variables y Extensiones

- Las variables inyectadas por el executor en Rust (`$IsLaptop`, `$RamGB`, `$GameList`, `$ActionId`) deben coincidir letra por letra en todos los scripts PowerShell. **Verificar explícitamente cuál variable global inyecta el header de `executor.rs` para cada script antes de asumir que un `param()` local dentro del `.ps1` tiene efecto — los bloques `param()` se recortan antes de ejecutar, así que un script puede referenciar una variable con un nombre que nunca coincide con lo que realmente le llega, y el bug no se nota leyendo el archivo aislado.** (Esto ya causó que una función completa del ejecutable — Acciones Rápidas — no hiciera nada durante un tiempo.)
- Al validar nombres de ejecutables (`lib.rs`, `manage_priority_service.ps1`, `11_game_hooks.ps1`), normaliza el string (quitar `.exe`, mayúsculas/minúsculas) para evitar fallos de coincidencia.

## 5. Preservación del Estado Original de Archivos y Contenidos

- **Modificación interna de archivos**: si cambias un valor dentro de un archivo de configuración de usuario (ej. `GameUserSettings.ini`), respalda el valor original de esa línea específica antes de sobreescribirla. La reversión restaura el valor real, no solo atributos del archivo.
- **Atributo Read-Only**: si el archivo tenía Read-Only, respáldalo y vuelve a aplicarlo después de escribir — pero esto es secundario al punto anterior, nunca un sustituto.

## 6. Verificación Exhaustiva Línea por Línea

- Revisa cada archivo completo en cada cambio o auditoría, sin importar tokens o tiempo. Prioridad absoluta: corrección impecable, cero deuda técnica.
- La exigencia es full-stack: backend (Rust), scripts (PowerShell), frontend (Vue/Pinia), y archivos de configuración/distribución (Cargo.toml, tauri.conf.json, package.json).

## 7. Tweaks Reales, Sin Placebos, Compatibilidad Universal

- Cada tweak debe ser real, medible, y sustentado técnicamente. Nunca afirmes un mecanismo de por qué algo funciona o por qué se quitó sin haberlo verificado contra el código o documentación oficial — inventar una justificación técnica plausible es tan grave como inventar un bug.
- **Rutas de registro heredadas de generaciones viejas de drivers (ej. claves de "PowerMizer" bajo rutas genéricas de NVIDIA de eras anteriores) no se asumen efectivas en hardware/drivers recientes sin verificación con una herramienta de monitoreo real (GPU-Z, `nvidia-smi`, etc.) que confirme el cambio de estado antes/después. Si no se puede verificar, el tweak no entra como default — va a "Experimental" o se descarta.**
- **Tweaks removidos — historial honesto, no inventes razones nuevas**: si vas a evaluar reintroducir alguno de estos, parte de la razón real documentada en @REGRESIONES_OVERLORD.md, no de una justificación nueva sin verificar:
  - `MouseDataQueueSize` / `KeyboardDataQueueSize`, `MaxCacheTtl` / `MaxNegativeCacheTtl`, `TdrDelay` / `TdrLevel`, `SvcHostSplitThresholdInKB`, `disabledynamictick`, `FTH` (Fault Tolerant Heap).
- **Portabilidad**: Overlord debe correr de forma segura en cualquier PC o laptop del mundo. Cualquier tweak que dependa de un componente específico de hardware (SSD, GPU dedicada, NIC) debe verificar ESE componente específico, no un proxy general del sistema — ej. un fallback de detección de SSD debe filtrar a la unidad de arranque (`$env:SystemDrive`), no reportar "es SSD" si CUALQUIER disco del sistema lo es.
- **Alineación de perfiles por hardware**: los perfiles (Competitivo, Programador, Laptop, etc.) deben respetar exclusiones lógicas de hardware — no forzar planes de energía de escritorio en laptop, no aplicar coalescencia agresiva en WiFi de laptop. Al mover o refactorizar un tweak de un módulo a otro, verificar que no herede sin querer un `exit`/guard temprano pensado para una lógica distinta (ej. un tweak de red que se mueve al módulo de afinidad de IRQ no debe quedar atrapado detrás de un `if ($IsLaptop) { exit }` pensado solo para el remapeo físico de IRQ). Inyecta advertencias explícitas en la UI cuando un tweak compromete seguridad, para decisión informada del usuario.

## 8. Prohibido Usar Carpetas Compartidas como Indicador de Estado

`get_modules_status.ps1` debe consultar siempre el **valor real activo** en el sistema (clave de registro específica, configuración real de adaptador/servicio) para determinar si una optimización está aplicada. Está prohibido usar `Test-Path` sobre una carpeta de backup compartida entre módulos como proxy de "está activo" — una carpeta puede existir por la acción de OTRO módulo y dar un falso positivo. La lógica de detección tampoco debe aceptar valores que el script de aplicación nunca escribe (ej. si `disable_mitigations.ps1` solo escribe `8259`, el chequeo de estado no debe aceptar también `3` "por si acaso" — eso es lógica muerta o, peor, un falso positivo esperando pasar desapercibido).

## 9. Nota Técnica de Respaldo para `powercfg`

Las configuraciones de `powercfg` no se consultan con un Get/Set de registro simple de forma directa vía cmdlets — pero SÍ se puede leer el índice actual directamente del registro (`HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\...`) en vez de parsear la salida de texto de `powercfg /q`, que cambia según el idioma de Windows instalado y rompe en sistemas no ingleses. Antes de sobreescribir cualquier parámetro con `SETACVALUEINDEX`/`SETDCVALUEINDEX`, consulta el valor original (vía registro directo, no parseo de texto), y guárdalo en el registro de backup de Overlord para reversión dinámica, incluyendo el marcador `_ABSENT_` si el valor nunca fue personalizado. Nunca asumas que "cambiar el plan activo de vuelta" basta — no basta si el ajuste se aplicó sobre un plan que ya existía antes de instalar Overlord.

## 10. Gestión de Datos de Configuración de Arranque (BCD)

Los cambios vía `bcdedit` (`useplatformclock`, `disabledynamictick`, etc.) no viven en el registro de Windows sino en el almacén BCD. Respáldalos consultando el estado real con `bcdedit /enum` antes de modificar (guardando si ya estaba en el valor deseado, para no revertir algo que el usuario configuró antes de instalar Overlord), y revierte con `bcdedit /set` o `/deletevalue` según corresponda. Nunca trates un valor BCD como si fuera una clave de registro normal. Cualquier cambio de BCD requiere reinicio para aplicarse — esto debe quedar explícito en la UI (`tweaksMetadata.ts`), no implícito.

## 11. Disciplina de Alcance y Control de Refactors

Prohibido mezclar correcciones puntuales con refactors masivos no solicitados. Los cambios deben ser limpios, enfocados, y localizados al error o tweak pedido. Si crees que se necesita una refactorización mayor, propónla y espera confirmación explícita antes de tocar archivos fuera del alcance definido.

**No arregles un hallazgo introduciendo uno nuevo.** Antes de dar cualquier corrección por terminada, releé el diff completo una vez más y preguntate específicamente: "¿esto que acabo de escribir hace exactamente lo que dije que hace, o solo se parece?" — no "¿el resto del archivo se ve bien?". En este proyecto, arreglos apurados generaron regresiones nuevas más de una vez: un script completo quedó corrupto al intentar loguear un `catch` vacío, un placeholder de configuración (`"REEMPLAZAR_ESTO"`) quedó sin reemplazar en el build final, un valor de fallback incorrecto se cambió por otro valor igual de incorrecto, y una lógica movida de un módulo a otro quedó inalcanzable por un guard heredado sin querer. Ninguno de los cuatro era un error de intención — todos fueron de no releer el propio cambio antes de darlo por bueno.

## 12. Mecanismos de Persistencia (Daemons, Tareas Programadas, Servicios SYSTEM)

Cualquier mecanismo que persista en el sistema a nivel SYSTEM (`manage_priority_service.ps1` y similares) debe:

- Requerir consentimiento explícito e informado en la UI antes de instalarse, describiendo qué hace y que persiste tras cerrar la app.
- Quedar **completamente** desinstalado en `10_revertir.ps1`: tarea programada desregistrada, proceso detenido, directorio/archivos eliminados. Verificar esto explícitamente, no asumir que "borrar la carpeta" detiene el proceso en ejecución.
- Tener manejo de errores no silencioso. `$ErrorActionPreference = "SilentlyContinue"` en un bucle infinito sin ningún log es inaceptable — si el daemon falla, debe quedar registro de por qué.
- Si el mecanismo o script se genera como texto embebido (here-string `@'...'@`) dentro de otro `.ps1` para escribirse a un archivo aparte, ese texto embebido se valida por separado con el parser real (ver regla 14) — el parser del archivo contenedor no detecta errores de sintaxis dentro del string.

## 13. Fuente Única de Verdad para la Versión

La cadena de versión (ej. `v4.5.0`) debe vivir en un solo lugar (`Cargo.toml` o `package.json`) y todo lo demás (`tauri.conf.json`, `launch.ps1`, README, UI) debe leerla de ahí, nunca hardcodearla de forma independiente en múltiples archivos. Si encuentras un string de versión hardcodeado fuera de la fuente única, repórtalo y propone unificarlo.

## 14. Validación Sintáctica de PowerShell Obligatoria

Antes de dar por terminada cualquier modificación a scripts de PowerShell (`.ps1`, `.psm1`), es obligatorio ejecutar el parser oficial de PowerShell para verificar que no haya errores de sintaxis (paréntesis faltantes, problemas de scope con variables dentro de strings como `$Var:`, llaves sin cerrar, etc.). No confiar en la lectura visual del diff — en este proyecto, 4 bugs de sintaxis distintos pasaron una revisión visual completa y solo se detectaron corriendo el parser.

Ejecuta el siguiente comando en la raíz del proyecto y asegúrate de que no devuelva errores:

```powershell
Get-ChildItem -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $errors = $null; $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) { Write-Host "FALLA: $($_.Name)"; $errors | ForEach-Object { Write-Host " $_" } }
}
```

Si se modifica un daemon o script embebido (here-strings), se debe extraer a un archivo temporal y validarlo con el mismo parser (ver regla 12).

## 15. Higiene de Secretos y Control de Versiones

- **Nunca commitear certificados, claves privadas, tokens, ni archivos de credenciales** (`.pfx`, `.p12`, `.pem`, `.key`, `.cer` y equivalentes) al repositorio, sin importar si el repo es privado o público. Verificar `.gitignore` incluye estas extensiones antes de cualquier commit que toque configuración de firma o certificados.
- Antes de cualquier `git add`/`git commit` que incluya archivos nuevos fuera de `src-tauri/`, `src/`, o `scripts/`, revisar explícitamente qué se está agregando (`git status`, `git diff --stat`) — no asumir que solo se agregó lo que se pretendía tocar.
- Si un secreto llega a commitearse: no alcanza con borrarlo del working directory. Hay que sacarlo de **todo el historial de git** (reescritura con `git filter-repo`/BFG + force push), rotar la credencial asumiendo que ya está comprometida (no reusar el mismo par de claves), y confirmar que no quedó en forks/clones activos ni en el reflog remoto.
- Nunca dejar un valor de configuración sensible como placeholder literal sin reemplazar en una rama que se vaya a mergear a `main` (ej. `"REEMPLAZAR_ESTO"`, `"YOUR_VALUE_HERE"`) — si el valor real todavía no se conoce, usar una variable de entorno o un paso de build explícito que falle ruidosamente si falta, no un string que compile silenciosamente y quede roto en producción.

## 16. Concurrencia y Cierre de la Aplicación

- Nunca invocar `std::process::Command` (bloqueante) dentro de una función `async fn` de Rust sin envolverlo en `tokio::task::spawn_blocking` o usar `tokio::process::Command` en su lugar — bloquea el hilo del runtime de Tokio mientras el proceso externo corre, afectando la responsividad de toda la app durante ese tiempo. Si se corrige este patrón en un lugar del código, buscar y corregir todas las demás instancias en el mismo archivo o módulo relacionado — no asumir que había una sola.
- Cualquier mecanismo de aislamiento de procesos con terminación forzada (Job Objects con `KILL_ON_JOB_CLOSE` o equivalente) debe verificar que no exista una operación crítica de sistema en curso (DISM, SFC, escritura de registro) antes de permitir que la aplicación se cierre — usar `on_window_event`/`CloseRequested` con `prevent_close()` gateado por un `is_busy()` real (basado en el lock de ejecución existente, no un flag nuevo desincronizado), y notificar al usuario por qué no puede cerrar todavía.

---

## Protocolo Post-Modificación (obligatorio, sin excepción)

Después de cualquier cambio:

1. `cargo check` (y `cargo clippy -- -W clippy::all`) en `src-tauri`, para compilación y lints de Rust.
2. El comando de la regla 14 (parser de PowerShell) sobre todos los `.ps1`/`.psm1` tocados, incluyendo cualquier script embebido extraído por separado.
3. `Invoke-Pester` sobre `src-tauri/tests/modules.tests.ps1`.

**Nota de calidad sobre Pester — esto es lo que convierte el protocolo en un gate real, no en una formalidad**: los tests de Pester no deben limitarse a validar el estado final del sistema. Deben incluir un bloque de **análisis estático de texto** que lea con `Get-Content` y regex cada script en `src-tauri/scripts/` y certifique automáticamente que:

- Por cada `Backup-OverlordRegistryValue` en un script de aplicación, existe su `Invoke-OverlordSafeRestore`/`Restore-OverlordRegistryValue` correspondiente en `10_revertir.ps1` (mismo `ValueName` + `BackupSubFolder`).
- Por cada línea de reversión en `10_revertir.ps1`, existe un backup correspondiente en algún script de aplicación (si no, es código fantasma).
- Ninguna llamada `SETACVALUEINDEX`/`SETDCVALUEINDEX` aparece sin una consulta previa al valor original (registro directo o `powercfg /q`) o un `Backup-OverlordRegistryValue` cercano.
- `get_modules_status.ps1` no contiene el patrón `Test-Path $XBackup` combinado con una condición de laptop/desktop sin verificar también un valor real del sistema, y ningún chequeo de estado acepta un valor que ningún script de aplicación escribe realmente.
- El fallback de detección de un componente de hardware específico (SSD, GPU) filtra al dispositivo relevante, no reporta positivo si cualquier componente del mismo tipo en el sistema lo cumple.
- No hay archivos de certificado/clave (`.pfx`, `.p12`, `.pem`, `.key`) trackeados por git en ningún punto del árbol.

Si este bloque de Pester falla, la tarea no está completa, sin importar qué tan limpio se vea el resto del diff. Pega la salida completa de `Invoke-Pester` como evidencia antes de reportar cualquier tarea como terminada.
