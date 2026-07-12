export interface TweakMetadata {
  id: string;
  title: string;
  description: string;
  riesgo: "Seguro" | "Balanceado" | "Experimental";
  evidenciaImpacto: "Comprobado" | "Situacional" | "Cosmético";
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
    title: "Respuesta de Teclado y Ratón",
    description:
      "Desactiva la aceleración del puntero, optimiza los tiempos de repetición del teclado y deshabilita la suspensión selectiva de puertos USB para reducir la latencia de respuesta.",
    riesgo: "Seguro",
    evidenciaImpacto: "Cosmético",
    reversible: true,
    metodoReversion:
      "Restauración de la aceleración del ratón por defecto, reactivación de suspensión de USB y restablecimiento de velocidad de teclado stock.",
    hardwareRecomendado:
      "Cualquier placa base con controladores de bus USB xHCI nativos de Intel o AMD.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/keyboard-and-mouse-class-drivers",
    scriptName: "01_perifericos.ps1",
    impactoRendimiento:
      "Mayor consistencia en el movimiento físico del ratón y reducción del retraso de repetición del teclado.",
    warning:
      "Requiere reconectar los periféricos USB o reiniciar el equipo para aplicar la desactivación del modo de suspensión selectiva.",
    details: [
      "Inyección de Message Signaled Interrupts (MSI Mode) seguro en controladores USB, GPU y de sonido (Class MEDIA y AudioEndpoint).",
      "Ajuste del programador de CPU (Win32PrioritySeparation = 26) para establecer Quanta Corta y Fija, evitando micro-stutters.",
      "Eliminación absoluta de la aceleración por software de Windows (MouseSpeed = 0).",
      "Optimización de la latencia y repetición del teclado (FilterKeys con retraso a 200ms y repetición a 15ms).",
      "Desactivación del USB Selective Suspend para mantener energizados los puertos HID de forma continua.",
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
      "Intento de re-registro de paquetes AppX provisionados locales y habilitación de servicios deshabilitados.",
    hardwareRecomendado: "General.",
    windowsVersion: "Windows 10 / Windows 11 (Home y Pro)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage",
    scriptName: "02_debloat.ps1",
    impactoRendimiento:
      "Liberación de memoria RAM física y reducción del recuento total de procesos activos en segundo plano.",
    warning:
      "Este proceso preserva la Microsoft Store y la App de Xbox para mantener intacto tu entorno gaming y de desarrollo. La desinstalación de aplicaciones AppX es semi-permanente.",
    details: [
      "Remoción de software preinstalado innecesario (Cortana, Bing, Weather, Maps, etc.).",
      "Eliminación de telemetría GPO básica y sugerencias web invasivas de Bing en el menú de inicio.",
      "Remoción estructural de las barras laterales y servicios de Windows Copilot.",
      "Desactivación de los servicios de Diagnóstico del Sistema en segundo plano (WdiServiceHost y WdiSystemHost).",
      "Desactivación estructural de Edge en segundo plano y Startup Boost para ahorrar memoria RAM.",
      "Deshabilitación de permisos UWP en segundo plano (GlobalUserDisabled = 1) para apps inactivas.",
      "Detención y deshabilitación de servicios innecesarios (Fax, RetailDemo, MapsBroker, PhoneSvc, AJRouter, WpcMonSvc, SensorService, TrkWks, RemoteRegistry).",
    ],
  },
  networkOptimized: {
    id: "networkOptimized",
    title: "Optimización de Internet",
    description:
      "Desactiva el algoritmo de Nagle (TcpNoDelay) y elimina el estrangulamiento de red multimedia del sistema operativo para bajar el jitter de red.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Restauración de los valores originales de ThrottlingIndex, SystemResponsiveness y reactivación de Nagle.",
    hardwareRecomendado:
      "Conexiones por cable Ethernet o adaptadores Wi-Fi modernos.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/networking/technologies/tcp-ip/tcp-ip-performance-tuning",
    scriptName: "03_red.ps1",
    impactoRendimiento:
      "Reducción y estabilización del ping de juegos, erradicación de micro-cortes por estrangulamiento de paquetes.",
    details: [
      "Desactivación total del estrangulamiento de ancho de banda (NetworkThrottlingIndex deshabilitado).",
      "Prioridad de CPU dedicada (SystemResponsiveness = 10) para evitar que hilos del kernel estrangulen el hilo del juego.",
      "Optimización del tiempo de retransmisión TCP (InitialRto = 2000ms) para recuperación ultrarrápida de pérdidas de paquetes.",
      "Desactivación del algoritmo de Nagle (TcpNoDelay = 1 y TcpAckFrequency = 1) en las interfaces de red activas.",
      "Desactivación de Large Send Offload (LSO) y Receive Segment Coalescing (RSC) en adaptadores de red para eliminar jitter (Advertencia: puede reducir el ancho de banda pico en transferencias masivas).",
      "Configuración del perfil RSS a Closest para minimizar fallos de caché L3 de la CPU al procesar interrupciones.",
      "Desactivación de modos de ahorro Ethernet (EEE, Green Energy), coalescencia de paquetes y control de flujo.",
      "Desactivación del Power Management del adaptador de red (AllowComputerToTurnOffDevice) para reducir varianza/jitter de ping (Aviso: reduce levemente la autonomía en WiFi).",
    ],
  },
  generalPerformance: {
    id: "generalPerformance",
    title: "Potencia Bruta y Procesador",
    description:
      "Configura la compresión adaptativa de RAM y desactiva el servicio de captura automática de juegos (GameDVR) para liberar recursos de CPU.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Reactivación de la compresión de RAM y re-habilitación de GameDVR.",
    hardwareRecomendado:
      "Equipos con procesadores multinúcleo y configuraciones de memoria DDR4 / DDR5.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/commercialize/performance/rules/page-combining",
    scriptName: "04_rendimiento.ps1",
    impactoRendimiento:
      "Disminución de stutters provocados por procesos de reorganización de memoria y codificación de vídeo en segundo plano.",
    details: [
      "Gestión adaptativa de MMAgent (Memory Compression) optimizada según la cantidad total de RAM detectada.",
      "Apagado de la compresión de RAM en sistemas de >=32GB para ahorrar procesamiento en favor de latencia pura.",
      "Desactivación de Page Combining en MMAgent para mitigar micro-stutters generados por el de-duplicador de páginas.",
      "Ajuste del Programador Multimedia (MMCSS) para priorizar juegos en primer plano (Scheduling Category = High, Priority = 6, GPU Priority = 8).",
      "Apagado total de los servicios de grabación en segundo plano y capturas automáticas de GameDVR.",
      "Desactivación del aparcamiento de núcleos (Core Parking al 0% en corriente alterna) para extrema estabilidad de 1% y 0.1% lows.",
      "Desactivación de Dynamic Tick (requiere reinicio) para optimizar el jitter fino a nivel del kernel de Windows.",
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
      "Reactivación de las directivas de mitigación nativas restableciendo FeatureSettingsOverride.",
    hardwareRecomendado:
      "Procesadores legacy (Intel Core 9th Gen o anterior, AMD Ryzen 3000 o anterior) que sufren sobrecarga por los parches de seguridad.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://support.microsoft.com/en-us/topic/kb4073119-guidance-to-protect-against-speculative-execution-side-channel-vulnerabilities-in-windows-devices-419d691e-3652-32b0-951b-cb6104f7b494",
    scriptName: "disable_mitigations.ps1",
    impactoRendimiento:
      "Recuperación de rendimiento y reducción de stutters en juegos, con una mejora marginal de FPS (1-5% real en gaming, aunque mayor en benchmarks de syscalls de CPU antiguos).",
    warning:
      "Desactivar mitigaciones expone al procesador a vulnerabilidades de ejecución especulativa de canal lateral.",
    details: [
      "Inhabilitación de mitigaciones de speculative execution (Spectre/Meltdown).",
      "Restauración del rendimiento perdido por parches de seguridad de kernel.",
    ],
  },
  gpuDisplay: {
    id: "gpuDisplay",
    title: "Fluidez de Pantalla y Gráficos",
    description:
      "Ajusta la prioridad del planificador gráfico oficial (HAGS) y desactiva la captura en segundo plano de GameBar para evitar caídas de FPS.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Reactivación de GameBar y restauración del modo de programación predeterminado de GPU.",
    hardwareRecomendado:
      "Tarjetas gráficas dedicadas modernas (NVIDIA GeForce / AMD Radeon / Intel Arc).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/win32/desktopmgmt/desktop-window-manager-overview",
    scriptName: "05_gpu_display.ps1",
    impactoRendimiento:
      "Eliminación de stutters por superposiciones de GameBar y optimización de latencia en la cola gráfica.",
    details: [
      "Establece HwSchMode a 2 para activar la programación de GPU acelerada por hardware (HAGS).",
      "Desactivación de GameBarPresenceWriter a nivel de directivas de usuario para prevenir congelamientos temporales.",
      "Desactivación del grabador de aplicaciones AppCaptureEnabled para liberar ciclos del codificador de vídeo.",
    ],
  },
  irqAffinity: {
    id: "irqAffinity",
    title: "Afinidad de Hardware (IRQ)",
    description:
      "Aísla de forma exclusiva las cargas de interrupciones físicas de red fuera de los hilos principales del sistema operativo.",
    riesgo: "Experimental",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Restauración de las llaves de configuración de adaptadores PCI y remoción de las máscaras binarias dinámicas generadas.",
    hardwareRecomendado:
      "Procesadores multinúcleo modernos (arquitecturas híbridas con P-Cores/E-Cores o multi-CCD).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/interrupt-affinity-and-priority",
    scriptName: "06_irq_affinity.ps1",
    impactoRendimiento:
      "Reducción masiva de la latencia de llamadas de procedimiento diferidas (DPC Latency) del bus de red.",
    warning:
      "Este módulo aísla las interrupciones del bus de red fuera del Core 0. En CPUs de >=8 hilos utiliza una política de afinación multi-núcleo selectiva (SpecifiedProcessors) para preservar la capacidad RSS y evitar cuellos de botella en descargas Gigabit.",
    details: [
      "Cálculo topológico dinámico en tiempo de ejecución basado en el mapa de hilos físicos del procesador.",
      "Asignación multi-núcleo selectiva en dos cores físicos independientes (SpecifiedProcessors) para conservar RSS y ancho de banda en descargas.",
      "Selección automática de hilos P-Core optimizados (4 y 6 en CPUs >=12 hilos, o 2 y 4 en CPUs >=8 hilos) evitando hilos lógicos hermanos (SMT).",
      "Desactivación de Interrupt Moderation en adaptadores de red (EXPERIMENTAL: Fuerza interrupciones en tiempo real reduciendo latencia DPC, pero aumenta considerablemente el uso de CPU).",
    ],
  },
  smartStorage: {
    id: "smartStorage",
    title: "Almacenamiento Inteligente",
    description:
      "Optimiza el sistema de archivos NTFS desactivando LastAccessUpdate y deshabilita el Inicio Rápido para evitar fugas de memoria. Nota: La detección de SSD de Overlord se basa en el disco donde está instalado Windows (C:), por lo que esta optimización se guiará por dicho estado, independientemente de si tienes bibliotecas de juegos secundarias en otros tipos de discos.",
    riesgo: "Seguro",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Re-habilitación del registro del último acceso y activación del Inicio Rápido de Windows.",
    hardwareRecomendado:
      "Unidades de estado sólido sólidas (SSD SATA / NVMe M.2).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-government/administration/windows-commands/fsutil-behavior",
    scriptName: "07_almacenamiento.ps1",
    impactoRendimiento:
      "Evita escrituras redundantes en discos SSD, aumentando su vida útil, y previene la degradación de memoria provocada por apagados sucios.",
    details: [
      "Desactivación de la actualización de marcas de tiempo (Last Access Update) para mitigar ciclos de degradación en SSD.",
      "Desactivación universal de la creación de nombres de archivo cortos en formato MS-DOS 8.3 para acelerar el sistema de archivos.",
      "Optimización adaptativa de la caché de metadatos NTFS (NtfsMemoryUsage = 2) en sistemas con >= 16 GB de RAM.",
      "Desactivación completa de la hibernación y remoción del archivo fantasma persistente Hiberfil.sys (en desktops).",
      "Desactivación de Inicio Rápido (HiberbootEnabled = 0) para forzar un apagado limpio del kernel de Windows.",
    ],
  },
  deepTelemetry: {
    id: "deepTelemetry",
    title: "Blindaje de Seguridad y Privacidad",
    description:
      "Purga por completo los flujos ocultos de recolección de diagnóstico, detiene event loggers y tareas programadas del sistema.",
    riesgo: "Experimental",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Restauración de loggers asíncronos y servicios de telemetría a su estado de fábrica.",
    hardwareRecomendado:
      "Computadoras enfocadas puramente al alto rendimiento gaming de baja latencia.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization",
    scriptName: "08_telemetria.ps1",
    impactoRendimiento:
      "Reducción del consumo de CPU en segundo plano y prevención de picos de latencia debido a procesos de recolección de Microsoft.",
    warning:
      "Desactivar servicios y autologgers de telemetría bloquea la transmisión de datos a servidores de Microsoft, pero reduce el diagnóstico automático de fallas.",
    details: [
      "Deshabilitación de la directiva de Windows Error Reporting a nivel de políticas de sistema.",
      "Erradicación definitiva del servicio de recolección de experiencias DiagTrack y del historial de actividades de usuario.",
      "Configuración del servicio Delivery Optimization (DoSvc) en modo Manual para prevenir consumo sorpresivo de ancho de banda local.",
      "Bloqueo perimetral en el Firewall de Windows para los ejecutables de recolección nativos (CompatTelRunner, etc.).",
      "Detención e inhabilitación asíncrona de Autologgers ocultos del Visor de Eventos de Windows.",
      "Bloqueo total de Windows Recall y captura de actividad local de Inteligencia Artificial (Windows AI).",
    ],
  },
  powerProfiles: {
    id: "powerProfiles",
    title: "Perfiles de Energía",
    description:
      "Inyecta el esquema energético de Máximo Rendimiento y deshabilita el Core Parking en PCs de escritorio.",
    riesgo: "Balanceado",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Inversión de los estados de estacionamiento de núcleos y restauración del plan de energía original.",
    hardwareRecomendado:
      "Computadoras de escritorio y laptops conectadas a la corriente eléctrica.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options",
    scriptName: "09_energia.ps1",
    impactoRendimiento:
      "Consistencia total en las frecuencias máximas del reloj de la CPU y respuesta eléctrica inmediata de los buses PCIe.",
    details: [
      "Importación e inyección del esquema de energía personalizado Overlord Performance.",
      "Ajuste del estacionamiento de núcleos (Core Parking) al 100% para evitar caídas y fluctuaciones de frecuencias.",
      "Optimización de la preferencia de rendimiento energético (EPP = 0) y CPU Boost (Agresivo) en desktops.",
      "Configuración de la suspensión de discos duros a Nunca (Timeout = 0) y deshabilitación global de Power Throttling en desktops.",
    ],
  },
  gameHooks: {
    id: "gameHooks",
    title: "Prioridad Absoluta para Juegos",
    description:
      "Fuerza el bypass gráfico de pantalla completa optimizada e inicializa el monitor dinámico de hilos en memoria RAM.",
    riesgo: "Seguro",
    evidenciaImpacto: "Situacional",
    reversible: true,
    metodoReversion:
      "Eliminación determinista de subllaves aisladas mapeadas bajo la ruta absoluta de cada binario descubierto.",
    hardwareRecomendado:
      "Sistemas dependientes de rendimiento mononúcleo para videojuegos competitivos.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/win32/desktopmgmt/full-screen-optimization",
    scriptName: "11_game_hooks.ps1",
    impactoRendimiento:
      "Prioridad de ejecución en tiempo real aislada frente a hilos del sistema operativo, estabilizando los cuadros por segundo.",
    warning:
      "Módulo 100% seguro para Anti-Cheats (Vanguard, EasyAntiCheat, BattlEye). La prioridad se inyecta dinámicamente desde el backend de Rust.",
    details: [
      "Inyección de invalidación de escalado de PPP (High DPI) para eliminar la latencia por reescalado de pantalla.",
      "Forzado de pantalla completa exclusiva en archivos de configuración de juegos compatibles (como Unreal Engine).",
      "Limpieza quirúrgica de modificaciones IFEO inyectadas previamente por Overlord, preservando de forma 100% segura los hooks legítimos de Anti-Cheats (Vanguard, EAC).",
      "Aislamiento de persistencia de entorno mediante subllaves estructuradas con la ruta física completa del ejecutable.",
    ],
  },
  defenderExclusions: {
    id: "defenderExclusions",
    title: "Exclusiones de Windows Defender",
    description:
      "Añade las carpetas de instalación de tus juegos a la lista de exclusiones de Windows Defender para evitar micro-stutters causados por el escaneo en tiempo real.",
    riesgo: "Balanceado",
    warning:
      "Esta optimización crea una excepción en el escaneo en tiempo real de Windows Defender para las carpetas de los juegos detectados. Esto mejora el rendimiento, pero significa que los archivos dentro de esas carpetas específicas no serán analizados.",
    evidenciaImpacto: "Comprobado",
    reversible: true,
    metodoReversion:
      "Eliminación exclusiva de las rutas del catálogo agregadas previamente por Overlord, conservando tus exclusiones manuales.",
    hardwareRecomendado: "Cualquier PC (especialmente laptops y sistemas con CPUs limitadas).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/powershell/module/defender/add-mppreference",
    scriptName: "12_defender_exclusions.ps1",
    impactoRendimiento:
      "Evita el consumo repentino de CPU y stutters por parte de Antimalware Service Executable (MsMpEng.exe) al leer los recursos del juego.",
    details: [
      "Resolución dinámica de las carpetas de instalación de todos tus juegos del catálogo.",
      "Uso del cmdlet oficial Add-MpPreference de Windows Defender.",
      "Persistencia de la lista de directorios agregados en la base de datos de Overlord para una reversión quirúrgica no destructiva.",
    ],
  },
};
