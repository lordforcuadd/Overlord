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
      "Optimiza la frecuencia de muestreo y los tiempos de procesamiento de los controladores de clase de entrada en Windows. Elimina retrasos de búfer acumulados en los puertos USB.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Restauración de valores por defecto en los servicios nativos mouclass y kbdclass del registro de Windows.",
    hardwareRecomendado:
      "Cualquier placa base con controladores de bus USB xHCI nativos de Intel o AMD.",
    windowsVersion: "Windows 10 / Windows 11 (Todas las versiones)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/keyboard-and-mouse-class-drivers",
    scriptName: "01_perifericos.ps1",
    impactoRendimiento:
      "Reducción medible del Input Lag del sistema y mayor consistencia del puntero.",
    details: [
      "Respuesta inmediata de teclado y ratón",
      "Puertos USB configurados en modo de alto rendimiento",
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
      "Elimina paquetes de aplicaciones preinstaladas (Bloatware) y aprovisionamientos de fábrica de Windows que consumen ciclos de reloj del procesador y espacio en disco.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Reinstalación manual desde la Microsoft Store o comandos Get-AppxPackage de aprovisionamiento base.",
    hardwareRecomendado:
      "Setups de hardware comprometido, discos mecánicos HDD o almacenamiento particionado limitado.",
    windowsVersion: "Windows 10 / Windows 11 (Home y Pro)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage",
    scriptName: "02_debloat.ps1",
    impactoRendimiento:
      "Liberación de memoria RAM física y reducción del recuento total de procesos activos en el Administrador de Tareas.",
    details: [
      "Remoción limpia de telemetría básica del sistema operativo",
      "Eliminación de aplicaciones universales preinstaladas inútiles",
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
      "Configura directivas del planificador de paquetes TCP/IP nativo de Windows y optimiza el almacenamiento en caché del servicio DNS para evitar pérdidas de paquetes en saltos de red.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Comandos netsh int tcp reset y remoción de las llaves MaxCacheTtl creadas en el Dnscache.",
    hardwareRecomendado:
      "Conexiones por cable Ethernet de alta velocidad, adaptadores Intel e1000e o Realtek PCIe Gaming.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/networking/technologies/tcp-ip/tcp-ip-performance-tuning",
    scriptName: "03_red.ps1",
    impactoRendimiento:
      "Estabilización del Ping interno (Latencia Jitter) en títulos competitivos multijugador.",
    details: [
      "Envío eficiente de tramas y paquetes de datos",
      "Optimización del búfer de recepción y transmisión de la pila de red",
      "Aceleración de resolución de nombres de dominio (Caché DNS)",
      "Estabilización de directivas frente a micro-cortes de hardware",
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
      "Desbloquea los esquemas de energía ocultos de Windows diseñados para hardware de alto rendimiento y gestiona las mitigaciones de ejecución especulativa de la CPU.",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Restauración del FeatureSettingsOverride a valor cero y conmutación al plan de energía Equilibrado.",
    hardwareRecomendado:
      "Procesadores de escritorio de más de 6 núcleos físicos con soluciones térmicas estables independientes.",
    windowsVersion: "Windows 10 v1809+ / Windows 11",
    fuenteOficial:
      "https://support.microsoft.com/en-us/topic/kb4073119-guidance-to-mitigate-speculative-execution-side-channel-vulnerabilities",
    scriptName: "04_rendimiento.ps1",
    impactoRendimiento:
      "Aumento de la velocidad de reloj sostenida del procesador y reducción de caídas bruscas de FPS (1% Low FPS).",
    details: [
      "Inyección del Plan de Energía Máxima de Windows (Ultimate Performance)",
      "Reducción de tirones térmicos o energéticos del planificador de núcleos",
      "Ajuste opcional de mitigaciones de vulnerabilidades de silicio de la CPU",
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
      "Ajusta los parámetros del Administrador de Ventanas del Escritorio (DWM) y reconfigura las directivas de Optimización de Optimización de Pantalla Completa y Multiplane Overlays (MPO).",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Remoción de la subclave PerfOptions de dwm.exe e inversión de la directiva global de mitigación de MPO.",
    hardwareRecomendado:
      "Tarjetas gráficas dedicadas NVIDIA GTX/RTX o AMD Radeon RX con controladores actualizados.",
    windowsVersion: "Windows 10 / Windows 11 (Compilaciones de producción)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/win32/desktopmgmt/desktop-window-manager-overview",
    scriptName: "05_gpu_display.ps1",
    impactoRendimiento:
      "Eliminación del parpadeo visual (Stuttering) y optimización del Frame Pacing gráfico.",
    details: [
      "Eliminación de micro-tirones gráficos causados por la composición de ventanas",
      "Establece HwSchMode al valor oficial documentado (1) para Programación de GPU",
      "Desactivación completa de servicios superpuestos de la Barra de Juegos de Windows",
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
      "Enruta las interrupciones físicas por hardware de tus adaptadores (Red, GPU) a núcleos específicos del procesador, liberando el Core 0 de cuellos de botella.",
    riesgo: "Experimental",
    reversible: true,
    metodoReversion:
      "Eliminación de la máscara binaria AssignmentSetOverride dentro de la directiva de Interrupt Management.",
    hardwareRecomendado:
      "Computadoras con procesadores modernos que posean arquitecturas de núcleos híbridos (P-Cores y E-Cores).",
    windowsVersion: "Windows 11 Obligatorio para una gestión de hilos óptima",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/interrupt-affinity-and-priority",
    scriptName: "06_irq_affinity.ps1",
    impactoRendimiento:
      "Evita picos de retraso (DPC Latency) provocados por colisiones de peticiones de red y renderizado simultáneos.",
    details: [
      "Aislamiento de la carga de red del hilo principal del juego",
      "Distribución balanceada de solicitudes IRQ en procesadores multinúcleo",
      "Mejora los tiempos de respuesta de entrada/salida de dispositivos críticos",
    ],
    registryMapping: [],
  },
  smartStorage: {
    id: "smartStorage",
    title: "Aceleración de Disco y Almacenamiento",
    description:
      "Ajusta los parámetros del sistema de archivos NTFS aumentando la asignación del búfer de memoria caché de paginación y deshabilita escrituras cosméticas innecesarias.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Comandos fsutil behavior set para habilitar de nuevo LastAccessUpdate y balancear MemoryUsage.",
    hardwareRecomendado:
      "Unidades de estado sólido SSD NVMe M.2 o SSD SATA III. Evitar en configuraciones RAID complejas.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-behavior",
    scriptName: "07_almacenamiento.ps1",
    impactoRendimiento:
      "Reducción en los tiempos de carga inicial de mapas pesados y texturas dentro del juego.",
    details: [
      "Duplica el tamaño del búfer de lectura NTFS del sistema operativo",
      "Desactiva la actualización de marca de tiempo de último acceso a archivos para mitigar escrituras",
      "Desactiva el archivo de hibernación masivo en equipos de escritorio",
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
    title: "Seguridad Virtual y Filtros",
    description:
      "Desactiva las funciones de aislamiento de núcleo, integridad de memoria basadas en hipervisor (HVCI) y detiene los recolectores de eventos de diagnóstico profundo de Microsoft.",
    riesgo: "Experimental",
    reversible: true,
    metodoReversion:
      "Habilitación explícita de DeviceGuard y escenarios HVCI desde el registro de Windows o directivas de grupo.",
    hardwareRecomendado:
      "Computadoras de escritorio dedicadas exclusivamente al entretenimiento, streaming o gaming competitivo.",
    windowsVersion:
      "Windows 11 (Sistemas con virtualización por hardware activa)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/security/hardware-security/virtualization-based-security",
    scriptName: "08_telemetria.ps1",
    impactoRendimiento:
      "Ganancia de rendimiento gráfico bruto en juegos pesados (aumento de hasta un 5-10% en FPS promedio).",
    warning:
      "Deshabilitar VBS rompe Valorant, Fortnite, Apex Legends, WSL2 y Docker Desktop. ¿Desea continuar?",
    details: [
      "Apaga el aislamiento de núcleo que sobrecarga la traducción de direcciones de la CPU",
      "Bloquea la recolección de trazas y logs invisibles en tiempo real",
      "Detiene servicios del motor de telemetría unificada (DiagTrack)",
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
    title: "Energía Inteligente Antiparos",
    description:
      "Desactiva los estados de suspensión selectiva de los buses PCIe y los modos de reposo profundo (C-States agresivos) que causan latencias al despertar componentes de hardware.",
    riesgo: "Balanceado",
    reversible: true,
    metodoReversion:
      "Comando powercfg -setactive para reasignar el plan estándar predeterminado de Windows.",
    hardwareRecomendado:
      "Computadoras de mesa. El software bloquea parcialmente este tweak en portátiles por seguridad térmica.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options",
    scriptName: "09_energia.ps1",
    impactoRendimiento:
      "Eliminación del retraso de inicialización de la GPU y estabilidad absoluta en frecuencias de reloj.",
    details: [
      "Mantiene la interfaz del puerto PCIe al máximo rendimiento eléctrico constante",
      "Evita el aparcado intempestivo de núcleos lógicos del procesador",
      "Filtro inteligente de protección de temperatura para equipos portátiles",
    ],
    registryMapping: [],
  },
  gameHooks: {
    id: "gameHooks",
    title: "Prioridad Absoluta para Juegos",
    description:
      "Inyecta configuraciones específicas en las directivas de Image File Execution Options (IFEO) de Windows para forzar al planificador del sistema operativo a dar prioridad de ejecución en tiempo real a ejecutables multimedia.",
    riesgo: "Experimental",
    reversible: true,
    metodoReversion:
      "Purga completa de la clave PerfOptions asociada al ejecutable dentro de la colmena IFEO.",
    hardwareRecomendado:
      "Sistemas donde se ejecuten títulos competitivos que dependan críticamente del rendimiento de un solo hilo de CPU.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/image-file-execution-options",
    scriptName: "11_game_hooks.ps1",
    impactoRendimiento:
      "Prioridad de subprocesamiento prioritaria frente a cualquier otra aplicación o navegador abierto en segundo plano.",
    warning:
      "Alterar las prioridades de ejecución mediante ganchos de imagen (IFEO) puede generar falsos positivos en sistemas anti-cheat (Vanguard, Ricochet, Easy Anti-Cheat) y resultar en un baneo permanente. ¿Desea continuar?",
    details: [
      "Fuerza una asignación de ciclos de CPU prioritaria e inmediata al proceso de juego en ejecución",
      "Desactiva las optimizaciones de optimización de presentación híbrida lentas",
    ],
    registryMapping: [],
  },
};
