import { defineStore } from "pinia";
import { invoke } from "@tauri-apps/api/core";

// Interfaz para tipar correctamente los juegos detectados
export interface Game {
  name: string;
  exe: string;
  detected: boolean;
  optimize: boolean;
}

// 🚀 TIPO DE DATO EXPORTABLE PARA v2.5: Define las clasificaciones de riesgo válidas
export type TipoRiesgo = "Seguro" | "Avanzado" | "Kernel";

// Variable a nivel de módulo para controlar de forma segura el intervalo y evitar memory leaks
let telemetryIntervalId: ReturnType<typeof setInterval> | null = null;

export const useOverlordStore = defineStore("overlord", {
  // ==========================================
  // 1. ESTADO GLOBAL
  // ==========================================
  state: () => ({
    hardwareInfo: {
      cpu: "",
      gpu: "",
      motherboard: "",
      ram: 0,
      ramSpeed: 0,
      isLaptop: false,
      tier: "Analizando hardware...",
    },

    restorePointCreated: false,

    // Perfil seleccionado por el usuario
    activeProfile: "Personalizado",

    // El estado binario de los módulos ofensivos de bajo nivel
    modules: {
      peripheralLatency: false,
      debloat: false,
      networkOptimized: false,
      generalPerformance: false,
      gpuDisplay: false,
      irqAffinity: false,
      smartStorage: false,
      deepTelemetry: false,
      powerProfiles: false,
      gameHooks: false,
    },

    moduleSpecs: {
      peripheralLatency: {
        riesgo: "Seguro" as TipoRiesgo,
        desc: "Raw Input 1:1, Modo MSI y Queue Size a 20",
      },
      debloat: {
        riesgo: "Seguro" as TipoRiesgo,
        desc: "Purga de Bloatware Apps y Telemetría básica",
      },
      networkOptimized: {
        riesgo: "Seguro" as TipoRiesgo,
        desc: "Bypass de Nagle, TCP Experimental y 0ms DNS Cache",
      },
      generalPerformance: {
        riesgo: "Avanzado" as TipoRiesgo,
        desc: "Plan Ultimate, Desactivación de parches Spectre/Meltdown y FTH",
      },
      gpuDisplay: {
        riesgo: "Avanzado" as TipoRiesgo,
        desc: "Bypass MPO y Latencia de renderizado",
      },
      irqAffinity: {
        riesgo: "Kernel" as TipoRiesgo,
        desc: "Afinidad de interrupciones físicas e hilos de CPU",
      },
      smartStorage: {
        riesgo: "Seguro" as TipoRiesgo,
        desc: "Caché de metadatos NTFS x2 y bloqueo LastAccess",
      },
      deepTelemetry: {
        riesgo: "Kernel" as TipoRiesgo,
        desc: "Apagado total de VBS / HVCI y Autologgers en RAM",
      },
      powerProfiles: {
        riesgo: "Avanzado" as TipoRiesgo,
        desc: "Anulación de limitador de energía MMCSS",
      },
      gameHooks: {
        riesgo: "Kernel" as TipoRiesgo,
        desc: "Inyección de prioridades masivas a ejecutables eSports",
      },
    },

    liveTelemetry: {
      cpuUsage: 0,
      ramUsed: 0,
      ramTotal: 0,
      ramPercent: 0,
    },

    // Lista dinámica de juegos
    gameList: [] as Game[],
  }),

  // ==========================================
  // 2. ACCIONES DEL SISTEMA
  // ==========================================
  actions: {
    /**
     * Inicia el sondeo de telemetría asegurando limpiar cualquier intervalo previo
     */
    startTelemetryPolling() {
      if (telemetryIntervalId) {
        clearInterval(telemetryIntervalId);
      }

      telemetryIntervalId = setInterval(async () => {
        try {
          const data: any = await invoke("get_live_telemetry");
          this.liveTelemetry.cpuUsage = data.cpu_usage;
          this.liveTelemetry.ramUsed = data.ram_used_gb;
          this.liveTelemetry.ramTotal = data.ram_total_gb;
          this.liveTelemetry.ramPercent = data.ram_percent;
        } catch (error) {
          // Micro-cortes controlados en silencio para mantener limpia la consola
        }
      }, 1000);
    },

    /**
     * Detiene el intervalo de telemetría de raíz para liberar memoria
     */
    stopTelemetryPolling() {
      if (telemetryIntervalId) {
        clearInterval(telemetryIntervalId);
        telemetryIntervalId = null;
      }
    },

    /**
     * Llama al backend en Rust para leer componentes físicos
     */
    async detectHardware() {
      try {
        const data: any = await invoke("get_hardware_info");

        this.hardwareInfo.cpu = data.cpu;
        this.hardwareInfo.gpu = data.gpu;
        this.hardwareInfo.motherboard = data.motherboard;
        this.hardwareInfo.ram = data.ram_gb;
        this.hardwareInfo.ramSpeed = data.ram_speed;
        this.hardwareInfo.isLaptop = data.is_laptop;

        // Asignación de Tiers basada en RAM
        if (data.ram_gb >= 32) {
          this.hardwareInfo.tier = "Gama Alta";
        } else if (data.ram_gb >= 16) {
          this.hardwareInfo.tier = "Gama Media";
        } else {
          this.hardwareInfo.tier = "Gama Baja";
        }
      } catch (error) {
        console.error("Fallo al interceptar hardware:", error);
        this.hardwareInfo.tier = "Lectura Fallida";
      }
    },

    /**
     * Escanea el registro de Windows buscando ejecutables de eSports
     */
    async scanGames() {
      try {
        const data: any = await invoke("scan_games");

        // Mapeamos para añadir nuestro toggle reactivo "optimize"
        this.gameList = data.map((game: any) => ({
          name: game.name,
          exe: game.exe,
          detected: game.detected,
          optimize: game.detected,
        }));
      } catch (error) {
        console.error("Error escaneando juegos desde el Kernel:", error);
      }
    },

    /**
     * Gestor de Arquetipos Premium: Asigna módulos con lógica real de hardware
     */
    applyProfile(profileName: string) {
      this.activeProfile = profileName;

      // 1. Reiniciar estado (Lienzo en blanco)
      (Object.keys(this.modules) as Array<keyof typeof this.modules>).forEach(
        (key) => {
          this.modules[key] = false;
        },
      );

      // 2. Configuración granular basada en compatibilidad de Hardware y Software real
      switch (profileName) {
        case "Competitivo":
          this.modules.peripheralLatency = true;
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.generalPerformance = true;
          this.modules.gpuDisplay = true;
          this.modules.irqAffinity = true;
          this.modules.smartStorage = true;
          this.modules.deepTelemetry = true;
          this.modules.powerProfiles = true;
          this.modules.gameHooks = true;
          break;

        case "Programador & Competitivo":
          this.modules.peripheralLatency = true;
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.generalPerformance = true;
          this.modules.gpuDisplay = true;
          this.modules.irqAffinity = true;
          this.modules.smartStorage = true;
          this.modules.deepTelemetry = false;
          this.modules.powerProfiles = true;
          this.modules.gameHooks = true;
          break;

        case "Programador":
          this.modules.debloat = true;
          this.modules.generalPerformance = true;
          this.modules.smartStorage = true;
          this.modules.networkOptimized = true;
          break;

        case "Home Office / Laptops":
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.smartStorage = true;
          break;

        case "Usuario Casual":
          this.modules.debloat = true;
          this.modules.generalPerformance = false;
          this.modules.smartStorage = true;
          break;
      }
    },
  },
  persist: true,
});
