# Reglas de Calidad y Auditoría Cero-Complacencia — Proyecto Overlord

Estas reglas se aplican a todas las interacciones con el repositorio de **Overlord**. El objetivo es eliminar errores de autocomplacencia y asegurar código de grado industrial, sin deuda técnica, 100% simétrico.

Antes de tocar cualquier archivo en `src-tauri/scripts/`, lee @REGRESIONES_OVERLORD.md. Contiene el historial exacto de bugs ya encontrados con evidencia de código real. Si tu cambio reintroduce alguno de esos patrones, la tarea falló, no importa qué tan bien se vea el resto.

---

## 1. Tolerancia Cero a la Autocomplacencia

- **No asumas**: nunca digas que un cambio está "perfecto", "completado" o "listo" sin haber trazado la ruta de ejecución de extremo a extremo (Rust → PowerShell → Registro/BCD/powercfg/archivo → Reversión).
- **Verificación de caja blanca**: revisa las implicaciones y efectos secundarios de cada cambio, no solo el caso feliz.
- **Prohibido declarar "perfecto" o "10/10" sin evidencia**: solo puedes decirlo si (a) el chequeo de simetría de Pester (sección Protocolo) corrió limpio en esta sesión sobre el código actual, y (b) releíste @REGRESIONES_OVERLORD.md y confirmaste, citando archivo y línea, que ninguna reapareció. Si no cumpliste ambas, dilo explícitamente: "no verificado al 100%, esto confirmé y esto falta."

## 2. Simetría Matemática Obligatoria (1:1)

- Cualquier optimización que modifique un valor de Registro, un ajuste de `powercfg`, un servicio de Windows, un valor de BCD, o un archivo de configuración de usuario, debe respaldar su estado inicial antes de tocarlo.
- Si un valor no existía de fábrica, el respaldo debe guardar el marcador `_ABSENT_`, y la reversión debe eliminar físicamente la propiedad.
- Prohibido usar valores fijos/hardcoded en la reversión que sobrescriban configuraciones personalizadas del usuario. La reversión usa siempre el dato del backup, con fallback al default real documentado de Microsoft solo si no existe backup.

## 3. Sincronización Estricta entre Componentes

Cada vez que se optimice, modifique, o **elimine** un tweak, sincroniza en el mismo cambio:

1. El script de optimización (`01_perifericos.ps1` … `11_game_hooks.ps1`, `disable_mitigations.ps1`, `manage_priority_service.ps1`).
2. El script de reversión (`10_revertir.ps1`).
3. El script de chequeo de estado (`get_modules_status.ps1`).
4. El mapeo de metadatos del frontend (`tweaksMetadata.ts`) — lo que el usuario ve dentro de la app.
5. La documentación pública (`README.md`).
6. La suite de pruebas de Pester (`modules.tests.ps1`).

Si eliminas un tweak del script de aplicación y no tocas los otros cinco, dejaste código fantasma, un status mentiroso, o documentación falsa. Las tres cosas ya pasaron en este proyecto.

## 4. Normalización de Nombres de Variables y Extensiones

- Las variables inyectadas por el executor en Rust (`$IsLaptop`, `$RamGB`, `$GameList`) deben coincidir letra por letra en todos los scripts PowerShell.
- Al validar nombres de ejecutables (`lib.rs`, `manage_priority_service.ps1`, `11_game_hooks.ps1`), normaliza el string (quitar `.exe`, mayúsculas/minúsculas) para evitar fallos de coincidencia.

## 5. Preservación del Estado Original de Archivos y Contenidos

- **Modificación interna de archivos**: si cambias un valor dentro de un archivo de configuración de usuario (ej. `GameUserSettings.ini`), respalda el valor original de esa línea específica antes de sobreescribirla. La reversión restaura el valor real, no solo atributos del archivo.
- **Atributo Read-Only**: si el archivo tenía Read-Only, respáldalo y vuelve a aplicarlo después de escribir — pero esto es secundario al punto anterior, nunca un sustituto.

## 6. Verificación Exhaustiva Línea por Línea

- Revisa cada archivo completo en cada cambio o auditoría, sin importar tokens o tiempo. Prioridad absoluta: corrección impecable, cero deuda técnica.
- La exigencia es full-stack: backend (Rust), scripts (PowerShell), frontend (Vue/Pinia), y archivos de configuración/distribución (Cargo.toml, tauri.conf.json, package.json).

## 7. Tweaks Reales, Sin Placebos, Compatibilidad Universal

- Cada tweak debe ser real, medible, y sustentado técnicamente. Nunca afirmes un mecanismo de por qué algo funciona o por qué se quitó sin haberlo verificado contra el código o documentación oficial — inventar una justificación técnica plausible es tan grave como inventar un bug.
- **Tweaks removidos — historial honesto, no inventes razones nuevas**: si vas a evaluar reintroducir alguno de estos, parte de la razón real documentada en @REGRESIONES_OVERLORD.md, no de una justificación nueva sin verificar:
  - `MouseDataQueueSize` / `KeyboardDataQueueSize`, `MaxCacheTtl` / `MaxNegativeCacheTtl`, `TdrDelay` / `TdrLevel`, `SvcHostSplitThresholdInKB`, `disabledynamictick`, `FTH` (Fault Tolerant Heap).
- **Portabilidad**: Overlord debe correr de forma segura en cualquier PC o laptop del mundo.
- **Alineación de perfiles por hardware**: los perfiles (Competitivo, Programador, Laptop, etc.) deben respetar exclusiones lógicas de hardware — no forzar planes de energía de escritorio en laptop, no aplicar coalescencia agresiva en WiFi de laptop. Inyecta advertencias explícitas en la UI cuando un tweak compromete seguridad, para decisión informada del usuario.

## 8. Prohibido Usar Carpetas Compartidas como Indicador de Estado

`get_modules_status.ps1` debe consultar siempre el **valor real activo** en el sistema (clave de registro específica, configuración real de adaptador/servicio) para determinar si una optimización está aplicada. Está prohibido usar `Test-Path` sobre una carpeta de backup compartida entre módulos como proxy de "está activo" — una carpeta puede existir por la acción de OTRO módulo y dar un falso positivo.

## 9. Nota Técnica de Respaldo para `powercfg`

Las configuraciones de `powercfg` no se consultan con un Get/Set de registro simple. Antes de sobreescribir cualquier parámetro con `SETACVALUEINDEX`/`SETDCVALUEINDEX`, consulta el valor original con `powercfg /q SCHEME_CURRENT <subgroup_guid> <setting_guid>`, parsea el índice actual, y guárdalo en el registro de backup de Overlord para reversión dinámica. Nunca asumas que "cambiar el plan activo de vuelta" basta — no basta si el ajuste se aplicó sobre un plan que ya existía antes de instalar Overlord.

## 10. Gestión de Datos de Configuración de Arranque (BCD)

Los cambios vía `bcdedit` (`useplatformclock`, etc.) no viven en el registro de Windows sino en el almacén BCD. Respáldalos consultando el estado real con `bcdedit /enum` antes de modificar, y revierte con `bcdedit /set` o `/deletevalue` según corresponda. Nunca trates un valor BCD como si fuera una clave de registro normal.

## 11. Disciplina de Alcance y Control de Refactors

Prohibido mezclar correcciones puntuales con refactors masivos no solicitados. Los cambios deben ser limpios, enfocados, y localizados al error o tweak pedido. Si crees que se necesita una refactorización mayor, propónla y espera confirmación explícita antes de tocar archivos fuera del alcance definido.

## 12. Mecanismos de Persistencia (Daemons, Tareas Programadas, Servicios SYSTEM)

Cualquier mecanismo que persista en el sistema a nivel SYSTEM (`manage_priority_service.ps1` y similares) debe:

- Requerir consentimiento explícito e informado en la UI antes de instalarse, describiendo qué hace y que persiste tras cerrar la app.
- Quedar **completamente** desinstalado en `10_revertir.ps1`: tarea programada desregistrada, proceso detenido, directorio/archivos eliminados. Verificar esto explícitamente, no asumir que "borrar la carpeta" detiene el proceso en ejecución.
- Tener manejo de errores no silencioso. `$ErrorActionPreference = "SilentlyContinue"` en un bucle infinito sin ningún log es inaceptable — si el daemon falla, debe quedar registro de por qué.

## 13. Fuente Única de Verdad para la Versión

La cadena de versión (ej. `v4.5.0`) debe vivir en un solo lugar (`Cargo.toml` o `package.json`) y todo lo demás (`tauri.conf.json`, `launch.ps1`, README, UI) debe leerla de ahí, nunca hardcodearla de forma independiente en múltiples archivos. Si encuentras un string de versión hardcodeado fuera de la fuente única, repórtalo y propone unificarlo.

---

## Protocolo Post-Modificación (obligatorio, sin excepción)

Después de cualquier cambio:

1. `cargo check` (y `cargo clippy -- -W clippy::all`) en `src-tauri`, para compilación y lints de Rust.
2. `Invoke-Pester` sobre `src-tauri/tests/modules.tests.ps1`.

**Nota de calidad sobre Pester — esto es lo que convierte el protocolo en un gate real, no en una formalidad**: los tests de Pester no deben limitarse a validar el estado final del sistema. Deben incluir un bloque de **análisis estático de texto** que lea con `Get-Content` y regex cada script en `src-tauri/scripts/` y certifique automáticamente que:

- Por cada `Backup-OverlordRegistryValue` en un script de aplicación, existe su `Invoke-OverlordSafeRestore`/`Restore-OverlordRegistryValue` correspondiente en `10_revertir.ps1` (mismo `ValueName` + `BackupSubFolder`).
- Por cada línea de reversión en `10_revertir.ps1`, existe un backup correspondiente en algún script de aplicación (si no, es código fantasma).
- Ninguna llamada `SETACVALUEINDEX`/`SETDCVALUEINDEX` aparece sin una consulta `powercfg /q` o un `Backup-OverlordRegistryValue` cercano.
- `get_modules_status.ps1` no contiene el patrón `Test-Path $XBackup` combinado con una condición de laptop/desktop sin verificar también un valor real del sistema.

Si este bloque de Pester falla, la tarea no está completa, sin importar qué tan limpio se vea el resto del diff. Pega la salida completa de `Invoke-Pester` como evidencia antes de reportar cualquier tarea como terminada.
