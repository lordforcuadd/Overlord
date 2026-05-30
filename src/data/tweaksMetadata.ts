export interface RegistryValueMapping {
  hive: "HKEY_LOCAL_MACHINE" | "HKEY_CURRENT_USER";
  path: string;
  valueName: string;
  valueType: "REG_DWORD" | "REG_SZ" | "REG_BINARY" | "REG_MULTI_SZ";
  fallbackValue: any;
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
      "Optimiza el tamaño de la cola de procesamiento de los controladores HID nativos para reducir el tiempo de respuesta de los periféricos.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Restauración de valores por defecto en los servicios nativos mouclass y kbdclass del registro de Windows.",
    hardwareRecomendado:
      "Cualquier placa base con controladores de bus USB xHCI nativos de Intel o AMD.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/keyboard-and-mouse-class-drivers",
    scriptName: "01_perifericos.ps1",
    impactoRendimiento:
      "Reducción medible del Input Lag del sistema y mayor consistencia del puntero en periféricos de alta tasa de sondeo (polling rate).",
    details: [
      "Respuesta inmediata de teclado y ratón",
      "Buffers de clase USB optimizados para alta frecuencia",
      "Aceleración del ratón heredada 100% desactivada",
      "Desactivación del retraso de accesibilidad (Teclas pegajosas)",
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
      "Reinstalación manual desde la Microsoft Store o comandos Get-AppxPackage de aprovisionamiento base.",
    hardwareRecomendado: "General.",
    windowsVersion: "Windows 10 / Windows 11 (Home y Pro)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage",
    scriptName: "02_debloat.ps1",
    impactoRendimiento:
      "Liberación de memoria RAM física y reducción del recuento total de procesos activos.",
    details: [
      "Remoción de software preinstalado innecesario",
      "Eliminación de telemetría básica del sistema operativo",
      "Detención de servicios auxiliares pesados en segundo plano",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection",
        valueName: "AllowTelemetry",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
    ],
  },
  networkOptimized: {
    id: "networkOptimized",
    title: "Optimización de Internet",
    description:
      "Configura el TTL de la caché DNS para estabilidad de resolución y habilita RSC/LSO para descarga de procesamiento de red.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Comandos netsh int tcp reset y remoción de las llaves MaxCacheTtl creadas en el Dnscache.",
    hardwareRecomendado: "Conexiones por cable Ethernet.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/networking/technologies/tcp-ip/tcp-ip-performance-tuning",
    scriptName: "03_red.ps1",
    impactoRendimiento:
      "Estabilidad DNS integral. No aumenta la velocidad, mejora la consistencia de resolución.",
    details: [
      "Optimización del búfer de recepción y transmisión de la pila de red (RSC/LSO)",
      "Estabilización de persistencia de resolución DNS (TTL 86400)",
      "Desactivación de timestamps TCP para reducir overhead de cabecera",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters",
        valueName: "MaxCacheTtl",
        valueType: "REG_DWORD",
        fallbackValue: 86400,
      },
    ],
  },
  generalPerformance: {
    id: "generalPerformance",
    title: "Potencia Bruta y Procesador",
    description:
      "Desbloquea los esquemas de energía y ajusta la gestión de memoria del Kernel.",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Restauración del FeatureSettingsOverride a valor cero y conmutación al plan de energía Equilibrado.",
    hardwareRecomendado: "Procesadores de escritorio (Desktops).",
    windowsVersion: "Windows 10 v1809+ / Windows 11",
    fuenteOficial:
      "https://support.microsoft.com/en-us/topic/kb4073119-guidance-to-mitigate-speculative-execution-side-channel-vulnerabilities",
    scriptName: "04_rendimiento.ps1",
    impactoRendimiento:
      "Aumento de la estabilidad del reloj de CPU y reducción de latencia de paginación del Kernel.",
    details: [
      "Inyección del Plan de Energía Máxima de Windows (Ultimate Performance)",
      "Reducción de latencia en la gestión de memoria del Kernel",
      "Tradeoff de seguridad: Ajuste de mitigaciones de vulnerabilidades de silicio de la CPU",
      "Limpieza automatizada de directorios temporales del sistema",
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
      "Ajusta la prioridad del planificador gráfico y la programación de GPU acelerada (HAGS).",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Remoción de la subclave PerfOptions de dwm.exe e inversión de la directiva global de HAGS.",
    hardwareRecomendado:
      "Tarjetas gráficas dedicadas modernas (RTX 3000+, RX 6000+).",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/win32/desktopmgmt/desktop-window-manager-overview",
    scriptName: "05_gpu_display.ps1",
    impactoRendimiento:
      "Eliminación de stuttering de escritorio y optimización del Frame Pacing en juegos.",
    details: [
      "Eliminación de micro-tirones gráficos",
      "Establece HwSchMode al valor oficial documentado (2) para Programación de GPU",
      "Establece prioridad alta para DWM (Desktop Window Manager)",
      "Desactivación completa de GameDVR",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers",
        valueName: "HwSchMode",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options\\dwm.exe\\PerfOptions",
        valueName: "CpuPriorityClass",
        valueType: "REG_DWORD",
        fallbackValue: 2,
      },
    ],
  },
  irqAffinity: {
    id: "irqAffinity",
    title: "Organización del Procesador",
    description:
      "Ajusta la afinidad de interrupciones de red para evitar colisiones en el Core 0.",
    riesgo: "Experimental",
    reversible: true,
    metodoReversion: "Eliminación de la máscara binaria AssignmentSetOverride.",
    hardwareRecomendado: "Procesadores multinúcleo (Multi-CCD o Híbridos).",
    windowsVersion: "Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/interrupt-affinity-and-priority",
    scriptName: "06_irq_affinity.ps1",
    impactoRendimiento:
      "Reduce latencia DPC al distribuir carga de interrupciones fuera de los núcleos principales de juego.",
    details: [
      "Aislamiento de la carga de red",
      "Distribución balanceada de solicitudes IRQ",
      "Mejora los tiempos de respuesta de E/S",
    ],
    registryMapping: [],
  },
  smartStorage: {
    id: "smartStorage",
    title: "Aceleración de Disco",
    description:
      "Optimiza el sistema de archivos NTFS para reducir la latencia de acceso a disco.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Comandos fsutil behavior set para habilitar de nuevo LastAccessUpdate y balancear MemoryUsage.",
    hardwareRecomendado: "Unidades SSD.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-behavior",
    scriptName: "07_almacenamiento.ps1",
    impactoRendimiento:
      "Mejora tiempos de carga de texturas y acceso a archivos pequeños.",
    details: [
      "Aumento de búfer de lectura NTFS",
      "Desactivación de marca de tiempo LastAccess",
      "Desactivación de hibernación",
      "Limpieza de archivos temporales",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\FileSystem",
        valueName: "NtfsDisableLastAccessUpdate",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
    ],
  },
  deepTelemetry: {
    id: "deepTelemetry",
    title: "Blindaje de Seguridad y Privacidad",
    description:
      "Desactiva servicios de diagnóstico, bloquea conexiones de telemetría y ajusta el aislamiento de Kernel (VBS/HVCI).",
    riesgo: "Experimental",
    reversible: true,
    metodoReversion:
      "Reactivación de servicios y restauración de claves DeviceGuard.",
    hardwareRecomendado: "Computadoras de alto rendimiento para gaming.",
    windowsVersion: "Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/security/hardware-security/virtualization-based-security",
    scriptName: "08_telemetria.ps1",
    impactoRendimiento:
      "Aumento de FPS por reducción de sobrecarga de virtualización (Tradeoff de seguridad).",
    warning:
      "Deshabilitar VBS puede romper Anti-Cheats (Vanguard, etc.) y protección contra rootkits. ¿Continuar?",
    details: [
      "Apaga capas de aislamiento que reducen el throughput de la CPU",
      "Detiene servicios de diagnóstico y reporte de Microsoft",
      "Bloqueo de salida de red para herramientas de telemetría",
    ],
    registryMapping: [
      {
        hive: "HKEY_LOCAL_MACHINE",
        path: "SYSTEM\\CurrentControlSet\\Control\\DeviceGuard\\Scenarios\\HypervisorEnforcedCodeIntegrity",
        valueName: "Enabled",
        valueType: "REG_DWORD",
        fallbackValue: 1,
      },
    ],
  },
  powerProfiles: {
    id: "powerProfiles",
    title: "Energía Inteligente",
    description:
      "Ajusta los estados de energía de buses PCIe y evita estados de reposo profundo de la CPU.",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Comando powercfg -setactive para reasignar plan de energía.",
    hardwareRecomendado: "Computadoras de escritorio.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options",
    scriptName: "09_energia.ps1",
    impactoRendimiento:
      "Consistencia total en frecuencias de CPU y reducción de latencia al despertar dispositivos.",
    details: [
      "Bus PCIe al máximo rendimiento eléctrico",
      "Evita el aparcado de núcleos lógicos",
      "Gestión de termales optimizada",
    ],
    registryMapping: [],
  },
  gameHooks: {
    id: "gameHooks",
    title: "Prioridad Absoluta para Juegos",
    description:
      "Ajusta las prioridades de ejecución mediante Image File Execution Options (IFEO).",
    riesgo: "Experimental",
    reversible: true,
    metodoReversion: "Purga de la clave IFEO del ejecutable.",
    hardwareRecomendado: "Sistemas dependientes de rendimiento mononúcleo.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/image-file-execution-options",
    scriptName: "11_game_hooks.ps1",
    impactoRendimiento:
      "Prioridad de ejecución frente a procesos en segundo plano.",
    warning: "Puede generar falsos positivos en Anti-Cheats. ¿Continuar?",
    details: [
      "Asignación de prioridad alta a procesos de juego",
      "Prioridad de E/S alta para procesos de juego",
    ],
    registryMapping: [],
  },
};
