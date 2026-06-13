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

export const tweaksMetadata: Record<string, TweakMetadata> = {
  peripheralLatency: {
    id: "peripheralLatency",
    title: "Respuesta de Teclado y Ratón",
    description:
      "Optimiza el tamaño de la cola de procesamiento de los controladores HID nativos para reducir el tiempo de respuesta de los periféricos e inyecta MSI Mode.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Restauración de valores por defecto en los servicios nativos mouclass y kbdclass, y limpieza de la llave MSI en el registro de Windows.",
    hardwareRecomendado:
      "Cualquier placa base con controladores de bus USB xHCI nativos de Intel o AMD.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/keyboard-and-mouse-class-drivers",
    scriptName: "01_perifericos.ps1",
    impactoRendimiento:
      "Reducción medible del Input Lag del sistema y mayor consistencia del puntero en periféricos de alta tasa de sondeo (polling rate).",
    warning:
      "Forzar el modo MSI en concentradores USB e inyectar buffers de cola de datos avanzados requiere reiniciar el equipo.",
    details: [
      "Inyección de Message Signaled Interrupts (MSI Mode) seguro en controladores USB y GPU.",
      "Optimización de búferes de cola de datos físicos (Mouse y KeyboardDataQueueSize a 128 hilos).",
      "Eliminación absoluta de aceleración por software y filtrado SmoothMouseCurve en el registro.",
      "Desactivación estricta de filtros de accesibilidad intrusivos (StickyKeys, ToggleKeys y FilterKeys).",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Services\\mouclass\\Parameters",
        valueName: "MouseDataQueueSize",
        valueType: "REG_DWORD",
        fallbackValue: 100,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Services\\kbdclass\\Parameters",
        valueName: "KeyboardDataQueueSize",
        valueType: "REG_DWORD",
        fallbackValue: 100,
      },
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
        valueName: "SmoothMouseXCurve",
        valueType: "REG_BINARY",
        fallbackValue: null,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Control Panel\\Mouse",
        valueName: "SmoothMouseYCurve",
        valueType: "REG_BINARY",
        fallbackValue: null,
      },
    ],
  },
  debloat: {
    id: "debloat",
    title: "Limpieza del Sistema (Debloat)",
    description:
      "Elimina aplicaciones preinstaladas (Bloatware) y aprovisionamientos de fábrica que consumen recursos en segundo plano.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Reinstalación manual desde la Microsoft Store o restauración de servicios nativos deshabilitados mediante el módulo de reversión.",
    hardwareRecomendado: "General.",
    windowsVersion: "Windows 10 / Windows 11 (Home y Pro)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage",
    scriptName: "02_debloat.ps1",
    impactoRendimiento:
      "Liberación de memoria RAM física y reducción del recuento total de procesos activos en segundo plano.",
    warning:
      "Este process preserva la Microsoft Store y la App de Xbox para mantener intacto tu entorno gaming y de desarrollo.",
    details: [
      "Remoción de software preinstalado innecesario (Cortana, Bing, Weather, Maps, etc.).",
      "Eliminación de telemetría GPO básica y sugerencias web invasivas de Bing en el menú de inicio.",
      "Remoción estructural de las barras laterales y servicios de Windows Copilot.",
      "Detención inteligente del servicio de impresión Spooler si no se detectan impresoras físicas.",
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
    ],
  },
  networkOptimized: {
    id: "networkOptimized",
    title: "Optimización de Internet",
    description:
      "Configura el TTL de la caché DNS, mitiga el throttling de red del sistema operativo y optimiza los tiempos de espera de la pila TCP/IP.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Restauración de los valores originales de ThrottlingIndex, TcpTimedWaitDelay y desocupación de la caché DNS.",
    hardwareRecomendado:
      "Conexiones por cable Ethernet o adaptadores Wi-Fi modernos.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/networking/technologies/tcp-ip/tcp-ip-performance-tuning",
    scriptName: "03_red.ps1",
    impactoRendimiento:
      "Erradicación del jitter de red, elimination de picos de lag por estrangulamiento y consistencia extrema en el registro de disparos (hitreg).",
    details: [
      "Erradicación total del estrangulamiento de ancho de banda (NetworkThrottlingIndex deshabilitado).",
      "Reducción agresiva del tiempo de espera de reutilización de puertos de red (TcpTimedWaitDelay a 30s).",
      "Desactivación de Receive Segment Coalescing (RSC) global para eliminar el retraso de acumulación de paquetes.",
      "Estabilización de persistencia de resolución DNS (TTL 86400) y apagado de túneles fantasma IPv6.",
      "Prioridad de CPU dedicada (SystemResponsiveness = 10) para evitar que procesos secundarios estrangulen el hilo del juego.",
      "Autosintonización TCP forzada a normal para desatar el ancho de banda y desactivación de ECN para prevenir pérdidas de paquetes.",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters",
        valueName: "MaxCacheTtl",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters",
        valueName: "TcpTimedWaitDelay",
        valueType: "REG_DWORD",
        fallbackValue: 30,
      },
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
    ],
  },
  generalPerformance: {
    id: "generalPerformance",
    title: "Potencia Bruta y Procesador",
    description:
      "Optimiza la paginación de la memoria del Kernel, gestiona la compresión de RAM y mitiga el impacto de las transiciones de estados energéticos.",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Restauración de las llaves del planificador de memoria y conmutación adaptativa de la compresión de sistema.",
    hardwareRecomendado:
      "Equipos con procesadores multinúcleo y configuraciones de memoria DDR4 / DDR5.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/commercialize/performance/rules/paging-executive",
    scriptName: "04_rendimiento.ps1",
    impactoRendimiento:
      "Aumento de la estabilidad de los relojes de CPU, menor latencia en el intercambio de memoria y FPS mínimos más altos.",
    warning:
      "Desactivar mitigaciones Spectre/Meltdown en CPUs legacy recupera ciclos de reloj pero expone al procesador a vulnerabilidades teóricas de canal lateral (Speculative Execution).",
    details: [
      "Inyección de Kernel residente en RAM (DisablePagingExecutive) para suprimir accesos lentos a disco.",
      "Desactivación del limpiador del archivo de paginación para agilizar los ciclos de arranque y apagado.",
      "Gestión adaptativa de MMAgent (Memory Compression) optimizada según la cantidad total de RAM detectada.",
      "Apagado total de los servicios de grabación en segundo plano y capturas automáticas de GameDVR.",
      "Desactivación de Page Combining en MMAgent para ahorrar ciclos de CPU y mitigar micro-stutters.",
      "Aislamiento de servicios svchost por proceso para reducir la contención del planificador (svchost splitting).",
      "Ajuste lógico de temporización de reloj (BCDedit) para desactivar Dynamic Ticks e HPET y priorizar TSC.",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management",
        valueName: "DisablePagingExecutive",
        valueType: "REG_DWORD",
        fallbackValue: 0,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management",
        valueName: "ClearPageFileAtShutdown",
        valueType: "REG_DWORD",
        fallbackValue: 0,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "System\\GameConfigStore",
        valueName: "GameDVR_Enabled",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "Software\\Microsoft\\FTH",
        valueName: "Enabled",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control",
        valueName: "SvcHostSplitThresholdInKB",
        valueType: "REG_DWORD",
        fallbackValue: 3800000,
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
      "Restauración de las llaves del planificador de memoria y reactivación de las directivas de seguridad nativas.",
    hardwareRecomendado:
      "Procesadores legacy (Intel Core 9th Gen o anterior, AMD Ryzen 3000 o anterior) que sufren sobrecarga por los parches de seguridad.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://support.microsoft.com/en-us/topic/kb4073119-guidance-to-protect-against-speculative-execution-side-channel-vulnerabilities-in-windows-devices-419d691e-3652-32b0-951b-cb6104f7b494",
    scriptName: "disable_mitigations.ps1",
    impactoRendimiento:
      "Incremento de hasta un 10-15% en throughput y rendimiento de CPU de un solo núcleo en procesadores vulnerables.",
    warning:
      "Desactivar mitigaciones Spectre/Meltdown en CPUs legacy recupera ciclos de reloj pero expone al procesador a vulnerabilidades teóricas de canal lateral (Speculative Execution).",
    details: [
      "Inhabilitación de mitigaciones de speculative execution (Spectre/Meltdown).",
      "Restauración del rendimiento perdido por parches de seguridad de kernel.",
      "Optimización enfocada a procesadores antiguos sin mitigaciones en silicio.",
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
      "Ajusta la prioridad del planificador gráfico oficial (HAGS) y optimiza el Frame Pacing eliminando superposiciones conflictivas.",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Remoción de la subclave PerfOptions de dwm.exe e inversión de la directiva global de HAGS al valor por defecto.",
    hardwareRecomendado:
      "Tarjetas gráficas dedicadas modernas (NVIDIA GeForce / AMD Radeon / Intel Arc).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/win32/desktopmgmt/desktop-window-manager-overview",
    scriptName: "05_gpu_display.ps1",
    impactoRendimiento:
      "Eliminación absoluta de stuttering de escritorio, optimización de latencia gráfica y estabilidad de framerate.",
    details: [
      "Establece HwSchMode al valor oficial documentado (2) para la programación de GPU acelerada por hardware.",
      "Desactivación de GameBarPresenceWriter a nivel de usuario para prevenir micro-stutters y frametime spikes al iniciar juegos.",
      "Ajuste del timeout de detección y recuperación de GPU (TdrDelay = 10s) para mitigar crashes en motores UE5/DirectX 12.",
      "Activación de la optimización del Flip Presentation Model para juegos en modo ventana o ventana sin bordes.",
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
        path: "SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers",
        valueName: "TdrDelay",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_CURRENT_USER",
        path: "Software\\Microsoft\\DirectX\\UserGpuPreferences",
        valueName: "SwapEffectUpgradeDisable",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows\\Dwm",
        valueName: "OverlayTestMode",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
    ],
  },
  irqAffinity: {
    id: "irqAffinity",
    title: "Afinidad de Hardware (IRQ)",
    description:
      "Aísla de forma exclusiva las cargas de interrupciones físicas de red y audio fuera de los hilos principales del sistema operativo y núcleos de eficiencia.",
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
      "Reducción masiva de la latencia de llamadas de procedimiento diferidas (DPC Latency) y aislamiento térmico/de hilos.",
    warning:
      "Este módulo desactiva la distribución multicanal RSS de red para priorizar la latencia en el CPU. Puede limitar el ancho de banda máximo en conexiones de fibra de alta velocidad (>= 500 Mbps).",
    details: [
      "Cálculo topológico dinámico en tiempo de ejecución basado en el mapa de hilos físicos del procesador.",
      "Aislamiento exclusivo de las interrupciones de red (NIC Isolation) en el penúltimo P-Core físico libre.",
      "Aislamiento del búfer de audio multimedia (Multimedia Isolation) en el último P-Core físico limpio disponible.",
      "Ajuste de prioridades del planificador multimedia (MMCSS Tasks Games) a categoría High.",
    ],
    registryMapping: [
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
    ],
  },
  smartStorage: {
    id: "smartStorage",
    title: "Almacenamiento Inteligente",
    description:
      "Optimiza la asignación de memoria caché NTFS, deshabilita herencias restrictivas y consolida el espacio rígido de almacenamiento.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Restauración de los flags de comportamiento NTFS mediante comandos fsutil y reactivación de hibernación.",
    hardwareRecomendado:
      "Unidades de estado sólido sólidas (SSD SATA / NVMe M.2).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-government/administration/windows-commands/fsutil-behavior",
    scriptName: "07_almacenamiento.ps1",
    impactoRendimiento:
      "Optimiza los tiempos de carga de texturas in-game (streaming de assets) y mitiga escrituras redundantes en el SSD.",
    warning:
      "La consolidación profunda del almacén de componentes de Windows mediante DISM cuenta con un tiempo extendido para completarse.",
    details: [
      "Desactivación de la actualización de marcas de tiempo (Last Access Update) para mitigar ciclos de degradación en SSD.",
      "Aumento de la asignación de memoria caché NTFS y remoción de nombres cortos de archivos de estructura legacy 8dot3.",
      "Desactivación completa de la hibernación y remoción del archivo fantasma persistente Hiberfil.sys.",
      "Ejecución y consolidación del almacén de componentes WinSxS mediante comandos DISM con protección extendida.",
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
        path: "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management\\PrefetchParameters",
        valueName: "EnablePrefetcher",
        valueType: "REG_DWORD",
        fallbackValue: 3,
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
      "Purga por completo los flujos ocultos de recolección de diagnóstico, detiene event loggers y desactiva el aislamiento basado en virtualización (VBS/HVCI).",
    riesgo: "Experimental",
    reversible: true,
    metodoReversion:
      "Restauración de llaves DeviceGuard nativas y reconfiguración de loggers asíncronos al estado de fábrica.",
    hardwareRecomendado:
      "Computadoras enfocadas puramente al alto rendimiento gaming de baja latencia.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/security/hardware-security/virtualization-based-security",
    scriptName: "08_telemetria.ps1",
    impactoRendimiento:
      "Incremento dramático del throughput de la CPU y estabilización de FPS mínimos por eliminación de sobrecarga de virtualización.",
    warning:
      "Desactivar el aislamiento de Kernel (VBS/HVCI) incrementa el rendimiento y la consistencia de FPS, pero reduce la seguridad estructural de memoria del sistema operativo.",
    details: [
      "Análisis en caliente de BitLocker mediante WMI para evitar la corrupción de llaves de cifrado en el arranque.",
      "Erradicación definitiva del servicio de recolección de experiencias DiagTrack y del historial de actividades de usuario.",
      "Bloqueo perimetral en el Firewall de Windows para los ejecutables de recolección nativos (CompatTelRunner, etc.).",
      "Detención e inhabilitación asíncrona de Autologgers ocultos del Visor de Eventos de Windows.",
      "Desactivación completa del servicio y políticas de Windows Error Reporting (WER) para evitar el lanzamiento de WerFault.exe en bloqueos.",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\DeviceGuard",
        valueName: "EnableVirtualizationBasedSecurity",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\DeviceGuard\\Scenarios\\HypervisorEnforcedCodeIntegrity",
        valueName: "Enabled",
        valueType: "REG_DWORD",
        fallbackValue: null,
      },
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
    ],
  },
  powerProfiles: {
    id: "powerProfiles",
    title: "Perfiles de Energía",
    description:
      "Inyecta un esquema energético de ultra-baja latencia optimizado, gestiona de forma centralizada la suspensión USB y suprime el Core Parking.",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Eliminación del GUID del esquema Overlord y conmutación automática al plan equilibrado por defecto de Windows.",
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
      "Desactivación de la suspensión selectiva USB de forma centralizada y segura con soporte de backup.",
      "Ajuste del estacionamiento de núcleos (Core Parking) al 100% para evitar caídas y fluctuaciones de frecuencias.",
    ],
    registryMapping: [],
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
