<div align="center">
  <img src="overlord_icon.png" alt="Overlord Logo" width="120">

# OVERLORD (v4.5.0)

**Suite Avanzada de Optimización, Privacidad y Reducción de Latencia de Bajo Nivel para Windows 10 y 11.**

Una suite de ingeniería orientada al rendimiento competitivo, depuración profunda del sistema operativo y eliminación del retraso de entrada (_input lag_), impulsada por un núcleo asíncrono no bloqueante en Rust, scripts de automatización ejecutados en memoria RAM vía Base64 cifrado, y una interfaz fluida construida sobre Vue 3, Tailwind CSS y Pinia.

[![Vue.js](https://img.shields.io/badge/Vue%203-35495E?style=for-the-badge&logo=vue.js&logoColor=4FC08D)](https://vuejs.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![Tauri](https://img.shields.io/badge/Tauri-FFC131?style=for-the-badge&logo=tauri&logoColor=white)](https://tauri.app/)
[![Rust](https://img.shields.io/badge/Rust-000000?style=for-the-badge&logo=rust&logoColor=white)](https://www.rust-lang.org/)
[![PowerShell](https://img.shields.io/badge/PowerShell_5.1-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://docs.microsoft.com/powershell/)

</div>

<hr>

<div align="center">
  <img src="/src/assets/overlordPanel.png" alt="Overlord UI" width="800"/>
</div>

---

## 🧠 Filosofía de Ingeniería y Arquitectura del Sistema

A diferencia de las utilidades de optimización tradicionales, **Overlord v4.5.0** opera bajo auditorías de bajo nivel basadas en la documentación oficial de la arquitectura de Windows NT. Elimina por completo modificaciones destructivas, tweaks placebo y cambios que corrompan el subsistema de seguridad o generen inestabilidades en el planificador del Kernel. Cada módulo verifica el resultado de cada escritura en registro mediante comprobaciones explícitas que lanzan excepciones ante cualquier fallo.

### Pilares Fundamentales de la Arquitectura

- **Ejecución en Memoria RAM Pura (Sin Huella en Disco):** En v4.5.0, los scripts nunca se escriben como archivos físicos en el disco. El motor Rust los codifica en UTF-16 LE y los transmite cifrados en Base64 directamente a través de `stdin` a un proceso PowerShell aislado que los decodifica y ejecuta en memoria mediante `Invoke-Expression`. Al terminar, no queda ningún artefacto en el sistema de archivos del usuario, eliminando vectores de secuestro de archivos (_File Hijacking_).

- **Codificador Base64 Nativo en Rust:** El executor implementa su propio codificador Base64 personalizado (`custom_base64_encode`) sin dependencias externas, operando directamente sobre los bytes UTF-16 del script unificado. Esto garantiza compatibilidad exacta con el decodificador `[System.Convert]::FromBase64String` de PowerShell sin depender de crates de terceros.

- **Mutex de Ejecución Concurrente:** Un `static EXECUTION_LOCK: Mutex<()>` en `executor.rs` garantiza que nunca se ejecuten dos módulos simultáneamente, evitando condiciones de carrera sobre las claves de registro de backup.

- **Resolución por SID Dinámico con Redundancia de 4 Niveles:** Al ejecutarse con privilegios elevados, Windows redirige `HKCU:` hacia la cuenta de Administrador. El motor de Overlord resuelve el SID real del usuario interactivo utilizando un esquema de fallback de 4 niveles (WMI -> Propietario de `explorer.exe` -> Traducción de clase `.NET NTAccount` -> Escaneo directo en `HKEY_USERS` de claves con entorno volátil activo), forzando la inyección en `Registry::HKEY_USERS\$UserSID` en los scripts QoL. Esto garantiza compatibilidad absoluta en sistemas optimizados o recortados con el subsistema WMI/CIM corrompido.

- **Inyección de Módulos Unificada:** El executor concatena en memoria el header de variables (`$IsLaptop`, `$RamGB`, `$GameList`), `utils.ps1` y `backup_manager.psm1` antes de cada script de módulo, garantizando que las funciones de backup siempre estén disponibles sin importar el contexto de ejecución.

- **Puente IPC Sanitizado:** Los argumentos dinámicos como listas de videojuegos pasan por filtros de caracteres que neutralizan vectores de inyección de comandos locales (_Local Command Injection_), escapando comillas simples antes de insertarlos en el script unificado.

- **Telemetría Asíncrona No Bloqueante:** El bucle de monitoreo de hardware utiliza el temporizador asíncrono nativo de Tokio, evitando `thread::sleep` bloqueantes que congelen el hilo principal de la aplicación Tauri.

- **Detección de Hardware Asíncrona No Bloqueante:** Para evitar retardos de hasta 2 segundos durante el arranque de la interfaz gráfica, la detección de la velocidad física de la memoria RAM (que anteriormente realizaba una consulta WMI/CIM síncrona lenta a través de PowerShell) se delega a un hilo de fondo en Rust de forma asíncrona mediante variables atómicas. El frontend carga al instante y actualiza reactivamente la frecuencia en MHz tras 3 segundos, eliminando demoras visuales.

---

## 🛡️ Infraestructura de Seguridad y Respaldo Simétrico

### Sistema de Backup con Tipo de Dato Preservado (`backup_manager.psm1`)

La función `Backup-OverlordRegistryValue` intercepta y almacena no solo el valor original de cada clave de registro, sino también su `ValueKind` nativo de Windows (DWord, REG_BINARY, REG_SZ, etc.) bajo una clave paralela con sufijo `_Kind`. La función `Restore-OverlordRegistryValue` recupera ambos y reconstruye el valor con su tipo exacto original, garantizando que máscaras binarias de afinidad IRQ, curvas de ratón y otros valores binarios no se corrompan como cadenas planas durante el revert.

El backup utiliza el marcador especial `_ABSENT_` para registrar claves que no existían antes de Overlord, permitiendo al revert eliminarlas limpiamente en lugar de restaurar un valor incorrecto.

### Punto de Restauración Forzado (`crear_respaldo.ps1`)

Antes de despachar cualquier módulo, el orquestador invoca obligatoriamente `crear_respaldo.ps1`, que levanta una instantánea VSS nativa del volumen del sistema (`Checkpoint-Computer`) tras verificar permisos de administrador, activar el servicio VSS y forzar `SystemRestorePointCreationFrequency = 0` para saltarse la limitación de un punto cada 24 horas.

En caso de inestabilidad, el revert lee la colmena aislada `HKLM:\SOFTWARE\Overlord\Backup` y realiza un rollback simétrico completo: restaura cada valor de registro a su estado exacto previo, restablece los tipos de dato originales via `_Kind`, devuelve el plan de energía activo guardado en backup, reactiva servicios según sus `StartupType` de fábrica, y notifica al usuario antes de reiniciar el shell del explorador.

### Suite de Pruebas Unitarias (`modules.tests.ps1`)

Las validaciones de tipos de datos, existencia de claves de Kernel modificadas y consistencia del sistema de backup están automatizadas bajo el framework **Pester v5**.

---

## 🛠️ Desglose Técnico de Módulos de Optimización (v4.5.0)

### 1. Respuesta de Periféricos (`01_perifericos.ps1`)

- Activa **MSI Mode** (Message Signaled Interrupts) en GPU, controladores USB y controladores de audio (Class MEDIA/AudioEndpoint) recorriendo el árbol PCI completo mediante la API nativa `Microsoft.Win32.Registry` y configura la prioridad de interrupción a Alta (`DevicePriority = 3`) bajo la directiva de política de afinidad, eliminando interrupciones de línea compartida (IRQ sharing) y pops/stutters de sonido bajo carga.
- Establece `Win32PrioritySeparation = 26` (0x1A): quantum de CPU interactivo corto y fijo con boost de 3:1 para garantizar la máxima respuesta del juego en primer plano y evitar micro-stutters generados por procesos en segundo plano.
- Desactiva la aceleración del puntero (`MouseSpeed = 0`, `MouseThreshold1/2 = 0`), garantizando traducción 1:1 de movimiento físico a digital.
- Desactiva StickyKeys y ToggleKeys para evitar interrupciones de accesibilidad involuntarias durante el juego, y optimiza la latencia mecánica y velocidad de repetición del teclado a nivel de FilterKeys (AutoRepeatDelay a 200ms, AutoRepeatRate a 15ms y DelayBeforeAcceptance a 0ms).
- Deshabilita USB Selective Suspend via `powercfg` para eliminar los micro-stutters causados por la suspensión automática de puertos USB del ratón y teclado.

### 2. Limpieza del Sistema - Debloat (`02_debloat.ps1`)

- Desinstala aplicaciones UWP redundantes preinstaladas tanto del perfil activo como del aprovisionamiento del sistema (`Remove-AppxProvisionedPackage`).
- **Conserva intactos** `Microsoft.GamingApp` y `Microsoft.XboxApp`, blindando Xbox Game Pass, Auto HDR y Xbox Game Bar.
- Deshabilita búsqueda Bing integrada en el menú inicio y Cortana Consent.
- Desactiva Copilot tanto a nivel de usuario como de sistema via políticas de grupo.
- Deshabilita y detiene servicios de telemetría, diagnóstico y red innecesarios: `DiagTrack`, `dmwappushservice`, `Fax`, `RetailDemo`, `MapsBroker`, `PhoneSvc`, `AJRouter` (enrutador IoT), `WpcMonSvc` (control parental), `TrkWks` (Distributed Link Tracking Client), `RemoteRegistry` (registro remoto), `WdiServiceHost` y `WdiSystemHost` (servicios de diagnóstico) y `SensorService` (en computadoras de escritorio).
- Deshabilita de forma estructural los servicios y procesos en segundo plano de Microsoft Edge (`StartupBoostEnabled = 0` y `BackgroundModeEnabled = 0`) para erradicar procesos huérfanos y liberar de 150 a 250 MB de memoria RAM física.
- Desactiva de forma global los permisos de ejecución de aplicaciones UWP en segundo plano (`GlobalUserDisabled = 1`) para evitar el consumo fantasma de CPU y RAM de la tienda Store.
- Deshabilita 16 tareas programadas de telemetría, diagnóstico, CEIP, informes de errores, mapas y de monitoreo familiar.
- **Advertencia de reversión:** La desinstalación de aplicaciones AppX es semi-permanente; la reversión intenta volver a registrarlas localmente desde el almacén de WindowsApps, pero no garantiza su descarga de la nube.

### 3. Optimización de Red TCP/IP (`03_red.ps1`)

- Elimina el límite de throttling del planificador de red con `NetworkThrottlingIndex = 0xFFFFFFFF`, permitiendo que la pila TCP/IP procese todos los paquetes disponibles en cada intervalo sin restricción artificial.
- Mantiene activas las marcas de tiempo TCP (TCP Timestamps) para asegurar un correcto control de congestión, cálculo de RTT y escalamiento de ventana TCP en conexiones modernas de alta velocidad.
- Establece la prioridad de reserva del programador de Windows a un balance óptimo (`SystemResponsiveness = 10`), reservando el 90% para juegos en primer plano y dejando el 10% para procesos de fondo, lo cual previene micro-cortes y stutters en Discord, Spotify y navegadores mientras se juega.
- Desactiva el algoritmo de Nagle (`TcpAckFrequency = 1` y `TcpNoDelay = 1`) en interfaces de red activas para bajar el ping drásticamente en juegos competitivos.
- Deshabilita **Energy Efficient Ethernet (EEE)** y **Green Energy** para evitar micro-cortes de conexión. Desactiva la **Coalescencia de Paquetes** (`*PacketCoalescing = 0`, `PacketCoalescing = 0`) de forma **adaptativa** (solo en computadoras de escritorio con más de 8 hilos lógicos, omitiéndose en portátiles y procesadores modestos para prevenir stutters por sobrecarga de interrupciones en la CPU).
- Desactiva Large Send Offload (**LSO**) y Receive Segment Coalescing (**RSC**) para evitar ráfagas de paquetes que inducen jitter y micro-cortes de red.
- Establece el perfil RSS en adaptadores de red a **Closest** para direccionar las interrupciones al núcleo de CPU más cercano al hardware, reduciendo la latencia DPC y fallos de caché L3.
- Reduce el tiempo de retransmisión TCP a **InitialRto = 2000** (default 3000ms) para una recuperación instantánea ante pérdida de paquetes.
- Apaga la moderación de interrupciones (`InterruptModeration = 0`) y el control de flujo (`FlowControl = 0`) de forma adaptativa en PCs de escritorio con más de 8 hilos lógicos para habilitar respuestas de hardware instantáneas.

### 4. Rendimiento de Kernel y Procesador (`04_rendimiento.ps1`)

- Gestiona `MMAgent MemoryCompression`: la deshabilita en sistemas con 32 GB o más donde el overhead de compresión supera el beneficio; la mantiene activa en sistemas con menos RAM.
- Deshabilita de forma universal el Page Combining en `MMAgent` para evitar que Windows gaste ciclos de reloj en segundo plano deduplicando páginas de memoria RAM, eliminando micro-stutters esporádicos en partidas de alta intensidad.
- Deshabilita `GameDVR_Enabled` en the `GameConfigStore` del usuario, eliminando el overhead del sistema de captura de Xbox.
- Optimiza las directivas del Programador Multimedia (**MMCSS Games Task**): asigna prioridad de CPU `High` (Scheduling Category), prioridad SFIO `High`, `Priority = 6`, `GPU Priority = 8` y `Clock Rate = 10` para garantizar cuadros estables (1% Low FPS) sin interferencia de procesos en segundo plano.

### 5. GPU, Pantalla y Compositor (`05_gpu_display.ps1`)

- Activa **HAGS** (Hardware Accelerated GPU Scheduling) con `HwSchMode = 2`, habilitando compatibilidad con DLSS 3 Frame Generation y mejorando frametimes en GPUs modernas.
- Preserva **MPO** (Multiplane Overlay) activo por defecto para beneficiar la latencia de entrada y aceleración gráfica por hardware en aplicaciones y juegos en ventana sin bordes.
- Deshabilita `GameBarPresenceWriter` a nivel de usuario (`AppCaptureEnabled = 0` en HKCU) para neutralizar procesos de grabación intrusivos en segundo plano de Xbox, previniendo frametime spikes y micro-stutters al iniciar cualquier videojuego.
- Deshabilita `AllowGameDVR` via política de grupo, bloqueando el sistema de captura a nivel de políticas.
- En sistemas con 6 GB de RAM o menos: deshabilita transparencias del compositor (`EnableTransparency = 0`) para liberar ancho de banda de GPU.

### 6. Afinidad IRQ (`06_irq_affinity.ps1`)

- Recorre el árbol PCI completo via `Microsoft.Win32.Registry` para aislar dinámicamente los hilos de interrupción de **adaptadores de red** (`Class = Net`) fuera del Core 0. Implementa una **política multi-núcleo selectiva compatible con RSS** (`DevicePolicy = 2` - *SpecifiedProcessors*) direccionando las interrupciones a dos cores físicos independientes (hilos lógicos 4 y 6 en CPUs >=12 hilos, o hilos lógicos 2 y 4 en CPUs >=8 hilos) evitando hilos lógicos hermanos (SMT/HT). Esto previene stutters en aplicaciones secundarias y cuellos de botella de ancho de banda en descargas de alta velocidad (Gigabit+).
- Preserva la gestión dinámica de los **dispositivos de audio** (`Class = MEDIA`) a cargo del programador de Windows, previniendo distorsión de sonido, pops o micro-cortes en Discord/juegos cuando un núcleo afinado estáticamente se satura.

### 7. Almacenamiento y Sistema de Archivos (`07_almacenamiento.ps1`)

- Activa `NtfsDisableLastAccessUpdate = 1` via registro, eliminando escrituras innecesarias en cada lectura de archivo.
- Desactiva la creación de nombres de archivo cortos en formato MS-DOS 8.3 (`NtfsDisable8dot3NameCreation = 1`) a nivel global, aumentando la velocidad de operaciones en disco NTFS.
- Configura la asignación de memoria de caché de metadatos NTFS a modo de alto rendimiento (`NtfsMemoryUsage = 2`) de forma adaptativa en sistemas que cuenten con un mínimo de **16 GB de RAM** para optimizar el acceso a directorios grandes.
- Desactiva **Fast Startup** (`HiberbootEnabled = 0`), evitando el estado inconsistente de drivers entre sesiones que puede impedir que los tweaks de registro surtan efecto correctamente tras el reinicio.
- En desktop: desactiva hibernación completa para liberar el espacio del `hiberfil.sys`.
- Ejecuta `DISM /Cleanup-Image /StartComponentCleanup` con protección de procesos para compactar el store de componentes de Windows.
- Limpia descargas de Windows Update verificando primero que no haya una instalación activa via `Microsoft.Update.Installer.IsBusy`.
- Limpia caché de Delivery Optimization y carpetas temporales del sistema.

### 8. Blindaje de Seguridad y Privacidad (`08_telemetria.ps1`)

- Detiene y deshabilita `DiagTrack` (Connected User Experiences and Telemetry).
- Bloquea la salida de red de los binarios de telemetría (`CompatTelRunner.exe`, `DeviceCensus.exe`, `wsqmcons.exe`) mediante reglas de firewall de salida nombradas con el prefijo `Overlord_Block_`.
- Desactiva los loggers WMI de telemetría: `AutoLogger-Diagtrack-Listener`, `SQMLogger`, `DiagLog`, `AitEventLog`.
- Desactiva `PublishUserActivities` (historial de actividad y Timeline de Windows).
- Inyecta la directiva global de deshabilitación de Windows Error Reporting (`Disabled = 1`) en el registro de políticas de Windows para evitar que el spawn secundario del proceso `WerFault.exe` consuma CPU o interrumpa el juego al ocurrir fallos inesperados.

### 9. Gestión de Energía (`09_energia.ps1`)

- Guarda backup del GUID del plan de energía activo en `HKLM:\SOFTWARE\Overlord\Backup\Power\ActivePowerPlan` antes de cualquier cambio, garantizando que el revert devuelva el plan original exacto.
- **En desktop:** Desbloquea e inyecta el esquema de _Ultimate Performance_ (`e9a42b02-d5df-448d-aa00-03f14749eb61`). Si no existe en el sistema, clona dinámicamente el plan de Alto Rendimiento (o el plan Equilibrado como fallback garantizado si el primero fue eliminado de la ISO) y guarda el GUID del duplicado para el revert. Desactiva Core Parking y fuerza los límites de Core Parking a cero.
- **Optimización Energética de Escritorio (Fase 6):** Configura la preferencia de energía de CPU (EPP) a rendimiento máximo (`0`), activa el Processor Boost Mode a agresivo (`2`), apaga la suspensión o timeout de discos duros (`0` - Nunca) y deshabilita la directiva global de estrangulamiento de energía (**Power Throttling**) del Kernel para evitar la estrangulación eléctrica de herramientas activas en segundo plano como OBS Studio o Discord.
- **En laptop:** Optimiza el control térmico configurando el índice de gestión del procesador via `powercfg` sin deshabilitar las protecciones de ahorro de energía, preservando la integridad térmica.

### 10. Prioridad Absoluta para Juegos (`11_game_hooks.ps1`)

- Recibe la lista de ejecutables de juegos detectados desde el frontend y aplica directivas IFEO (`Image File Execution Options`) personalizadas a cada uno.
- Ajusta `CpuPriorityClass` de forma adaptativa según la topología del sistema: prioridad **Alta (3)** en sistemas con más de 6 cores; prioridad **AboveNormal (6)** en laptops o sistemas con 5-6 cores; prioridad **Normal (2)** en sistemas con 4 cores o menos, evitando penalizar el sistema en hardware limitado.
- Asigna `IoPriority = 3` (Alta) para lecturas de disco preferentes.
- Inyecta la invalidación de escalado de PPP (High DPI) para eliminar la latencia por reescalado de pantalla y conserva las optimizaciones modernas de DirectX en modo ventana maximizada.
- **Servicio de Prioridades Dinámico en Segundo Plano:** Crea una Tarea Programada de Windows elevada a nivel de `SYSTEM` que ejecuta un daemon de PowerShell (`priority_monitor_daemon.ps1`) en un bucle discreto cada 15 segundos para aplicar prioridad de CPU alta a los juegos configurados de forma automática, incluso sin tener la interfaz de Overlord abierta.

### 11. Desactivación de Mitigaciones de CPU (`disable_mitigations.ps1`)

- Desactiva las mitigaciones Spectre (v2) y Meltdown (`FeatureSettingsOverride = 3` y `FeatureSettingsOverrideMask = 3`) a nivel de Kernel en la colmena Memory Management de HKLM.
- **Caso de uso**: Recupera de un 10% a un 15% de throughput de CPU en procesadores legacy (Intel Core de 9.ª generación o anterior, y AMD Ryzen serie 3000 o anterior) que se ven ralentizados por los parches de seguridad de microcódigo.
- Cuenta con respaldo y reversión simétrica en el desinstalador para restablecer las directivas de seguridad nativas del Kernel de Windows.

---

El script `set_qol.ps1` orquesta 21 modificaciones inmediatas de experiencia de usuario y privacidad, cada una bajo bloques `Try/Catch` independientes. Resuelve el SID del usuario interactivo real mediante la cadena de resiliencia de 4 niveles antes de aplicar cambios en `HKCU:`, garantizando que los cambios lleguen al perfil correcto.

**Interfaz y apariencia:**
* **Modo Oscuro Global**: Fuerza el tema oscuro nativo en aplicaciones y el shell de Windows.
* **Rendimiento Visual (Barebones)**: Desactiva animaciones de ventanas y menús, sombras y transparencias para máximo rendimiento visual, **preservando el suavizado de fuentes ClearType** para mantener el texto legible.
* **Mostrar Extensiones de Archivo** y **Mostrar Archivos Ocultos**: Hace visibles formatos ocultos y extensiones en File Explorer.
* **Menú Contextual Clásico de Windows 11**: Recupera el menú del clic derecho clásico. En compilaciones de Windows 11 >= 26000, emite una advertencia informando sobre la necesidad de ExplorerPatcher o StartAllBack.
* **Barra de Tareas Alineada a la Izquierda** y **Inicio Directo en "Este Equipo"** (evitando historial de carga y red).
* **Alt+Tab Limpio**: Oculta pestañas abiertas del navegador Edge.

**Privacidad y sistema:**
* **Deshabilitar Búsqueda Bing y Cortana**: Escribe políticas globales e inyecta `BingSearchEnabled = 0` y `CortanaConsent = 0` bajo `HKCU:\Software\Microsoft\Windows\CurrentVersion\Search` para desactivar búsquedas de Bing en el Inicio en cualquier edición de Windows.
* **Ocultar Pantalla de Bloqueo** y **Desactivar Anuncios del Explorador**.
* **Ocultar "Terminemos de Configurar" (Scoobe)**: Bloquea las pantallas de bienvenida intrusivas e inyecta políticas de bloqueo de sugerencias de Microsoft en `ContentDeliveryManager`.
* **Erradicar MS Copilot** y **Bloquear Windows Recall** (capturas constantes de pantalla e IA).
* **Erradicar OneDrive**: Desinstala y bloquea la sincronización automática I/O.
* **Erradicar Widgets**: Remueve el panel de noticias de la barra de tareas, liberando entre 150-300MB de RAM por procesos WebView2 en segundo plano.
* **Pantallazo Azul Detallado**: Muestra códigos de error reales en BSODs.

**Gaming y Atajos:**
* **Modo Juego**: Activa la prioridad de hilos de procesos de juegos y **desactiva la grabación en segundo plano de GameDVR** (captura de pantalla y de audio) para evitar stutters y overhead de CPU/GPU.
* **Desactivar Sticky Keys** y **Teclas Filtro**: Evita la minimización accidental de partidas competitivas por alertas repetidas de la tecla Shift.
* **Cero Retraso de Arranque**: Reduce el retardo de inicio para aplicaciones del sistema.

---

## ⚡ Acciones Rápidas (Quick Actions)

La interfaz gráfica permite ejecutar acciones correctivas e integradas:
* **Purgar RAM**: Libera la memoria en espera de forma nativa a través de llamadas de Rust sin vaciar sets de trabajo (evitando page faults).
* **Limpieza Profunda**: Ejecuta `cleanmgr` bajo banderas especiales, vacía directorios temporales mediante llamadas rápidas por lotes en disco, y **limpia las cachés de shaders de DirectX (D3D/Nvidia/AMD)** para mitigar tirones de FPS en juegos 3D.
* **Reparar Sistema**: Corre DISM y SFC secuencialmente. Habilita e inicia de forma temporal el servicio de Windows Update (`wuauserv`) si este se encuentra deshabilitado para permitir la descarga de archivos limpios, regresándolo a su estado original al finalizar.
* **Liberar Red (DNS)**: Restablece catálogos de red, Winsock y flushea el DNS.

---

## ⚡ Ejecución Portátil Inmediata — Sin Instalación

Overlord implementa una arquitectura de **huella cero** que no requiere instaladores ni deja residuos en el sistema. Para levantar la suite directamente en memoria desde la nube, abra **PowerShell como Administrador** y ejecute:

```powershell
irm https://raw.githubusercontent.com/lordforcuadd/Overlord/main/launch.ps1 | iex
```

**Mecanismo de despliegue:**

1. `irm` (_Invoke-RestMethod_) descarga en memoria el orquestador de lanzamiento.
2. `launch.ps1` consulta la API pública de GitHub (`api.github.com/repos/lordforcuadd/Overlord/releases/latest`) para obtener dinámicamente la URL exacta del binario `.exe` del release más reciente, haciendo el comando inmune a cambios de versión.
3. Descarga el ejecutable en un directorio temporal aislado (`$env:TEMP\OverlordSuite`) y lo ejecuta con el puente IPC elevado de Tauri.
4. Al cerrar la UI, el script elimina forzosamente el directorio temporal, garantizando un entorno limpio sin residuos físicos.

> **Importante:** Antes de desinstalar Overlord o perder acceso al comando de lanzamiento, usa el botón **Revertir** desde la interfaz. Los cambios de Overlord quedan activos en el sistema incluso sin la aplicación; el backup en registro (`HKLM:\SOFTWARE\Overlord\Backup`) persiste y puede ser restaurado relanzando Overlord en cualquier momento.

---

## 💻 Entorno de Desarrollo Local

### Prerrequisitos

- **Node.js** v18 o superior con `npm`
- **Rust Toolchain** estable via `rustup` apuntando al objetivo `x86_64-pc-windows-msvc`
- **C++ Build Tools** de Visual Studio (MSVC)

### Comandos

```bash
# Instalar dependencias del frontend
npm install

# Entorno de desarrollo con Hot Module Replacement
npm run tauri dev

# Compilar binario de producción
npm run tauri build
```

El binario resultante se genera en:

```
src-tauri\target\release\bundle\nsis\
```

---

## ⚠️ Consideraciones Importantes

- Requiere **PowerShell 5.1** y ejecución como **Administrador**.
- Varios módulos requieren **reinicio** para tener efecto completo: MSI Mode, HAGS y las mitigaciones Spectre/Meltdown.
- La desactivación de mitigaciones **Spectre/Meltdown** es ahora un módulo independiente opcional. Esto representa un tradeoff de seguridad documentado por Microsoft orientado a maximizar throughput en entornos de un solo usuario, por lo que debe aplicarse con criterio.
- Overlord **nunca** modifica archivos del sistema, desinstala Windows Update, elimina Windows Defender ni toca componentes de seguridad sin advertencia explícita al usuario.
