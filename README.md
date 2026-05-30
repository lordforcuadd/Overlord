<div align="center">
  <img src="overlord_icon.png" alt="Overlord Logo" width="120">
  
  # OVERLORD (v3.0)
  **Sistema Avanzado de Optimización, Gestión de Privacidad y Reducción de Latencia de Bajo Nivel para Windows 10 y 11.**
  
  Una suite de ingeniería orientada al rendimiento competitivo, depuración avanzada del sistema operativo y anulación del retraso de entrada (*input lag*), impulsada por un núcleo asíncrono no bloqueante en Rust, scripts sintonizados para Windows PowerShell 5.1 y una interfaz fluida basada en Vue 3, Tailwind CSS y Pinia.

[![Vue.js](https://img.shields.io/badge/Vue%203-35495E?style=for-the-badge&logo=vue.js&logoColor=4FC08D)](https://vuejs.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![Tauri](https://img.shields.io/badge/Tauri-FFC131?style=for-the-badge&logo=tauri&logoColor=white)](https://tauri.app/)
[![Rust](https://img.shields.io/badge/Rust-000000?style=for-the-badge&logo=rust&logoColor=white)](https://www.rust-lang.org/)

</div>

<hr>

<div align="center">
  <img src="/src/assets/overlordPanel.png" alt="Overlord UI" width="800"/>
</div>

## 🧠 Filosofía de Ingeniería y Arquitectura del Sistema

A diferencia de las utilidades tradicionales de optimización distribuidas de forma ciega en internet, **Overlord v3.0** se rige bajo estrictas auditorías de bajo nivel basadas en la documentación oficial de la arquitectura de Windows NT. Omite por completo modificaciones destructivas o tweaks placebo que corrompan el subsistema de seguridad o generen inestabilidades en el planificador del Kernel.

### Pilares Fundamentales del Núcleo Nativo

- **Resolución por SID Dinámico:** Al ejecutarse con privilegios elevados, Windows mapea el alcance de la colmena `HKCU:` hacia la cuenta de Administrador. El motor de Overlord intercepta el SID real del usuario interactivo a través de consultas CIM nativas, forzando la inyección directa en `Registry::HKEY_USERS\$UserSID`. Esto garantiza que los cambios surtan efecto inmediato en el perfil de usuario correcto.
- **Incrustación Estática de Recursos:** Mediante la macro de compilación `include_str!` en Rust, la totalidad de los scripts de automatización se inyectan como cadenas estáticas dentro del binario único. El orquestador genera directorios temporales aislados con marcas de tiempo en nanosegundos, vuelca los scripts con marcas de orden de bytes (_BOM UTF-8_) y purga el espacio inmediatamente al finalizar, anulando vectores de secuestro de archivos (_File Hijacking_).
- **Telemetría Asíncrona No Bloqueante:** Implementa un bucle coordinado a través de Pinia que interroga concurrentemente al backend mediante comandos de Tauri. El backend procesa las llamadas de uso de CPU y RAM utilizando el temporizador asíncrono nativo de Tokio, evitando llamadas bloqueantes (`thread::sleep`) que congelen el hilo principal de la aplicación.
- **Puente IPC Sanitizado:** La comunicación frontend-backend cuenta con filtros estrictos de caracteres alfanuméricos en cadenas de argumentos dinámicas (como listas de videojuegos), neutralizando de forma matemática cualquier vector de inyección de comandos locales (_Local Command Injection_).

---

## 🛠️ Desglose Técnico de Módulos de Optimización

### 1. Respuesta de Teclado y Ratón (`01_perifericos.ps1`)

- **Mecánica Real:** Reconfigura el tamaño del búfer de intercambio intermedio de los controladores de clase nativos `mouclass` y `kbdclass` fijando `MouseDataQueueSize` y `KeyboardDataQueueSize` en el valor matemático balanceado de **32** (Hexadecimal `0x20`).
- **Impacto de Rendimiento:** Al alinearse limpiamente con el tamaño de las líneas de caché L1/L2 del procesador, previene el desbordamiento de búfer (_Input Drops_) y saltos del cursor bajo alta carga de CPU en ratones competitivos con tasas de sondeo elevadas de **4KHz u 8KHz**, garantizando una relación de traducción de movimiento físico a digital de $1:1$.

### 2. Limpieza del Sistema - Debloat (`02_debloat.ps1`)

- **Mecánica Real:** Remueve de raíz paquetes aprovisionados universales redundantes (_UWP_) mediante canalizaciones estrictas de `Remove-AppxProvisionedPackage`.
- **Impacto de Rendimiento:** **Conserva intactos** `Microsoft.GamingApp` y `Microsoft.XboxApp`, blindando el funcionamiento de Xbox Game Pass, Auto HDR y Xbox Game Bar (esencial para el planificador de hilos en CPUs AMD Ryzen X3D). Limpia telemetría básica sin corromper el servicio de búsqueda nativo.

### 3. Optimización de Red e Internet (`03_red.ps1`)

- **Mecánica Real:** Setea de forma mandatoria la persistencia de la caché DNS (`MaxCacheTtl`) al valor estándar óptimo de **86400 segundos** y el almacenamiento negativo a **0**. Desactiva las marcas de tiempo TCP (`timestamps=disabled`) y activa la coalescencia de recepción de segmentos (_RSC_).
- **Impacto de Rendimiento:** Al mantener el TTL en 86400 se evita la latencia generada por resoluciones DNS repetitivas durante el matchmaking. Desactivar marcas de tiempo elimina 12 bytes redundantes por encabezado de paquete reduciendo la fragmentación de tramas. _RSC_ disminuye drásticamente las interrupciones del CPU por segundo a nivel de tarjeta de red, mitigando la pérdida de paquetes (_packet loss_).

### 4. Potencia Bruta y Procesador (`04_rendimiento.ps1`)

- **Mecánica Real:** Modifica las opciones de memoria ejecutiva del Kernel (`DisablePagingExecutive`) de forma condicional solo en sistemas con **16 GB de RAM o más** y que no correspondan a entornos portátiles. Gestiona el MMAgent para deshabilitar la compresión de memoria física.
- **Impacto de Rendimiento:** Mantiene los drivers y el núcleo ejecutivo paginados directamente en la RAM física ultrarrápida, eliminando los tirones provocados por lecturas en el archivo de paginación del disco duro. Modifica el control de mitigaciones de vulnerabilidades de silicio (Spectre/Meltdown) mediante perfiles condicionales if-not-laptop, protegiendo la integridad térmica de portátiles.

### 5. Fluidez de Pantalla y Gráficos (`05_gpu_display.ps1`)

- **Mecánica Real:** Inyecta en el Kernel el valor oficial **2** en la directiva `HwSchMode` para forzar la activación de la Programación de GPU Acelerada por Hardware (HAGS) y eleva la prioridad del hilo del Administrador de Ventanas del Escritorio (`dwm.exe`) a **3** (Prioridad Alta).
- **Impacto de Rendimiento:** Al activar HAGS legítimamente, habilita la compatibilidad con tecnologías modernas como **DLSS 3 Frame Generation**. Elevar la prioridad de DWM a nivel Alta garantiza que el servidor gráfico de Windows mantenga el correcto _Frame Pacing_ y presentación de fotogramas, estabilizando los fotogramas mínimos (_1% Low FPS_) en escenarios donde la CPU llegue al 100% de uso.

### 6. Organización del Procesador - Afinidad IRQ (`06_irq_affinity.ps1`)

- **Mecánica Real:** Intercepta el árbol de instancias PCI para aislar los hilos de interrupción física de los adaptadores de red de alta velocidad, enrutándolos dinámicamente fuera del Core 0 mediante una máscara binaria calculada según la topología lógica detectada.
- **Impacto de Rendimiento:** Desahoga el núcleo principal del Kernel, mitigando picos severos de latencia DPC provocados por la llegada masiva de tramas de red concurrentes durante el procesamiento del renderizado del juego.

### 7. Aceleración de Disco y Smart Storage (`07_almacenamiento.ps1`)

- **Mecánica Real:** Interroga explícitamente el estado lúdico `.IsBoot` del almacenamiento raíz. Si detecta un **HDD mecánico**, configura _Prefetcher_ y _Superfetch (SysMain)_ en habilitado (`3`) para optimizar cargas secuenciales; si detecta un **SSD/NVMe**, los apaga por completo (`0`).
- **Impacto de Rendimiento:** Elimina ciclos constantes de escritura background en unidades sólidas prolongando la vida de las celdas flash. **Preserva de forma estricta** la carpeta `Minidump` y archivos `MEMORY.DMP` para no dejar desprotegido al usuario ante diagnósticos de pantallas azules. Cuenta con validación inteligente del estado ocupado (`IsBusy`) de Windows Update antes de purgar descargas corruptas.

### 8. Blindaje de Seguridad y Privacidad (`08_telemetria.ps1`)

- **Mecánica Real:** Erradica hilos de recolección de trazas y rastreadores unificados en tiempo real (`DiagTrack`). Detiene y bloquea mediante reglas de salida estrictas en el Firewall de Windows los binarios de recolección remota.
- **Impacto de Rendimiento:** Libera ciclos de procesamiento de CPU background al apagar los loggers circulares innecesarios. Muestra alertas transparentes y advertencias sobre el estado de la Seguridad Basada en Virtualización (_VBS / HVCI_), validando el estado del firmware UEFI mediante `Confirm-SecureBootUEFI`.

### 9. Energía Inteligente (`09_energia.ps1`)

- **Mecánica Real:** Realiza un respaldo dinámico previo del GUID del plan de energía activo de fábrica (`ActivePowerPlan`) antes de conmutar hilos. Desbloquea e inyecta el esquema oculto de Rendimiento Máximo (_Ultimate Performance_) exclusivamente en ordenadores de sobremesa.
- **Impacto de Rendimiento:** Mantiene los buses PCIe y el escalado de frecuencias de la CPU al máximo rendimiento eléctrico sostenido, mitigando latencias generadas por transiciones de ahorro energético (_C-States_ agresivos).

### 10. Prioridad Absoluta para Juegos (`11_game_hooks.ps1`)

- **Mecánica Real:** Inyecta directivas en el registro de opciones de ejecución de imágenes (_IFEO_) asignando de forma mandatoria la propiedad `CpuPriorityClass = 3` (Alta) e `IoPriority = 3` (Alta) a ejecutables competitivos detectados.
- **Impacto de Rendimiento:** Altera el planificador de Windows NT para otorgar mayores cuantos de tiempo (_Quantum_) a los procesos de juego cuando se encuentran en primer plano, estabilizando los _frametimes_.

---

### 🎛️ Ajustes Instantáneos QoL (Panel de 21 Interruptores)

El archivo `set_qol.ps1` orquesta modificaciones inmediatas de la experiencia de usuario y privacidad protegidas bajo bloques estructurados `Try/Catch` independientes:

- **Interfaz y UI:** Rendimiento Visual Barebones (remueve animaciones de ventanas), Modo Oscuro Global, Mostrar Extensiones de Archivo nativas, Menú Contextual Clásico tradicional de Windows 11, Barra de Tareas Alineada a la Izquierda y Pantallazos Azules Detallados (BSoD con parámetros de depuración extendidos).
- **Privacidad Absoluta:** Desactivación de sugerencias de búsqueda de Bing en el Inicio, bloqueo de anuncios de sincronización nativos en el explorador, deshabilitación de pantallas de bienvenida de experiencia inicial ("Scoobe"), bloqueo y purga estricta de telemetría e hilos asociados a MS Copilot y el sistema de capturas Recall.
- **Explorador y Gaming:** Inicio directo en "Este Equipo", erradicación del arranque y sincronización background automática de OneDrive, remoción completa del panel de Widgets (liberando RAM de procesos persistentes de WebView2) y reducción del retraso de arranque establecido en cero para almacenamiento sólido.

---

## ⚡ Ejecución Portátil Inmediata (Sin Instalación)

Overlord implementa una arquitectura de **huella cero** que no requiere asistentes locales ni almacena residuos en el sistema operativo del usuario. Para levantar la suite instantáneamente en memoria RAM desde la nube, abra **PowerShell como Administrador** e inyecte el comando de red:

```powershell
irm [https://raw.githubusercontent.com/lordforcuadd/Overlord/main/launch.ps1](https://raw.githubusercontent.com/lordforcuadd/Overlord/main/launch.ps1) | iex
```

````

### Mecanismo de Despliegue en Red:

1. El alias `irm` (_Invoke-RestMethod_) descarga en memoria el script remoto de orquestación.
2. `launch.ps1` interroga la API pública de GitHub (`api.github.com/repos/lordforcuadd/Overlord/releases/latest`) para interceptar de forma dinámica la ruta exacta del binario `.exe` del release más reciente, haciendo al comando inmune a cambios de versión.
3. Descarga el ejecutable en un directorio temporal aislado (`$env:TEMP\OverlordSuite`) y ejecuta el puente IPC elevado de Tauri.
4. Al cerrarse la UI, el script remueve de forma forzada el directorio temporal, garantizando un entorno limpio de residuos físicos.

---

## 💻 Configuración del Entorno de Desarrollo Local

Si deseas auditar, extender la lógica de los módulos de automatización o compilar los ejecutables de forma 100% local, configure su espacio de trabajo de la siguiente manera:

### Prerrequisitos del Entorno

- **Node.js:** Versión 18 o superior instalada de forma global junto con `npm`.
- **Rust Toolchain:** Cadena de herramientas estable instalada mediante `rustup` apuntando al objetivo nativo `x86_64-pc-windows-msvc`.
- **C++ Build Tools:** Herramientas de compilación nativas de Visual Studio (MSVC C++) configuradas en el sistema.

### Comandos de Inicialización y Depuración en Vivo

Instale las dependencias de Node e inicialice el entorno interactivo en vivo de Tauri:

```bash
# Instalar el árbol de dependencias del frontend
npm install

# Levantar el entorno de desarrollo nativo con Hot Module Replacement (HMR)
npm run tauri dev

```

### Compilación y Empaquetado de Producción

Para generar el archivo binario independiente y optimizado de producción listo para distribución, ejecute el asistente de empaquetado nativo:

```bash
# Compilar y empaquetar el binario final de Windows
npm run tauri build

```

El binario resultante se alojará automáticamente en la ruta interna del proyecto:
`src-tauri\target\release\bundle\nsis\`

---

## 🛡️ Infraestructura de Seguridad y Respaldo Simétrico

- **Gestión Multi-Tipo en Backups (`backup_manager.psm1`):** La rutina de respaldo intercepta y almacena el `ValueKind` original del registro de Windows (DWord, REG_BINARY, REG_SZ). Esto garantiza que, durante una restauración, las claves complejas (como máscaras binarias de interrupciones o curvas de ratón) no se corrompan ni se escriban como cadenas planas.
- **Punto de Restauración Forzado:** Antes de despachar cualquier tweak avanzado, el orquestador asíncrono invoca obligatoriamente `crear_respaldo.ps1` para levantar una instantánea de volumen nativa (`VSS`) del sistema operativo.
- **Reversión de Fábrica Centralizada (`10_revertir.ps1`):** En caso de inestabilidad, la suite lee la colmena aislada de respaldo de Overlord (`HKLM:\SOFTWARE\Overlord\Backup`) y realiza un rollback simétrico de tipo espejo, devolviendo el registro a su estado exacto previo a la optimización y notificando limpiamente al usuario antes de reiniciar el shell del explorador.
- **Suite de Pruebas Unitarias Integrada (`modules.tests.ps1`):** Las validaciones de tipos de datos, existencia de claves de Kernel modificadas y consistencia de compilación se encuentran completamente automatizadas bajo el framework de pruebas de infraestructura **Pester v5**.

```

```

````
