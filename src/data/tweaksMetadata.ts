export interface TweakMetadata {
  id: string;
  title: string;
  description: string;
  riesgo: "Seguro" | "Balanceado" | "Experimental";
  evidenciaImpacto: "Comprobado" | "Situacional" | "Cosmetico";
  reversible: boolean;
  metodoReversion: string;
  hardwareRecomendado: string;
  windowsVersion: string;
  fuenteOficial: string;
  scriptName: string;
  impactoRendimiento: string;
  warning?: string;
  details: string[];
}

export const PROFILE_CONFIGS: Record<string, string[]> = {
  Competitivo: [
    "peripheralLatency",
    "debloat",
    "networkOptimized",
    "generalPerformance",
    "gpuDisplay",
    "irqAffinity",
    "smartStorage",
    "deepTelemetry",
    "powerProfiles",
    "gameHooks",
    "defenderExclusions",
  ],
  "Programador & Competitivo": [
    "peripheralLatency",
    "debloat",
    "networkOptimized",
    "generalPerformance",
    "gpuDisplay",
    "smartStorage",
    "powerProfiles",
    "gameHooks",
    "defenderExclusions",
  ],
  Programador: ["debloat", "smartStorage", "generalPerformance"],
  "Home Office / Laptops": [
    "debloat",
    "smartStorage",
    "networkOptimized",
    "defenderExclusions",
  ],
  "Usuario Casual": ["debloat", "smartStorage", "defenderExclusions"],
};

export const tweaksMetadata: Record<string, TweakMetadata> = {
  peripheralLatency: {
    id: "peripheralLatency",
    title: "Respuesta de Teclado y Raton",
    description:
      "Desactiva la aceleracion del puntero, optimiza los tiempos de repeticion del teclado y deshabilita la suspension selectiva de puertos USB para reducir la latencia de respuesta.",
    riesgo: "Seguro",
    evidenciaImpacto: "Cosmetico",
    reversible: true,
    metodoReversion:
      "Restauracion de la aceleracion del raton por defecto, reactivacion de suspension de USB y restablecimiento de velocidad de teclado stock.",
    hardwareRecomendado:
      "Cualquier placa base con controladores de bus USB xHCI nativos de Intel o AMD.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/keyboard-and-mouse-class-drivers",
    scriptName: "01_perifericos.ps1",
    impactoRendimiento:
      "Mayor consistencia en el movimiento fisico del raton y reduccion del retraso de repeticion del teclado.",
    warning:
      "Requiere reconectar los perifericos USB o reiniciar el equipo para aplicar la desactivacion del modo de suspension selectiva.",
    details: [
      "Inyeccion de Message Signaled Interrupts (MSI Mode) seguro en controladores USB, GPU y de sonido (Class MEDIA y AudioEndpoint).",
      "Ajuste del programador de CPU (Win32PrioritySeparation = 26) para establecer Quanta Corta y Fija, evitando micro-stutters.",
      "Eliminacion absoluta de la aceleracion por software de Windows (MouseSpeed = 0).",
      "Optimizacion de la latencia y repeticion del teclado (FilterKeys con retraso a 200ms y repeticion a 15ms).",
      "Desactivacion del USB Selective Suspend para mantener energizados los puertos HID de forma continua.",
    ],
  },
  debloat: {
    id: "debloat",
    title: "Limpieza del Sistema (Debloat)",
    description:
      "Elimina aplicaciones preinstaladas (Bloatware) y desactiva servicios innecesarios que consumen ciclos de CPU y RAM.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Intento de re-registro de paquetes AppX provisionados locales y habilitacion de servicios deshabilitados.",
    hardwareRecomendado: "General.",
    windowsVersion: "Windows 10 / Windows 11 (Home y Pro)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage",
    scriptName: "02_debloat.ps1",
    impactoRendimiento:
      "Liberacion de memoria RAM fisica y reduccion del recuento total de procesos activos en segundo plano.",
    warning:
      "Este proceso preserva la Microsoft Store y la App de Xbox para mantener intacto tu entorno gaming y de desarrollo. La desinstalacion de aplicaciones AppX es semi-permanente.",
    details: [
      "Remocion de software preinstalado innecesario (Cortana, Bing, Weather, Maps, etc.).",
      "Eliminacion de telemetria GPO basica y sugerencias web invasivas de Bing en el menu de inicio.",
      "Remocion estructural de las barras laterales y servicios de Windows Copilot.",
      "Desactivacion de los servicios de Diagnostico del Sistema en segundo plano (WdiServiceHost y WdiSystemHost).",
      "Desactivacion estructural de Edge en segundo plano y Startup Boost para ahorrar memoria RAM.",
      "Deshabilitacion de permisos UWP en segundo plano (GlobalUserDisabled = 1) para apps inactivas.",
      "Detencion y deshabilitacion de servicios innecesarios (Fax, RetailDemo, MapsBroker, PhoneSvc, AJRouter, WpcMonSvc, SensorService, TrkWks, RemoteRegistry).",
    ],
  },
  networkOptimized: {
    id: "networkOptimized",
    title: "Optimizacion de Internet",
    description:
      "Desactiva el algoritmo de Nagle (TcpNoDelay) y elimina el estrangulamiento de red multimedia del sistema operativo para bajar el jitter de red.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Restauracion de los valores originales de ThrottlingIndex, SystemResponsiveness y reactivacion de Nagle.",
    hardwareRecomendado:
      "Conexiones por cable Ethernet o adaptadores Wi-Fi modernos.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/networking/technologies/tcp-ip/tcp-ip-performance-tuning",
    scriptName: "03_red.ps1",
    impactoRendimiento:
      "Reduccion y estabilizacion del ping de juegos, erradicacion de micro-cortes por estrangulamiento de paquetes.",
    warning:
      "El beneficio real de desactivar el algoritmo de Nagle (TcpNoDelay y TcpAckFrequency) en pilas TCP modernas es marginal o disputado para juegos online, y podria aumentar ligeramente el overhead del router local al disparar demasiados paquetes pequenos.",
    details: [
      "Desactivacion total del estrangulamiento de ancho de banda (NetworkThrottlingIndex deshabilitado).",
      "Prioridad de CPU dedicada (SystemResponsiveness = 10) para evitar que hilos del kernel estrangulen el hilo del juego.",
      "Optimizacion del tiempo de retransmision TCP (InitialRto = 2000ms) para recuperacion ultrarrapida de perdidas de paquetes.",
      "Desactivacion del algoritmo de Nagle (TcpNoDelay = 1 y TcpAckFrequency = 1) en las interfaces de red activas.",
      "Desactivacion de Large Send Offload (LSO) y Receive Segment Coalescing (RSC) en adaptadores de red para eliminar jitter (Advertencia: puede reducir el ancho de banda pico en transferencias masivas).",
      "Configuracion del perfil RSS a Closest para minimizar fallos de cache L3 de la CPU al procesar interrupciones.",
      "Desactivacion de modos de ahorro Ethernet (EEE, Green Energy), coalescencia de paquetes y control de flujo.",
      "Desactivacion del Power Management del adaptador de red (AllowComputerToTurnOffDevice) para reducir varianza/jitter de ping (Aviso: reduce levemente la autonomia en WiFi).",
    ],
  },
  generalPerformance: {
    id: "generalPerformance",
    title: "Potencia Bruta y Procesador",
    description:
      "Configura la compresion adaptativa de RAM y desactiva el servicio de captura automatica de juegos (GameDVR) para liberar recursos de CPU.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Reactivacion de la compresion de RAM y re-habilitacion de GameDVR.",
    hardwareRecomendado:
      "Equipos con procesadores multinucleo y configuraciones de memoria DDR4 / DDR5.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/commercialize/performance/rules/page-combining",
    scriptName: "04_rendimiento.ps1",
    impactoRendimiento:
      "Disminucion de stutters provocados por procesos de reorganizacion de memoria y codificacion de video en segundo plano.",
    details: [
      "Gestion adaptativa de MMAgent (Memory Compression) optimizada segun la cantidad total de RAM detectada.",
      "Apagado de la compresion de RAM en sistemas de >=32GB para ahorrar procesamiento en favor de latencia pura.",
      "Desactivacion de Page Combining en MMAgent para mitigar micro-stutters generados por el de-duplicador de paginas.",
      "Ajuste del Programador Multimedia (MMCSS) para priorizar juegos en primer plano (Scheduling Category = High, Priority = 6, GPU Priority = 8).",
      "Apagado total de los servicios de grabacion en segundo plano y capturas automaticas de GameDVR.",
      "Desactivacion del aparcamiento de nucleos (Core Parking al 0% en corriente alterna) para extrema estabilidad de 1% y 0.1% lows.",
      "Desactivacion de Dynamic Tick (requiere reinicio) para optimizar el jitter fino a nivel del kernel de Windows.",
    ],
  },
  disableMitigations: {
    id: "disableMitigations",
    title: "Desactivar Mitigaciones de CPU",
    description:
      "Desactiva las mitigaciones Spectre y Meltdown a nivel de Kernel para recuperar ciclos de reloj en procesadores legacy.",
    riesgo: "Experimental",
    evidenciaImpacto: "Situacional",
    reversible: true,
    metodoReversion:
      "Reactivacion de las directivas de mitigacion nativas restableciendo FeatureSettingsOverride.",
    hardwareRecomendado:
      "Procesadores legacy (Intel Core 9th Gen o anterior, AMD Ryzen 3000 o anterior) que sufren sobrecarga por los parches de seguridad.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://support.microsoft.com/en-us/topic/kb4073119-guidance-to-protect-against-speculative-execution-side-channel-vulnerabilities-in-windows-devices-419d691e-3652-32b0-951b-cb6104f7b494",
    scriptName: "disable_mitigations.ps1",
    impactoRendimiento:
      "Recuperacion de rendimiento y reduccion de stutters en juegos, con una mejora marginal de FPS (1-5% real en gaming, aunque mayor en benchmarks de syscalls de CPU antiguos).",
    warning:
      "Desactivar mitigaciones expone al procesador a vulnerabilidades de ejecucion especulativa de canal lateral.",
    details: [
      "Inhabilitacion de mitigaciones de speculative execution (Spectre/Meltdown).",
      "Restauracion del rendimiento perdido por parches de seguridad de kernel.",
    ],
  },
  gpuDisplay: {
    id: "gpuDisplay",
    title: "Fluidez de Pantalla y Graficos",
    description:
      "Ajusta la prioridad del planificador grafico oficial (HAGS) y desactiva la captura en segundo plano de GameBar para evitar caidas de FPS.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Reactivacion de GameBar y restauracion del modo de programacion predeterminado de GPU.",
    hardwareRecomendado:
      "Tarjetas graficas dedicadas modernas (NVIDIA GeForce / AMD Radeon / Intel Arc).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/win32/desktopmgmt/desktop-window-manager-overview",
    scriptName: "05_gpu_display.ps1",
    impactoRendimiento:
      "Eliminacion de stutters por superposiciones de GameBar y optimizacion de latencia en la cola grafica.",
    details: [
      "Establece HwSchMode a 2 para activar la programacion de GPU acelerada por hardware (HAGS).",
      "Desactivacion de GameBarPresenceWriter a nivel de directivas de usuario para prevenir congelamientos temporales.",
      "Desactivacion del grabador de aplicaciones AppCaptureEnabled para liberar ciclos del codificador de video.",
    ],
  },
  irqAffinity: {
    id: "irqAffinity",
    title: "Afinidad de Hardware (IRQ)",
    description:
      "Aisla de forma exclusiva las cargas de interrupciones fisicas de red fuera de los hilos principales del sistema operativo.",
    riesgo: "Experimental",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Restauracion de las llaves de configuracion de adaptadores PCI y remocion de las mascaras binarias dinamicas generadas.",
    hardwareRecomendado:
      "Procesadores multinucleo modernos (arquitecturas hibridas con P-Cores/E-Cores o multi-CCD).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/interrupt-affinity-and-priority",
    scriptName: "06_irq_affinity.ps1",
    impactoRendimiento:
      "Reduccion masiva de la latencia de llamadas de procedimiento diferidas (DPC Latency) del bus de red.",
    warning:
      "Este modulo aisla las interrupciones del bus de red fuera del Core 0. En CPUs de >=8 hilos utiliza una politica de afinacion multi-nucleo selectiva (SpecifiedProcessors) para preservar la capacidad RSS y evitar cuellos de botella en descargas Gigabit.",
    details: [
      "Calculo topologico dinamico en tiempo de ejecucion basado en el mapa de hilos fisicos del procesador.",
      "Asignacion multi-nucleo selectiva en dos cores fisicos independientes (SpecifiedProcessors) para conservar RSS y ancho de banda en descargas.",
      "Seleccion automatica de hilos P-Core optimizados (4 y 6 en CPUs >=12 hilos, o 2 y 4 en CPUs >=8 hilos) evitando hilos logicos hermanos (SMT).",
      "Desactivacion de Interrupt Moderation en adaptadores de red (EXPERIMENTAL: Fuerza interrupciones en tiempo real reduciendo latencia DPC, pero aumenta considerablemente el uso de CPU).",
    ],
  },
  smartStorage: {
    id: "smartStorage",
    title: "Almacenamiento Inteligente",
    description:
      "Optimiza el sistema de archivos NTFS desactivando LastAccessUpdate y deshabilita el Inicio Rapido para evitar fugas de memoria. Nota: La deteccion de SSD de Overlord se basa en el disco donde esta instalado Windows (C:), por lo que esta optimizacion se guiara por dicho estado, independientemente de si tienes bibliotecas de juegos secundarias en otros tipos de discos.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Re-habilitacion del registro del ultimo acceso y activacion del Inicio Rapido de Windows.",
    hardwareRecomendado:
      "Unidades de estado solido solidas (SSD SATA / NVMe M.2).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-government/administration/windows-commands/fsutil-behavior",
    scriptName: "07_almacenamiento.ps1",
    impactoRendimiento:
      "Evita escrituras redundantes en discos SSD, aumentando su vida util, y previene la degradacion de memoria provocada por apagados sucios.",
    details: [
      "Desactivacion de la actualizacion de marcas de tiempo (Last Access Update) para mitigar ciclos de degradacion en SSD.",
      "Desactivacion universal de la creacion de nombres de archivo cortos en formato MS-DOS 8.3 para acelerar el sistema de archivos.",
      "Optimizacion adaptativa de la cache de metadatos NTFS (NtfsMemoryUsage = 2) en sistemas con >= 16 GB de RAM.",
      "Desactivacion completa de la hibernacion y remocion del archivo fantasma persistente Hiberfil.sys (en desktops).",
      "Desactivacion de Inicio Rapido (HiberbootEnabled = 0) para forzar un apagado limpio del kernel de Windows.",
    ],
  },
  deepTelemetry: {
    id: "deepTelemetry",
    title: "Blindaje de Seguridad y Privacidad",
    description:
      "Purga por completo los flujos ocultos de recoleccion de diagnostico, detiene event loggers y tareas programadas del sistema.",
    riesgo: "Experimental",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Restauracion de loggers asincronos y servicios de telemetria a su estado de fabrica.",
    hardwareRecomendado:
      "Computadoras enfocadas puramente al alto rendimiento gaming de baja latencia.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization",
    scriptName: "08_telemetria.ps1",
    impactoRendimiento:
      "Reduccion del consumo de CPU en segundo plano y prevencion de picos de latencia debido a procesos de recoleccion de Microsoft.",
    warning:
      "Desactivar servicios y autologgers de telemetria bloquea la transmision de datos a servidores de Microsoft, pero reduce el diagnostico automatico de fallas.",
    details: [
      "Deshabilitacion de la directiva de Windows Error Reporting a nivel de politicas de sistema.",
      "Erradicacion definitiva del servicio de recoleccion de experiencias DiagTrack y del historial de actividades de usuario.",
      "Configuracion del servicio Delivery Optimization (DoSvc) en modo Manual para prevenir consumo sorpresivo de ancho de banda local.",
      "Bloqueo perimetral en el Firewall de Windows para los ejecutables de recoleccion nativos (CompatTelRunner, etc.).",
      "Detencion e inhabilitacion asincrona de Autologgers ocultos del Visor de Eventos de Windows.",
      "Bloqueo total de Windows Recall y captura de actividad local de Inteligencia Artificial (Windows AI).",
    ],
  },
  powerProfiles: {
    id: "powerProfiles",
    title: "Perfiles de Energia",
    description:
      "Inyecta el esquema energetico de Maximo Rendimiento y deshabilita el Core Parking en PCs de escritorio.",
    riesgo: "Balanceado",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Inversion de los estados de estacionamiento de nucleos y restauracion del plan de energia original.",
    hardwareRecomendado:
      "Computadoras de escritorio y laptops conectadas a la corriente electrica.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options",
    scriptName: "09_energia.ps1",
    impactoRendimiento:
      "Consistencia total en las frecuencias maximas del reloj de la CPU y respuesta electrica inmediata de los buses PCIe.",
    details: [
      "Importacion e inyeccion del esquema de energia personalizado Overlord Performance.",
      "Ajuste del estacionamiento de nucleos (Core Parking) al 100% para evitar caidas y fluctuaciones de frecuencias.",
      "Optimizacion de la preferencia de rendimiento energetico (EPP = 0) y CPU Boost (Agresivo) en desktops.",
      "Configuracion de la suspension de discos duros a Nunca (Timeout = 0) y deshabilitacion global de Power Throttling en desktops.",
    ],
  },
  gameHooks: {
    id: "gameHooks",
    title: "Prioridad Absoluta para Juegos",
    description:
      "Fuerza el bypass grafico de pantalla completa optimizada e inicializa el monitor dinamico de hilos en memoria RAM.",
    riesgo: "Seguro",
    evidenciaImpacto: "Situacional",
    reversible: true,
    metodoReversion:
      "Eliminacion determinista de subllaves aisladas mapeadas bajo la ruta absoluta de cada binario descubierto.",
    hardwareRecomendado:
      "Sistemas dependientes de rendimiento mononucleo para videojuegos competitivos.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/win32/desktopmgmt/full-screen-optimization",
    scriptName: "11_game_hooks.ps1",
    impactoRendimiento:
      "Prioridad de ejecucion en tiempo real aislada frente a hilos del sistema operativo, estabilizando los cuadros por segundo.",
    warning:
      "Modulo 100% seguro para Anti-Cheats (Vanguard, EasyAntiCheat, BattlEye). La prioridad se inyecta dinamicamente desde el backend de Rust.",
    details: [
      "Inyeccion de invalidacion de escalado de PPP (High DPI) para eliminar la latencia por reescalado de pantalla.",
      "Forzado de pantalla completa exclusiva en archivos de configuracion de juegos compatibles (como Unreal Engine).",
      "Limpieza quirurgica de modificaciones IFEO inyectadas previamente por Overlord, preservando de forma 100% segura los hooks legitimos de Anti-Cheats (Vanguard, EAC).",
      "Aislamiento de persistencia de entorno mediante subllaves estructuradas con la ruta fisica completa del ejecutable.",
    ],
  },
  defenderExclusions: {
    id: "defenderExclusions",
    title: "Exclusiones de Windows Defender",
    description:
      "Anade las carpetas de instalacion de tus juegos a la lista de exclusiones de Windows Defender para evitar micro-stutters causados por el escaneo en tiempo real.",
    riesgo: "Balanceado",
    warning:
      "Esta optimizacion crea una excepcion en el escaneo en tiempo real de Windows Defender para las carpetas de los juegos detectados. Esto mejora el rendimiento, pero significa que los archivos dentro de esas carpetas especificas no seran analizados.",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Eliminacion exclusiva de las rutas del catalogo agregadas previamente por Overlord, conservando tus exclusiones manuales.",
    hardwareRecomendado: "Cualquier PC (especialmente laptops y sistemas con CPUs limitadas).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/powershell/module/defender/add-mppreference",
    scriptName: "12_defender_exclusions.ps1",
    impactoRendimiento:
      "Evita el consumo repentino de CPU y stutters por parte de Antimalware Service Executable (MsMpEng.exe) al leer los recursos del juego.",
    details: [
      "Resolucion dinamica de las carpetas de instalacion de todos tus juegos del catalogo.",
      "Uso del cmdlet oficial Add-MpPreference de Windows Defender.",
      "Persistencia de la lista de directorios agregados en la base de datos de Overlord para una reversion quirurgica no destructiva.",
    ],
  },
};
