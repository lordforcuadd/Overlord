---
name: overlord-audit-delegate
description: "Recibe una lista plana de hallazgos generada por la skill overlord-audit (Hermes Agent), evalua cual es necesario corregir, y aplica los cambios siguiendo el protocolo de AGENTS.md. Usar cuando el usuario pega una lista con items etiquetados [BUG]/[SEGURIDAD]/[ARQUITECTURA]/[DEUDA]/[TWEAK]/[PRACTICA]/[INCONSISTENCIA]/[WINDOWS]/[RENDIMIENTO]/[UX]/[DUPLICACION]/[TESTS] y pide evaluarla o aplicarla."
---

# Overlord Audit Delegate

## Cuando usar esta skill

El usuario va a pegar una lista plana de hallazgos con este formato exacto (viene de la skill `overlord-audit` corrida en Hermes Agent, sobre un modelo distinto a este):

```
* [ETIQUETA] `archivo:linea` - descripcion corta del problema
```

Esta skill se dispara cuando el usuario pega una lista asi y pide algo como "revisa esto", "es necesario corregir esto?", "aplica lo que corresponda", o pega la lista sin mas contexto despues de mencionar Hermes/la auditoria.

## Rol de esta skill — NO es un auditor, es un evaluador + implementador

A diferencia de `overlord-audit` (que solo detecta y lista, nunca corrige), esta skill hace lo opuesto: parte de una lista YA generada por otro modelo y decide que hacer con cada item. El otro modelo (via Hermes) pudo haberse equivocado — tratar cada item como una sugerencia a verificar, no como una orden a ejecutar ciegamente.

## Paso 1 — Releer antes de decidir (misma regla anti-alucinacion que usa Hermes)

Para CADA item de la lista, antes de decidir si aplica:

1. Abrir el archivo citado y leer la linea/rango exacto.
2. Confirmar que el problema descrito realmente esta ahi, tal cual se describe. Si la cita no corresponde al codigo real (el modelo de Hermes pudo haber alucinado la linea o el patron), descartar el item y decirlo explicitamente en el resumen final — no intentar "encontrar algo parecido" para justificar la cita.
3. Si el archivo cambio desde que se genero la lista (por ejemplo, ya fue corregido en un commit posterior), marcarlo como "ya resuelto" y no tocar nada.

## Paso 2 — Evaluar si es necesario corregirlo

No todo hallazgo listado amerita un cambio. Antes de tocar codigo, verificar contra estos criterios — si alguno aplica, el item se reporta como "no se aplica" con la razon, no se implementa:

- **Diseno deliberado ya documentado**: revisar `AGENTS.md` (seccion "Tweaks Reales, Sin Placebos") y `REGRESIONES_OVERLORD.md` — si el patron citado coincide con una decision ya tomada a proposito (ej. no deshabilitar Core Isolation/VBS por compatibilidad con Vanguard/HVCI), no corregir.
- **Falso positivo de lectura**: el hallazgo describe un comportamiento que, al trazar el flujo completo (ej. una variable que parece indefinida localmente pero la inyecta un header externo), en realidad es correcto.
- **Categoria TWEAK/UX de bajo impacto sin consenso claro**: si es una recomendacion de mejora (no un bug), y no hay evidencia de que realmente cause dano o falle, preguntarle al usuario en el resumen final si quiere que se aplique en vez de decidir unilateralmente — estos son juicios de producto, no correcciones tecnicas obligatorias.

Todo lo demas (BUG, SEGURIDAD, INCONSISTENCIA, la mayoria de PRACTICA/ARQUITECTURA/DUPLICACION/TESTS) se corrige salvo que el Paso 1 lo haya descartado.

## Paso 3 — Aplicar siguiendo el protocolo de AGENTS.md, sin excepcion

Para cada item que se va a corregir:

1. Cambio minimo, enfocado, sin mezclar con refactors no pedidos (regla 11 de AGENTS.md).
2. Sincronizar TODOS los archivos relacionados si el cambio toca un tweak (script de aplicacion, `10_revertir.ps1`, `get_modules_status.ps1`, `tweaksMetadata.ts`, README, Pester) — regla 3 de AGENTS.md.
3. **Antes de dar el fix por terminado, releer el propio diff una vez mas** y preguntarse: "esto que acabo de escribir, hace exactamente lo que dije que hace, o solo se parece?" — no "el resto del archivo se ve bien?". Este es el paso que mas veces fallo historicamente en este proyecto (ver regla 11 y los 4 incidentes documentados en AGENTS.md).
4. Si el fix toca `.ps1`/`.psm1`: correr el parser real de PowerShell (regla 14 de AGENTS.md) sobre los archivos tocados, incluyendo cualquier here-string embebido, ANTES de reportar el fix como listo.
5. Si el fix toca Rust: `cargo check` (y si es posible `cargo clippy`).
6. Si el fix toca cualquier registro/servicio/tweak: correr `Invoke-Pester` sobre `modules.tests.ps1`.
7. Si ninguna herramienta de verificacion esta disponible en el entorno actual, decirlo explicitamente en el resumen — no reportar el fix como "verificado" sin haber corrido lo anterior.

## Paso 4 — Resumen final, formato fijo

Al terminar, resumir en tres bloques, sin narrativa de mas:

```
### Corregidos
- [ETIQUETA] archivo:linea - que se cambio (1 linea)

### No aplicados (con razon)
- [ETIQUETA] archivo:linea - por que no se toco (diseno deliberado / falso positivo / requiere decision de producto)

### Verificacion corrida
- cargo check: [resultado]
- Parser PowerShell: [resultado]
- Invoke-Pester: [resultado]
```

Si algun item quedo en duda genuina (no encaja claramente en "corregir" ni en "no aplicar"), preguntarle al usuario puntualmente por ese item en vez de decidir por el.

## Contexto del proyecto

Mismo stack y mismas notas que ya conoce `AGENTS.md`: Tauri v2, Rust + Vue 3/Pinia + PowerShell. Los archivos `AGENTS.md` y `REGRESIONES_OVERLORD.md` en la raiz del repo son la fuente de verdad para "que ya se decidio a proposito" — leerlos siempre antes de aplicar una lista nueva, no asumir que se recuerda su contenido de una sesion anterior.
