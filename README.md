<div align="center">
  <img src="overlord_icon.png" alt="Overlord Logo" width="120">

# OVERLORD

**Suite de Optimización de Grado Industrial, Privacidad y Rendimiento Extremo para Windows 10 y 11.**

Una herramienta de ingeniería orientada al rendimiento competitivo en videojuegos, depuración profunda del sistema operativo y eliminación del retraso de entrada (_input lag_), impulsada por un núcleo asíncrono en **Rust**, scripts ejecutados en memoria RAM vía **PowerShell**, y una interfaz moderna construida sobre **Vue 3, Tailwind CSS y Pinia**.

[![Vue.js](https://img.shields.io/badge/Vue%203-35495E?style=for-the-badge&logo=vue.js&logoColor=4FC08D)](https://vuejs.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![Tauri](https://img.shields.io/badge/Tauri-FFC131?style=for-the-badge&logo=tauri&logoColor=white)](https://tauri.app/)
[![Rust](https://img.shields.io/badge/Rust-000000?style=for-the-badge&logo=rust&logoColor=white)](https://www.rust-lang.org/)
[![PowerShell](https://img.shields.io/badge/PowerShell_5.1-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://docs.microsoft.com/powershell/)
[![CI Matrix](https://img.shields.io/badge/CI_Matrix-100%25_Passing-brightgreen?style=for-the-badge&logo=githubactions&logoColor=white)](.github/workflows/ci.yml)

</div>

<hr>

<div align="center">
  <img src="/src/assets/overlordPanel.png" alt="Overlord UI" width="800"/>
</div>

---

## 🚀 Guía Rápida para el Usuario (Quick Start)

Overlord está diseñado para que cualquier usuario, desde un jugador entusiasta hasta un profesional de eSports, pueda optimizar su PC de forma **segura, transparente e indolora**.

### 1. Descarga y Ejecución en 1 Clic (Sin Instaladores)
No necesitas instalar programas pesados que dejen residuos. Abre **PowerShell como Administrador** y pega:

```powershell
irm https://raw.githubusercontent.com/lordforcuadd/Overlord/main/launch.ps1 | iex
```
*Overlord se descargará y ejecutará en memoria con privilegios elevados de forma 100% segura.*

### 2. Elige tu Perfil Inteligente
La aplicación analiza automáticamente tu procesador (CPU), tarjeta gráfica (GPU), memoria RAM y tipo de equipo (PC de escritorio o Laptop):
* **🏆 Competitivo / Gaming:** Diseñado para eSports (CS2, Valorant, Warzone, Apex). Latencia de entrada ultra-baja, afinidad de interrupciones (IRQ), prioridades multimedia MMCSS y máxima estabilidad de fotogramas (1% Low FPS).
* **⚖️ Equilibrado:** Máxima fluidez para gaming y uso diario sin desactivar servicios auxiliares de Windows.
* **🛡️ Seguro:** Optimización ligera y debloat conservador enfocado en privacidad y reducción de procesos en segundo plano.
* **💻 Laptop:** Optimiza la latencia de red y periféricos respetando el consumo de batería y la gestión térmica del portátil.

### 3. Blindaje Automático (Respaldo Obligatorio)
Antes de tocar un solo valor del sistema, Overlord **crea un Punto de Restauración del Sistema (VSS)** y respalda en el Registro (`HKLM:\SOFTWARE\Overlord\Backup`) el valor original de cada ajuste junto con su tipo exacto de dato.

### 4. ¿Qué esperar tras optimizar?
* **Reinicio del Sistema:** Al finalizar la inyección de módulos, el sistema te solicitará reiniciar para que el Kernel de Windows cargue las nuevas directivas de hardware y scheduler.
* **Resultados Inmediatos:**
  * Menor uso de CPU y memoria RAM en reposo (de 40 a 60 procesos innecesarios eliminados).
  * Eliminación de micro-tirones (*frame drops*) causados por la telemetría y recolección de datos de Windows.
  * Respuesta inmediata del ratón y teclado al eliminar suspensiones de energía y buffering de interrupciones.

### 5. Reversión a Stock en 1 Clic (Garantía 1:1)
Si en cualquier momento deseas volver exactamente a como estaba tu Windows de fábrica:
1. Abre Overlord y pulsa el botón **"Revertir a Stock"**.
2. Overlord leerá los respaldos originales, restaurará cada clave de registro, reactivará los servicios de fábrica y devolverá el plan de energía anterior. **Cero configuraciones rotas, cero cambios irreversibles.**

---

## 🔬 Diagnóstico de BIOS & Monitoreo en Vivo

Overlord incorpora un sistema de diagnóstico informativo de hardware en tiempo real:

* **⚡ Diagnóstico de XMP / EXPO de RAM:** Detecta si tu memoria RAM está corriendo a velocidad base de fábrica (JEDEC) en lugar de la velocidad máxima de tu kit. Si compraste memorias de 6000 MHz y corren a 4800 MHz, Overlord te avisará: `⚠️ XMP OFF` para que lo actives en tu BIOS y desbloquees entre un 10% y 20% de rendimiento gratis.
* **🎮 Estado de Resizable BAR (ReBAR / SAM):** Valida si tu GPU (AMD, NVIDIA o Intel) tiene asignado el bus PCIe de memoria grande (*Large Memory Range*). Si está apagado, te indica que actives *Above 4G Decoding* y *ReBAR* en tu BIOS.
* **🔥 Soporte Exclusivo AMD Ryzen X3D (Dual-CCD Steering):** En procesadores como Ryzen 9 7900X3D, 7950X3D, 9900X3D y 9950X3D, Overlord enruta el tráfico de red e interrupciones al CCD1 (núcleos de frecuencia), reservando el CCD0 (3D V-Cache) de forma exclusiva para los juegos.
* **🟢 Indicador del Daemon SYSTEM:** Monitorea en vivo al servicio residente en segundo plano que vigila las prioridades de tus juegos y confirma qué juego está siendo optimizado en tiempo real (ej. `Daemon: Activo · javaw.exe → Prioridad Alta`).
* **📜 Consola de Auditoría y Logs Integrada:** Un panel interactivo accesible en la UI que consume `read_overlord_log` y los logs del daemon en vivo, con historial cronometrado de cada módulo aplicado y botón de copiado en 1 clic para soporte técnico.

---

## 🧠 Filosofía de Ingeniería y Arquitectura del Sistema

A diferencia de optimizadores tradicionales basados en scripts destructivos de internet, **Overlord** opera bajo auditorías de bajo nivel basadas en la documentación oficial de la arquitectura de Windows NT. Elimina por completo modificaciones destructivas, tweaks placebo y cambios que corrompan el subsistema de seguridad o generen inestabilidades en el planificador del Kernel.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                        OVERLORD ARCHITECTURE                           │
 ├────────────────────────┬───────────────────────┬───────────────────────┤
 │   1. Frontend UI       │   2. Núcleo Rust      │   3. Motor PowerShell │
 │   Vue 3 + Pinia        │   Tauri v2 IPC        │   Ejecución en Memoria│
 │   Diagnóstico BIOS     │   Concurrencia Mutex  │   Sin residuos en HD  │
 │   Consola Logs/History │   Purga Standby NT    │   Respaldo 1:1        │
 └────────────────────────┴───────────────────────┴───────────────────────┘
```

### Pilares Fundamentales de la Arquitectura

- **Ejecución en Memoria RAM Pura (Sin Huella en Disco):** Los scripts de optimización principales nunca se escriben como archivos físicos en el disco. El motor Rust los codifica en UTF-16 LE y los transmite cifrados en Base64 directamente a través de `stdin` a un proceso PowerShell aislado que los decodifica y ejecuta en memoria mediante `Invoke-Expression`.
- **Codificador Base64 Nativo en Rust:** El executor implementa su propio codificador Base64 personalizado (`custom_base64_encode`) sin dependencias externas, operando directamente sobre los bytes UTF-16 del script unificado.
- **Mutex de Ejecución Concurrente:** Un `static EXECUTION_LOCK: Mutex<()>` en `executor.rs` garantiza que nunca se ejecuten dos módulos simultáneamente, evitando condiciones de carrera sobre las claves de registro de backup.
- **Resolución por SID Dinámico con Redundancia de 4 Niveles:** Al ejecutarse con privilegios elevados, Windows redirige `HKCU:` hacia la cuenta de Administrador. El motor de Overlord resuelve el SID real del usuario interactivo utilizando un esquema de fallback de 4 niveles (WMI -> Propietario de `explorer.exe` -> Traducción de clase `.NET NTAccount` -> Escaneo directo en `HKEY_USERS`), forzando la inyección en `Registry::HKEY_USERS\$UserSID`.
- **Inyección de Módulos Unificada:** El executor concatena en memoria el header de variables (`$IsLaptop`, `$RamGB`, `$GameList`, `$IsX3d`, `$IsSsd`, `$IsHybrid`), `utils.ps1` y `backup_manager.psm1` antes de cada script de módulo.

---

## 🛡️ Infraestructura de Seguridad y Respaldo Simétrico

### Sistema de Backup con Tipo de Dato Preservado (`backup_manager.psm1`)
La función `Backup-OverlordRegistryValue` almacena no solo el valor original de cada clave de registro, sino también su `ValueKind` nativo de Windows (DWord, REG_BINARY, REG_SZ, etc.) bajo una clave paralela con sufijo `_Kind`. La función `Restore-OverlordRegistryValue` recupera ambos y reconstruye el valor con su tipo exacto original.

El backup utiliza el marcador especial `_ABSENT_` para registrar claves que no existían de fábrica antes de Overlord, permitiendo al revert eliminarlas limpiamente en lugar de restaurar valores inventados.

### Punto de Restauración Forzado (`crear_respaldo.ps1`)
Antes de despachar cualquier módulo, el orquestador invoca obligatoriamente `crear_respaldo.ps1`, que levanta una instantánea VSS nativa del volumen del sistema (`Checkpoint-Computer`) tras verificar permisos de administrador y activar el servicio VSS.

---

## 🛠️ Desglose Técnico de Módulos de Optimización

### 1. Respuesta de Periféricos (`01_perifericos.ps1`)
- Activa **MSI Mode** (Message Signaled Interrupts) exclusivamente en **GPUs dedicadas** (Display Adapters) con prioridad Alta (`DevicePriority = 3`), eliminando stutters e interrupciones de línea compartida sin afectar controladores USB ni codecs de audio.
- Establece `Win32PrioritySeparation = 26` (0x1A): quantum de CPU interactivo corto y fijo con boost de 3:1 para garantizar la máxima respuesta del juego en primer plano.
- Desactiva la aceleración del puntero (`MouseSpeed = 0`, `MouseThreshold1/2 = 0`), garantizando traducción 1:1 de movimiento físico a digital.
- Desactiva StickyKeys y optimiza la latencia mecánica del teclado a nivel de FilterKeys (AutoRepeatDelay a 200ms, AutoRepeatRate a 15ms).
- Deshabilita USB Selective Suspend via `powercfg` para eliminar micro-stutters causados por la suspensión automática de puertos USB del ratón y teclado.

### 2. Limpieza del Sistema - Debloat (`02_debloat.ps1`)
- Desinstala aplicaciones UWP redundantes preinstaladas del sistema (`Remove-AppxProvisionedPackage`).
- **Conserva intactos** `Microsoft.GamingApp`, `Microsoft.XboxApp`, `Microsoft.WindowsStickyNotes`, `Microsoft.Todos` y `Microsoft.BingSearch` (en Windows 11 24H2), blindando Xbox Game Pass, notas del usuario y el menú de inicio nativo.
- Desactiva Copilot y Cortana Consent via políticas de grupo.
- Deshabilita servicios de telemetría y diagnóstico innecesarios: `DiagTrack`, `dmwappushservice`, `Fax`, `RetailDemo`, `MapsBroker`, `RemoteRegistry`, preservando `SensorService` en laptops y equipos 2-en-1 para auto-rotación.
- Deshabilita procesos en segundo plano de Microsoft Edge (`StartupBoostEnabled = 0` y `BackgroundModeEnabled = 0`) para liberar de 150 a 250 MB de memoria RAM física.

### 3. Optimización de Red TCP/IP (`03_red.ps1`)
- Elimina el límite de throttling del planificador de red con `NetworkThrottlingIndex = 0xFFFFFFFF`.
- Mantiene activas las marcas de tiempo TCP (TCP Timestamps) para correcto cálculo de RTT y control de congestión.
- Establece la prioridad del programador a `SystemResponsiveness = 10` (90% para juegos en primer plano, 10% para procesos de fondo como Discord/Spotify).
- Desactiva el algoritmo de Nagle (`TcpAckFrequency = 1` y `TcpNoDelay = 1`) **estrictamente en interfaces Ethernet físicas activas**, preservando adaptadores virtuales y túneles VPN.
- **Preserva Flow Control** en Ethernet para evitar caídas de paquetes en switches saturados y deshabilita **Energy Efficient Ethernet (EEE)**.
- Desactiva Large Send Offload (**LSO**) y Receive Segment Coalescing (**RSC**) para erradicar el jitter.

### 4. Rendimiento de Kernel y Procesador (`04_rendimiento.ps1`)
- **Preserva MemoryCompression activa** para prevenir fallos OOM en escenarios multitarea, y **deshabilita Page Combining** en `MMAgent` para erradicar los ciclos de CPU gastados en deduplicación de RAM en segundo plano.
- Deshabilita `GameDVR_Enabled` en el `GameConfigStore` del usuario.
- Optimiza las directivas del Programador Multimedia (**MMCSS Games Task**): prioridad de CPU `High`, prioridad SFIO `High`, `GPU Priority = 8` y `Clock Rate = 10`.
- Inyecta `PowerThrottlingOff = 1` en sistemas de escritorio conectados a corriente AC para evitar estrangulamiento de procesos en background.

### 5. GPU, Pantalla y Compositor (`05_gpu_display.ps1`)
- Activa **HAGS** (Hardware Accelerated GPU Scheduling) con validación estricta de drivers y hardware moderno (filtrando GPUs legacy y drivers de máquinas virtuales VirtIO/VMware/VirtualBox para prevenir pantallas negras).
- Preserva **MPO** (Multiplane Overlay) activo por defecto para garantizar baja latencia con DirectScanout en modo ventana sin bordes y compatibilidad con AutoHDR.
- Deshabilita `GameBarPresenceWriter` a nivel de usuario (`AppCaptureEnabled = 0`) para evitar frametime spikes al iniciar juegos.

### 6. Afinidad IRQ y Enrutamiento AMD Ryzen X3D (`06_irq_affinity.ps1`)
- **Enrutamiento Inteligente para AMD Ryzen Dual-CCD X3D (7900X3D, 7950X3D, 9900X3D, 9950X3D):** Enruta las interrupciones del bus de red físico hacia el CCD1 (núcleos de frecuencia pura), manteniendo el CCD0 (3D V-Cache) 100% aislado y dedicado a los hilos de renderizado del juego.
- Desactiva **Interrupt Moderation** exclusivamente en adaptadores Ethernet físicos en PCs de escritorio (omitiendo Wi-Fi y laptops para evitar micro-spikes de latencia DPC).
- Preserva la gestión dinámica de los dispositivos de audio para evitar chasquidos o distorsión de sonido.

### 7. Almacenamiento y Sistema de Archivos (`07_almacenamiento.ps1`)
- Activa `NtfsDisableLastAccessUpdate = 1`, eliminando escrituras innecesarias en cada lectura de archivo.
- Desactiva nombres de archivo cortos MS-DOS 8.3 (`NtfsDisable8dot3NameCreation = 1`).
- Desactiva **Fast Startup** (`HiberbootEnabled = 0`) para asegurar reinicios limpios de Kernel.
- En desktop: desactiva hibernación completa liberando gigabytes del archivo `hiberfil.sys`.

### 8. Blindaje de Privacidad y Telemetría (`08_telemetria.ps1`)
- Detiene y deshabilita `DiagTrack`.
- Bloquea la salida de red de binarios espía (`CompatTelRunner.exe`, `DeviceCensus.exe`, `wsqmcons.exe`) con reglas de Firewall de Windows dedicadas (`Overlord_Block_`).
- Desactiva loggers WMI de telemetría y Windows Error Reporting (`WerFault.exe`).
- Desactiva Windows Recall e IA de captura constante de pantalla (`TurnOffUserCameraCapture = 1`, `DisableAIDataAnalysis = 1`).

### 9. Gestión de Energía (`09_energia.ps1`)
- Respalda el GUID del plan activo original antes de cualquier modificación.
- **En Desktop:** Inyecta y activa el esquema *Ultimate Performance* (`e9a42b02-d5df-448d-aa00-03f14749eb61`), deshabilita Core Parking y fija EPP a rendimiento máximo (`0`).
- **En Laptop:** Configura la gestión de energía sin desactivar las protecciones térmicas del chasis móvil.

### 10. Prioridad Dinámica de Juegos (`manage_priority_service.ps1`)
- Servicio residente como Tarea Programada de Windows elevada a nivel `SYSTEM` con ACLs blindadas.
- Monitorea cada 15 segundos los juegos seleccionados por el usuario y eleva su prioridad a `High`.
- En CPUs AMD Ryzen Dual-CCD X3D, fija la máscara de afinidad del juego al CCD0 (3D V-Cache).
- Cuenta con desinstalación simétrica 1:1 en `10_revertir.ps1` (detiene proceso, elimina archivos y borra la tarea programada).

### 11. Desactivación de Mitigaciones de CPU (`disable_mitigations.ps1`)
- Desactiva mitigaciones Spectre (v2), Meltdown, SSBD y L1TF (`FeatureSettingsOverride = 8259`).
- Opcional con advertencia explícita en la UI para recuperar hasta 15% de throughput de CPU en procesadores antiguos.

---

## ⚡ Acciones Rápidas (Quick Actions)

* **Purgar RAM:** Vaciado nativo de la lista de espera (Standby List) en memoria física mediante la API NT indocumentada de Windows `SystemMemoryListInformation` sin provocar fallos de página ni vaciar el working set del juego.
* **Limpieza Profunda:** Limpieza de archivos temporales del sistema y eliminación de cachés de sombreadores corruptos de DirectX, NVIDIA y AMD para erradicar micro-stutters gráficos.
* **Reparar Sistema:** Ejecución secuencial de DISM y SFC con preservación de transacciones en segundo plano.
* **Liberar Red (DNS):** Limpieza de caché DNS y optimización de catálogos Winsock preservando IPs y DNS estáticos.

---

## 💻 Entorno de Desarrollo Local

### Prerrequisitos
- **Node.js** v20 o superior con `npm`
- **Rust Toolchain** estable via `rustup` (`x86_64-pc-windows-msvc`)
- **C++ Build Tools** de Visual Studio (MSVC)

### Comandos de Compilación y Calidad

```bash
# Instalar dependencias
npm install

# Ejecutar verificación de tipos y bundle frontend
npx vue-tsc --noEmit
npm run build

# Compilar y probar backend Rust
cd src-tauri
cargo check
cargo clippy -- -W clippy::all
cargo test

# Ejecutar suite de pruebas Pester
powershell -Command "Invoke-Pester src-tauri/tests/modules.tests.ps1"

# Modo Desarrollo
npm run tauri dev
```

---

## ⚠️ Compromiso de Cero Daño y Reversibilidad

1. **Sin Placebos ni Claves Muertas:** Cada tweak está auditado contra la documentación interna de Microsoft y verificado en hardware real.
2. **Reversibilidad 100% Simétrica (1:1):** Cada escritura tiene su lectura previa de respaldo. Lo que no existía de fábrica se elimina físicamente al revertir.
3. **Overlord jamás corrompe Windows:** No elimina Windows Update, no rompe Windows Defender, no borra archivos de sistema y valida componentes en cada paso.
