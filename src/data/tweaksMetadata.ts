export interface TweakMetadata {
  id: string;
  title: string;
  description: string;
  riesgo: "Seguro" | "Avanzado" | "Kernel";
  reversible: boolean;
  metodoReversion: string;
  hardwareRecomendado: string;
  windowsVersion: string;
  fuenteOficial: string;
  details: string[];
}

export const tweaksMetadata: Record<string, TweakMetadata> = {
  peripheralLatency: {
    id: "peripheralLatency",
    title: "Respuesta de Teclado y Ratón",
    description:
      "Elimina por completo el retraso al hacer clic o presionar teclas. Optimiza tus puertos USB y quita los frenos de Windows para que el puntero se mueva exactamente como tu mano.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Restauración de valores por defecto en los servicios nativos mouclass y kbdclass del registro de Windows.",
    hardwareRecomendado:
      "Cualquier placa base con controladores de bus USB xHCI nativos de Intel o AMD.",
    windowsVersion: "Windows 10 / Windows 11 (Todas las versiones)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/keyboard-and-mouse-class-drivers",
    details: [
      "Respuesta inmediata de teclado y ratón",
      "Puertos USB en modo de alto rendimiento",
      "Aceleración del ratón 100% desactivada",
      "Desactiva teclas pegajosas molestas",
    ],
  },
  debloat: {
    id: "debloat",
    title: "Limpieza del Sistema (Debloat)",
    description:
      "Elimina programas basura que vienen preinstalados de fábrica y apaga funciones ocultas que vigilan tu actividad, liberando espacio en el procesador y la memoria RAM.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Reinstalación manual desde la Microsoft Store o comandos Get-AppxPackage de aprovisionamiento base.",
    hardwareRecomendado:
      "Setups de hardware comprometido, discos mecánicos HDD o almacenamiento particionado limitado.",
    windowsVersion: "Windows 10 / Windows 11 (Home y Pro)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage",
    details: [
      "Apaga el rastreo de datos oculto de Windows",
      "Elimina aplicaciones preinstaladas inútiles",
      "Detiene servicios pesados en segundo plano",
    ],
  },
  networkOptimized: {
    id: "networkOptimized",
    title: "Optimización de Internet",
    description:
      "Estabiliza la conexión para evitar subidas repentinas de Ping en tus partidas en línea. Elimina los límites ocultos de Windows para que aproveches toda la velocidad de tu red.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Comandos netsh int tcp reset y remoción de las llaves MaxCacheTtl creadas en el Dnscache.",
    hardwareRecomendado:
      "Conexiones por cable Ethernet de alta velocidad, adaptadores Intel e1000e o Realtek PCIe Gaming.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/networking/technologies/tcp-ip/tcp-ip-performance-tuning",
    details: [
      "Envío instantáneo de paquetes de datos",
      "Elimina los límites de velocidad de Windows",
      "Acelera la respuesta al buscar páginas (DNS)",
      "Estabiliza el internet frente a micro-cortes",
    ],
  },
  generalPerformance: {
    id: "generalPerformance",
    title: "Potencia Bruta y Procesador",
    description:
      "Desbloquea el plan de energía oculto de máximo rendimiento y regula el consumo excesivo del antivirus en segundo plano para que no cause caídas de fotogramas (FPS).",
    riesgo: "Avanzado",
    reversible: true,
    metodoReversion:
      "Restauración del FeatureSettingsOverride a valor cero y conmutación al plan de energía Equilibrado.",
    hardwareRecomendado:
      "Procesadores de escritorio de más de 6 núcleos físicos con soluciones térmicas estables independientes.",
    windowsVersion: "Windows 10 v1809+ / Windows 11",
    fuenteOficial:
      "https://support.microsoft.com/en-us/topic/kb4073119-guidance-to-mitigate-speculative-execution-side-channel-vulnerabilities",
    details: [
      "Activa el Plan de Energía Máxima del sistema",
      "Evita tirones y congelamientos en juegos",
      "Quita frenos de seguridad del procesador",
      "Limpia archivos temporales acumulados",
    ],
  },
  gpuDisplay: {
    id: "gpuDisplay",
    title: "Fluidez de Pantalla y Gráficos",
    description:
      "Mejora la suavidad visual de tus juegos eliminando las micro-congelaciones en la pantalla. Le otorga prioridad absoluta a tu tarjeta de video para procesar las imágenes primero.",
    riesgo: "Avanzado",
    reversible: true,
    metodoReversion:
      "Remoción de la subclave PerfOptions de dwm.exe e inversión de la directiva global de mitigación de MPO.",
    hardwareRecomendado:
      "Tarjetas gráficas dedicadas NVIDIA GTX/RTX o AMD Radeon RX con controladores actualizados.",
    windowsVersion: "Windows 10 / Windows 11 (Compilaciones de producción)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/win32/desktopmgmt/desktop-window-manager-overview",
    details: [
      "Elimina pequeños tirones visuales en juegos",
      "Otorga prioridad máxima a la tarjeta de video",
      "Apaga funciones pesadas de la barra de juegos",
    ],
  },
  irqAffinity: {
    id: "irqAffinity",
    title: "Organización del Procesador",
    description:
      "Reordena la forma en que trabaja tu computadora. Evita que las tareas del internet saturen el núcleo principal donde corre tu juego, distribuyendo el esfuerzo eficientemente.",
    riesgo: "Kernel",
    reversible: true,
    metodoReversion:
      "Eliminación de la máscara binaria AssignmentSetOverride dentro de la directiva de Interrupt Management.",
    hardwareRecomendado:
      "Computadoras con procesadores modernos que posean arquitecturas de núcleos híbridos (P-Cores y E-Cores).",
    windowsVersion: "Windows 11 Obligatorio para una gestión de hilos óptima",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/interrupt-affinity-and-priority",
    details: [
      "Enfoca el 100% del sistema en tus tareas",
      "Separa el tráfico de internet de tus juegos",
      "Acelera la velocidad de lectura de archivos",
    ],
  },
  smartStorage: {
    id: "smartStorage",
    title: "Aceleración de Disco y Almacenamiento",
    description:
      "Duplica la memoria interna dedicada a leer datos para que tus programas abran más rápido, y ejecuta un limpiador profundo que borra gigabytes de actualizaciones viejas.",
    riesgo: "Seguro",
    reversible: true,
    metodoReversion:
      "Comandos fsutil behavior set para habilitar de nuevo LastAccessUpdate y balancear MemoryUsage.",
    hardwareRecomendado:
      "Unidades de estado sólido SSD NVMe M.2 o SSD SATA III. Evitar en configuraciones RAID complejas.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-behavior",
    details: [
      "Duplica la velocidad de lectura de archivos",
      "Borra carpetas basura ocultas de Windows Update",
      "Evita desgastes y escrituras inútiles en tu SSD",
      "Apaga la hibernación en computadoras de mesa",
    ],
  },
  deepTelemetry: {
    id: "deepTelemetry",
    title: "Seguridad Virtual y Filtros",
    description:
      "Desactiva las capas de seguridad invisibles de Windows 11 que frenan el rendimiento gráfico en juegos y apaga por completo los grabadores que registran tu historial en disco.",
    riesgo: "Kernel",
    reversible: true,
    metodoReversion:
      "Habilitación explícita de DeviceGuard y escenarios HVCI desde el registro de Windows o directivas de grupo.",
    hardwareRecomendado:
      "Computadoras de escritorio dedicadas exclusivamente al entretenimiento, streaming o gaming competitivo.",
    windowsVersion:
      "Windows 11 (Sistemas con virtualización por hardware activa)",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows/security/hardware-security/virtualization-based-security",
    details: [
      "Desactiva la seguridad virtual que frena los FPS",
      "Bloquea el envío automático de datos a Microsoft",
      "Apaga grabadores de eventos en segundo plano",
    ],
  },
  powerProfiles: {
    id: "powerProfiles",
    title: "Energía Inteligente Antiparos",
    description:
      "Evita que tus piezas se pongan en 'modo de ahorro' o se duerman en mitad de una partida. Mantiene tu procesador despierto para responder instantáneamente ante cargas pesadas.",
    riesgo: "Avanzado",
    reversible: true,
    metodoReversion:
      "Comando powercfg -setactive para reasignar el plan estándar predeterminado de Windows.",
    hardwareRecomendado:
      "Computadoras de mesa. El software bloquea parcialmente este tweak en portátiles por seguridad térmica.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options",
    details: [
      "Mantiene la ventaja de la GPU a máxima velocidad",
      "Evita que los núcleos del procesador se duerman",
      "Protección inteligente automática para Laptops",
    ],
  },
  gameHooks: {
    id: "gameHooks",
    title: "Prioridad Absoluta para Juegos",
    description:
      "Cuando abres tus juegos favoritos, el sistema detecta su ejecución y enfoca de inmediato toda la potencia del procesador en ellos, suspendiendo alertas molestas.",
    riesgo: "Kernel",
    reversible: true,
    metodoReversion:
      "Purga completa de la clave PerfOptions asociada al ejecutable dentro de la colmena IFEO.",
    hardwareRecomendado:
      "Sistemas donde se ejecuten títulos competitivos que dependan críticamente del rendimiento de un solo hilo de CPU.",
    windowsVersion: "Windows 10 / Windows 11",
    fuenteOficial:
      "https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/image-file-execution-options",
    details: [
      "Fuerza prioridad del procesador exclusiva al jugar",
      "Desactiva funciones de pantalla completa lentas",
    ],
  },
};
