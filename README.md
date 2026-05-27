<div align="center">
  <img src="overlord_icon.png" alt="Overlord Logo" width="120">
  
  # OVERLORD (v2.5.4)
  **Sistema Avanzado de Optimización, Gestión de Telemetría y Reducción de Latencia para Windows 10 y 11.**
  
  Una suite de ingeniería orientada al rendimiento competitivo de bajo nivel, depuración avanzada del sistema operativo y anulación del retraso de entrada (*input lag*), impulsada por un núcleo asíncrono en Rust, scripts sintonizados para Windows PowerShell 5.1 y una interfaz fluida basada en Vue 3, Tailwind CSS y Pinia.

[![Vue.js](https://img.shields.io/badge/Vue%203-35495E?style=for-the-badge&logo=vue.js&logoColor=4FC08D)](https://vuejs.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![Tauri](https://img.shields.io/badge/Tauri-FFC131?style=for-the-badge&logo=tauri&logoColor=white)](https://tauri.app/)
[![Rust](https://img.shields.io/badge/Rust-000000?style=for-the-badge&logo=rust&logoColor=white)](https://www.rust-lang.org/)

</div>

<hr>

<div align="center">
  <img src="/src/assets/overlordPanel.png" alt="Overlord UI" width="800"/>
</div>

## 🧠 Filosofía de Ingeniería y Arquitectura Saneada

A diferencia de las herramientas tradicionales de optimización distribuidas de forma genérica en foros de internet, Overlord v2.5.4 se rige bajo estrictas auditorías de código, omitiendo por completo modificaciones "placebo" o destructivas que comprometan el subsistema de Windows Update o generen congelamientos en el núcleo del sistema.

### Pilares Fundamentales del Sistema

- **Resolución por SID Dinámico (Bypass de Privilegios de Admin):** Al ejecutarse en un entorno elevado, Windows mapea de forma predeterminada el alcance de la colmena `HKCU:` hacia la cuenta del Administrador del Sistema. El motor de Overlord intercepta el SID real del usuario interactivo mediante instancias CIM nativas, forzando la inyección quirúrgica de configuraciones directamente en `Registry::HKEY_USERS\$UserSID`, garantizando que el 100% de los cambios surtan efecto inmediato en el perfil correcto del usuario.
- **Compatibilidad Nativa Completa con PowerShell 5.1:** Toda la lógica de automatización de scripts internos ha sido reestructurada aislando los flujos condicionales complejos en variables dedicadas antes del paso de argumentos. Esto elimina de raíz las fallas de compilación del intérprete (`Code 1`) presentes en entornos limpios de Windows que no cuentan con PowerShell 7+.
- **Gestión Avanzada de Telemetría Dinámica:** El frontend incorpora un bucle asíncrono de sondeo coordinado a través de Pinia (`startTelemetryPolling`) que realiza llamadas concurrentes cada 2000ms al backend de Rust (`invoke("get_live_telemetry")`). Las lecturas numéricas de rendimiento de la CPU y la memoria RAM son interceptadas y procesadas a través de restricciones estrictas `.toFixed()` en el componente `<HardwareSidebar/>`, suprimiendo desbordamientos de punto flotante de JavaScript para brindar una visualización limpia en tiempo real.
- **Puente IPC Seguro y Parametrizado:** El backend de Rust procesa la ejecución de comandos de PowerShell de forma totalmente aislada a través de un esquema nativo parametrizado. Esto previene vulnerabilidades de inyección de código al separar de forma estricta las variables lógicas de los argumentos externos.
- **Diagnóstico de Hardware Avanzado:** Interroga directamente al controlador de memoria física y al bus PCI para obtener telemetría real en tiempo real. Detecta frecuencias de memoria RAM en MHz (con soporte XMP y EXPO), arquitecturas con múltiples tarjetas gráficas simultáneas (Setups híbridos o dedicados) y adapta los perfiles según se trate de un equipo portátil o de escritorio.
- **Purga de Memoria Nativa:** Invoca la API nativa no documentada del Kernel de Windows (`NtSetSystemInformation`) directamente desde código seguro en Rust, liberando la lista de espera de la memoria RAM (_Standby List_) de forma inmediata sin consumir ciclos de procesamiento de la CPU.
- **Depuración Quirúrgica Anti-Placebo:** Basado en rigurosas auditorías de rendimiento, se han purgado todas las mitigaciones dañinas que circulan habitualmente en internet (como la clave de video obsoleta `RMHdcpKeyLocalZero` o el apagado arbitrario del reloj del sistema `useplatformclock false` que destruye la estabilidad en procesadores AMD Ryzen modernos), priorizando configuraciones estables avaladas por análisis de micro-tirones (_stuttering_).

---

## 🛠️ Módulos de Optimización y Clasificación de Impacto

Para garantizar un control preciso del sistema operativo, Overlord organiza sus funciones en categorías estandarizadas de riesgo y cuenta con un mapeo de sincronización bidireccional estricto entre el almacenamiento reactivo de Pinia y el registro de Windows:

### 1. Clasificación: Seguro

- **Respuesta Ultra-Baja de Periféricos:** Modifica los valores asignados a los búferes de intercambio de hardware `MouseDataQueueSize` y `KeyboardDataQueueSize` a un umbral óptimo de 20 paquetes concurrentes y anula las curvas dinámicas de aceleración heredadas del registro, forzando un rastreo puro uno a uno de los sensores de hardware.
- **Limpieza del Sistema (Debloat):** Desinstala aplicaciones innecesarias preinstaladas de fábrica (_UWP Bloatware_) y deshabilita tareas programadas de telemetría básica de recolección de datos. Mantiene el servicio de búsqueda nativo plenamente operativo para evitar el bloqueo o la congelación de los cuadros de texto en la configuración de Windows.
- **Sintonización de Red de Alto Rendimiento:** Configura la ventana de recepción TCP a un nivel avanzado, desactiva algoritmos de agrupación de paquetes que provocan variaciones de ping y establece un límite superior real de permanencia de caché DNS a 86400 segundos (`MaxCacheTtl`), evitando consultas repetitivas de resolución de nombres a los servidores globales y estabilizando las conexiones frente a micro-cortes de red.
- **Aceleración de Almacenamiento:** Duplica la pila asignada a la caché de metadatos del sistema de archivos NTFS y bloquea el registro redundante de marcas de tiempo en el almacenamiento (`NtfsDisableLastAccessUpdate`), reduciendo las operaciones I/O innecesarias y prolongando la vida útil de las unidades de estado sólido de alta velocidad (SSD y NVMe).

### 2. Clasificación: Avanzado

- **Potencia Bruta y Procesador:** Aplica el plan de energía oculto de rendimiento máximo, anula el estacionamiento de núcleos del procesador (_Core Parking_) en equipos de escritorio y deshabilita de forma lógica las mitigaciones de seguridad de ejecución especulativa de la CPU para liberar potencia de procesamiento bruto en entornos multitarea y videojuegos.
- **Fluidez de Pantalla y Gráficos:** Mitiga los fallos de sincronización y parpadeos visuales desactivando la superposición de planos múltiples (_MPO_) en el gestor de ventanas y ajusta las prioridades de ejecución de la tarjeta gráfica a través de directivas de GPU programadas.
- **Mitigación Controlada de Tiempos de Espera (DISM):** Los scripts lógicos del sistema integran directivas de control y exclusión asíncrona para evitar congelamientos o bloqueos en la interfaz visual de Tauri durante la ejecución de comandos pesados de mantenimiento en la imagen de Windows.

### 3. Clasificación: Kernel

- **Organización del Procesador:** Distribuye el tráfico de interrupciones de red de hardware fuera del Núcleo 0 de la CPU para evitar la congestión del procesador principal, asignando prioridades exclusivas al subsistema multimedia.
- **Seguridad Virtual y Filtros:** Desactiva opcionalmente el aislamiento de integridad de código basado en virtualización (_VBS / HVCI_). Libera recursos considerables del procesador en juegos limitados por CPU, pero restringe temporalmente herramientas que dependen de hipervisores nativos.
- **Prioridad Absoluta para Juegos:** Inyecta reglas directas en las opciones de ejecución de imágenes del registro (_IFEO_) para ejecutables específicos de deportes electrónicos (como `League of Legends.exe`, `VALORANT-Win64-Shipping.exe`, `cs2.exe`), asegurando el enfoque prioritario de los hilos de la CPU cuando el juego se encuentra en primer plano.

### 4. Clasificación: Ajustes Instantáneos (21 Interruptores QoL de un Clic)

El módulo **`<QolPanel/>`** despliega 21 modificaciones quirúrgicas inmediatas a nivel de experiencia de usuario y privacidad. Cada switch cuenta con control defensivo de excepciones por bloques (`Try/Catch`), de modo que el escáner no se interrumpa si el sistema operativo carece de alguna subclave de fábrica:

- **Interfaz & UI:** Rendimiento Visual Barebones (apaga animaciones de ventanas), Modo Oscuro Global, Mostrar Extensiones de Archivos nativas, Menú Contextual Clásico de Windows 11 (clic derecho tradicional), Barra de Tareas Alineada a la Izquierda y Pantallazos Azules Detallados (BSoD con parámetros de depuración avanzados).
- **Privacidad:** Desactivar sugerencias de búsqueda de Bing en el Menú Inicio, bloquear anuncios de sincronización nativos en el explorador, deshabilitar pantallas de bienvenida de inicio ("Scoobe"), bloquear la telemetría e hilos de MS Copilot y el sistema de capturas de pantalla de Windows Recall.
- **Explorador & Gaming:** Iniciar directamente en "Este Equipo", erradicación completa del arranque y sincronización en segundo plano de OneDrive, remoción total del panel de Widgets (liberando RAM de procesos persistentes de WebView2), deshabilitación de atajos de accesibilidad (Sticky Keys/Filter Keys) y retraso de arranque establecido en cero para unidades de estado sólido.

---

## ⚡ Ejecución Portátil Inmediata (Sin Instalación)

Inspirado en la filosofía de distribución moderna y limpia de herramientas líderes como _WinUtil_, Overlord ha adoptado un modelo de **arquitectura de huella cero**. No requiere asistentes de instalación locales ni deja dependencias basura flotando en el almacenamiento del usuario.

Para ejecutar la suite de forma instantánea directamente desde la nube a la memoria RAM, abra una sesión de **PowerShell como Administrador** e inyecte el comando _one-liner_ oficial:

```powershell
irm [https://raw.githubusercontent.com/lordforcuadd/Overlord/main/launch.ps1](https://raw.githubusercontent.com/lordforcuadd/Overlord/main/launch.ps1) | iex
```

### Mechanism de Portabilidad Interno:

1. El comando `irm` (_Invoke-RestMethod_) descarga en memoria el script de orquestación remota `launch.ps1`.
2. El script consulta dinámicamente la API pública de GitHub (`api.github.com/repos/lordforcuadd/Overlord/releases/latest`) para interceptar el nombre exacto y la ruta de descarga de los recursos binarios `.exe` subidos en el último release, haciendo que el comando sea inmune a futuros cambios de versión.
3. Descarga el ejecutable en un directorio temporal aislado (`$env:TEMP\OverlordSuite`) y levanta la interfaz con privilegios elevados.
4. Al cerrarse la aplicación, el script remueve de forma automática y forzada el directorio temporal, garantizando un entorno 100% libre de residuos en la máquina del usuario.

---

## 🛠️ Gestión de Arquetipos de Perfiles

El sistema procesa perfiles granulares integrados en su lógica reactiva para adaptar el entorno de forma automatizada según el caso de uso del equipo:

- **Competitivo:** Activa la suite completa de bajo nivel para obtener la mínima latencia de entrada, priorización estricta de GPU y la máxima tasa de fotogramas por segundo estables.
- **Programador & Competitivo:** Conserva activas las directivas de seguridad virtual indispensables para entornos de desarrollo basados en contenedores aislados (Docker, WSL2) y máquinas virtuales, aplicando las optimizaciones de hardware restantes de forma íntegra.
- **Programador:** Maximiza el rendimiento del sistema de archivos NTFS y los subprocesos del procesador, optimizando drásticamente los tiempos de compilación de código local.
- **Home Office / Laptops:** Enfocado en la estabilidad de red y el ahorro de ciclos de escritura en disco, preservando los esquemas de ahorro térmico y la duración de la batería de los equipos portátiles.

---

## 🛡️ Métodos de Seguridad, Respaldo y Auditoría

La integridad del sistema operativo es la máxima prioridad del software. Overlord v2.5.4 cuenta con una red de seguridad simétrica verificada de extremo a extremo mediante el framework de pruebas de infraestructura **Pester v5**:

- **Punto de Restauración Obligatorio:** Antes de realizar modificaciones avanzadas o de nivel Kernel, el backend asíncrono invoca forzosamente el script `crear_respaldo.ps1`, activando el servicio de instantáneas de volumen de Microsoft para blindar el estado de la máquina.
- **Reversión de Estado Simétrica:** El software escribe los valores originales de fábrica del registro en una zona aislada de respaldo de Overlord (`HKLM:\SOFTWARE\Overlord\Backup`). En caso de inestabilidad provocada por el estado acumulado del sistema del usuario, los cambios pueden revertirse en su totalidad dejando la PC en su estado exacto de fábrica.
- **Modo de Simulación Seguro (Dry-Run):** Integrado en el corazón de `App.vue`, permite ejecutar la suite de forma local con fines de desarrollo y demostración. El flujo simula los tiempos de espera secuenciales, muta los estados reactivos en la pantalla a `"loading"` y `"success"`, pero evita la modificación física del registro de Windows para prevenir errores accidentales durante las pruebas de interfaz.

---

## 💻 Configuración del Entorno de Desarrollo y Distribución

Si deseas colaborar, extender las funciones lógicas de los módulos de automatización o compilar los ejecutables de forma local, configure su espacio de trabajo de la siguiente manera:

### Prerrequisitos del Entorno

- **Node.js:** Versión 18 o superior con el gestor de paquetes `npm` de forma global.
- **Rust Toolchain:** Instalación de la cadena de herramientas estable a través de `rustup` apuntando al objetivo `x86_64-pc-windows-msvc`.
- **C++ Build Tools:** Paquetes de compilación nativos de Visual Studio (MSVC) configurados en el sistema operativo.

### Flujo de Comandos de Desarrollo

Instala los módulos de Node y levanta el entorno de depuración interactivo en vivo de Tauri:

```bash
# Instalar dependencias e interfaces de tipado estricto
npm install

# Levantar entorno de desarrollo nativo con Hot Module Replacement (HMR)
npm run tauri dev
```

### Compilación y Publicación Manual de Versiones (Releases)

Para generar el archivo ejecutable de producción y distribuirlo en la pestaña de descargas de GitHub, ejecute el asistente de empaquetado nativo:

```bash
# Generar el binario optimizado de producción de Windows
npm run tauri build
```

Una vez finalizado el proceso de compilación, Tauri generará el instalador o ejecutable correspondiente dentro de la carpeta del proyecto en la siguiente ruta:
`src-tauri\target\release\bundle\` (o `release\` según la configuración de bundles).

**Pasos para el despliegue en GitHub:**

1. Ve a tu repositorio en GitHub y haz clic en la sección **Releases** > **Create a new release**.
2. Define la etiqueta de versión correspondiente (ej. `v2.5.4`).
3. Arrastra y suelta el archivo `.exe` compilado en la zona de archivos adjuntos (_Attach binaries_).
4. Publica el Release. El script dinámico `launch.ps1` detectará de inmediato el nuevo archivo de manera automática para todos los usuarios.

> **Nota sobre seguridad:** Debido a que el software interactúa con los parámetros del registro del sistema de bajo nivel, algunas soluciones de seguridad de software estricto pueden generar alertas de falsos positivos. Overlord es un proyecto totalmente transparente y de código abierto que puede ser auditado de forma independiente en este repositorio.

```

```
