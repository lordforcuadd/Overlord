export interface RegistryValueMapping {
  hive: "HKEY_LOCAL_MACHINE" | "HKEY_CURRENT_USER";
  path: string;
  valueName: string;
  valueType: "REG_DWORD" | "REG_SZ" | "REG_BINARY" | "REG_MULTI_SZ";
  fallbackValue: string | number | boolean | null;
}

export interface TweakMetadata {
  id: string;
  title: string;
  description: string;
  riesgo: "Seguro" | "Balanceado" | "Experimental";
  reversible: boolean;
  metodoReversion: string;
  hardwareRecomendado: string;
  windowsVersion: string;
  fuenteOficial: string;
  scriptName: string;
  impactoRendimiento: string;
  warning?: string;
  details: string[];
  registryMapping: RegistryValueMapping[];
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
  ],
  Programador: ["debloat", "smartStorage", "generalPerformance"],
  "Home Office / Laptops": [
    "debloat",
    "smartStorage",
    "networkOptimized",
  ],
  "Usuario Casual": ["debloat", "smartStorage"],
};

export const tweaksMetadata: Record<string, TweakMetadata> = {
  peripheralLatency: {
    id: "peripheralLatency",
    title: "Respuesta de Teclado y Ratón",
    description:
      "Desactiva la aceleración del puntero, optimiza los tiempos de repetición del teclado y deshabilita la suspensión selectiva de puertos USB para reducir la latencia de respuesta.",
    riesgo: "Seguro",
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
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\PriorityControl",
        valueName: "Win32PrioritySeparation",
        valueType: "REG_DWORD",
        fallbackValue: 2,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Mouse",
        valueName: "MouseSpeed",
        valueType: "REG_SZ",
        fallbackValue: "1",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Mouse",
        valueName: "MouseThreshold1",
        valueType: "REG_SZ",
        fallbackValue: "6",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Mouse",
        valueName: "MouseThreshold2",
        valueType: "REG_SZ",
        fallbackValue: "10",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Accessibility\\Keyboard Response",
        valueName: "Flags",
        valueType: "REG_SZ",
        fallbackValue: "126",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Accessibility\\Keyboard Response",
        valueName: "AutoRepeatDelay",
        valueType: "REG_SZ",
        fallbackValue: "1000",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Accessibility\\Keyboard Response",
        valueName: "AutoRepeatRate",
        valueType: "REG_SZ",
        fallbackValue: "500",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Accessibility\\Keyboard Response",
        valueName: "DelayBeforeAcceptance",
        valueType: "REG_SZ",
        fallbackValue: "1000",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Accessibility\\Keyboard Response",
        valueName: "BounceTime",
        valueType: "REG_SZ",
        fallbackValue: "0",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Accessibility\\StickyKeys",
        valueName: "Flags",
        valueType: "REG_SZ",
        fallbackValue: "510",
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Accessibility\\ToggleKeys",
        valueName: "Flags",
        valueType: "REG_SZ",
        fallbackValue: "62",
      },
    ],
  },
  debloat: {
    id: "debloat",
    title: "Limpieza del Sistema (Debloat)",
    description:
      "Elimina aplicaciones preinstaladas (Bloatware) y desactiva servicios innecesarios que consumen ciclos de CPU y RAM.",
    riesgo: "Seguro",
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
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection",
        valueName: "AllowTelemetry",
        valueType: "REG_DWORD",
        fallbackValue: 3,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Software\\Microsoft\\Windows\\CurrentVersion\\Search",
        valueName: "BingSearchEnabled",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Software\\Microsoft\\Windows\\CurrentVersion\\Search",
        valueName: "CortanaConsent",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Software\\Microsoft\\Windows\\CurrentVersion\\BackgroundAccessApplications",
        valueName: "GlobalUserDisabled",
        valueType: "REG_DWORD",
        fallbackValue: 0,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Edge",
        valueName: "StartupBoostEnabled",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Edge",
        valueName: "BackgroundModeEnabled",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Software\\Policies\\Microsoft\\Windows\\WindowsCopilot",
        valueName: "TurnOffWindowsCopilot",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsCopilot",
        valueName: "TurnOffWindowsCopilot",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
    ],
  },
  networkOptimized: {
    id: "networkOptimized",
    title: "Optimización de Internet",
    description:
      "Desactiva el algoritmo de Nagle (TcpNoDelay) y elimina el estrangulamiento de red multimedia del sistema operativo para bajar el jitter de red.",
    riesgo: "Seguro",
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
      "Desactivación de Large Send Offload (LSO) y Receive Segment Coalescing (RSC) en adaptadores de red para eliminar jitter.",
      "Configuración del perfil RSS a Closest para minimizar fallos de caché L3 de la CPU al procesar interrupciones.",
      "Desactivación de modos de ahorro Ethernet (EEE, Green Energy) y coalescencia de paquetes, control de flujo y moderación de interrupciones (adaptativo en escritorio con >8 hilos lógicos).",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile",
        valueName: "NetworkThrottlingIndex",
        valueType: "REG_DWORD",
        fallbackValue: 10,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile",
        valueName: "SystemResponsiveness",
        valueType: "REG_DWORD",
        fallbackValue: 20,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters",
        valueName: "InitialRto",
        valueType: "REG_DWORD",
        fallbackValue: 3000,
      },
    ],
  },
  generalPerformance: {
    id: "generalPerformance",
    title: "Potencia Bruta y Procesador",
    description:
      "Configura la compresión adaptativa de RAM y desactiva el servicio de captura automática de juegos (GameDVR) para liberar recursos de CPU.",
    riesgo: "Seguro",
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
    ],
    registryMapping: [
      {
        hive: "HKEY_CURRENT_USER",
        path: "System\\GameConfigStore",
        valueName: "GameDVR_Enabled",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games",
        valueName: "Scheduling Category",
        valueType: "REG_SZ",
        fallbackValue: "Medium",
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games",
        valueName: "SFIO Priority",
        valueType: "REG_SZ",
        fallbackValue: "Normal",
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games",
        valueName: "Priority",
        valueType: "REG_DWORD",
        fallbackValue: 2,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games",
        valueName: "GPU Priority",
        valueType: "REG_DWORD",
        fallbackValue: 8,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games",
        valueName: "Clock Rate",
        valueType: "REG_DWORD",
        fallbackValue: 10,
      },
    ],
  },
  disableMitigations: {
    id: "disableMitigations",
    title: "Desactivar Mitigaciones de CPU",
    description:
      "Desactiva las mitigaciones Spectre y Meltdown a nivel de Kernel para recuperar ciclos de reloj en procesadores legacy.",
    riesgo: "Experimental",
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
      "Incremento de hasta un 10-15% en throughput de CPU en procesadores antiguos vulnerables.",
    warning:
      "Desactivar mitigaciones expone al procesador a vulnerabilidades de ejecución especulativa de canal lateral.",
    details: [
      "Inhabilitación de mitigaciones de speculative execution (Spectre/Meltdown).",
      "Restauración del rendimiento perdido por parches de seguridad de kernel.",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management",
        valueName: "FeatureSettingsOverride",
        valueType: "REG_DWORD",
        fallbackValue: 0,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management",
        valueName: "FeatureSettingsOverrideMask",
        valueType: "REG_DWORD",
        fallbackValue: 0,
      },
    ],
  },
  gpuDisplay: {
    id: "gpuDisplay",
    title: "Fluidez de Pantalla y Gráficos",
    description:
      "Ajusta la prioridad del planificador gráfico oficial (HAGS) y desactiva la captura en segundo plano de GameBar para evitar caídas de FPS.",
    riesgo: "Seguro",
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
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers",
        valueName: "HwSchMode",
        valueType: "REG_DWORD",
        fallbackValue: 2,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Windows\\GameDVR",
        valueName: "AllowGameDVR",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Software\\Microsoft\\Windows\\CurrentVersion\\GameDVR",
        valueName: "AppCaptureEnabled",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
    ],
  },
  irqAffinity: {
    id: "irqAffinity",
    title: "Afinidad de Hardware (IRQ)",
    description:
      "Aísla de forma exclusiva las cargas de interrupciones físicas de red fuera de los hilos principales del sistema operativo.",
    riesgo: "Experimental",
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
    ],
    registryMapping: [],
  },
  smartStorage: {
    id: "smartStorage",
    title: "Almacenamiento Inteligente",
    description:
      "Optimiza el sistema de archivos NTFS desactivando LastAccessUpdate y deshabilita el Inicio Rápido para evitar fugas de memoria.",
    riesgo: "Seguro",
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
    warning:
      "La consolidación profunda del almacén de componentes de Windows mediante DISM cuenta con un tiempo extendido para completarse.",
    details: [
      "Desactivación de la actualización de marcas de tiempo (Last Access Update) para mitigar ciclos de degradación en SSD.",
      "Desactivación universal de la creación de nombres de archivo cortos en formato MS-DOS 8.3 para acelerar el sistema de archivos.",
      "Optimización adaptativa de la caché de metadatos NTFS (NtfsMemoryUsage = 2) en sistemas con >= 16 GB de RAM.",
      "Desactivación completa de la hibernación y remoción del archivo fantasma persistente Hiberfil.sys (en desktops).",
      "Desactivación de Inicio Rápido (HiberbootEnabled = 0) para forzar un apagado limpio del kernel de Windows.",
      "Ejecución y consolidación del almacén de componentes WinSxS mediante comandos DISM.",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\FileSystem",
        valueName: "NtfsDisableLastAccessUpdate",
        valueType: "REG_DWORD",
        fallbackValue: 0,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\FileSystem",
        valueName: "NtfsDisable8dot3NameCreation",
        valueType: "REG_DWORD",
        fallbackValue: 2,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\FileSystem",
        valueName: "NtfsMemoryUsage",
        valueType: "REG_DWORD",
        fallbackValue: 0,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power",
        valueName: "HiberbootEnabled",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
    ],
  },
  deepTelemetry: {
    id: "deepTelemetry",
    title: "Blindaje de Seguridad y Privacidad",
    description:
      "Purga por completo los flujos ocultos de recolección de diagnóstico, detiene event loggers y tareas programadas del sistema.",
    riesgo: "Experimental",
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
      "Bloqueo perimetral en el Firewall de Windows para los ejecutables de recolección nativos (CompatTelRunner, etc.).",
      "Detención e inhabilitación asíncrona de Autologgers ocultos del Visor de Eventos de Windows.",
      "Bloqueo total de Windows Recall y captura de actividad local de Inteligencia Artificial (Windows AI).",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        valueName: "PublishUserActivities",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows\\Windows Error Reporting",
        valueName: "Disabled",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsAI",
        valueName: "TurnOffUserCameraCapture",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsAI",
        valueName: "DisableAIDataAnalysis",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Software\\Policies\\Microsoft\\Windows\\WindowsAI",
        valueName: "TurnOffUserCameraCapture",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Software\\Policies\\Microsoft\\Windows\\WindowsAI",
        valueName: "DisableAIDataAnalysis",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
    ],
  },
  powerProfiles: {
    id: "powerProfiles",
    title: "Perfiles de Energía",
    description:
      "Inyecta el esquema energético de Máximo Rendimiento y deshabilita el Core Parking en PCs de escritorio.",
    riesgo: "Balanceado",
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
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\Power\\PowerThrottling",
        valueName: "PowerThrottlingOff",
        valueType: "REG_DWORD",
        fallbackValue: 0,
      },
    ],
  },
  gameHooks: {
    id: "gameHooks",
    title: "Prioridad Absoluta para Juegos",
    description:
      "Fuerza el bypass gráfico de pantalla completa optimizada e inicializa el monitor dinámico de hilos en memoria RAM.",
    riesgo: "Seguro",
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
      "Eliminación de modificaciones IFEO estáticas en el registro de Windows para erradicar por completo falsos positivos.",
      "Aislamiento de persistencia de entorno mediante subllaves estructuradas con la ruta física completa del ejecutable.",
    ],
    registryMapping: [],
  },
};
