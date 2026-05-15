import { defineStore } from "pinia";
import { invoke } from "@tauri-apps/api/core";

// Interfaz para tipar correctamente los juegos detectados
export interface Game {
  name: string;
  exe: string;
  detected: boolean;
  optimize: boolean;
}

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
    activeProfile: "Custom",

    // El estado de los 10 módulos ofensivos
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
    startTelemetryPolling() {
      // Hacemos ping a Rust cada 1000ms (1 segundo)
      setInterval(async () => {
        try {
          const data: any = await invoke("get_live_telemetry");
          this.liveTelemetry.cpuUsage = data.cpu_usage;
          this.liveTelemetry.ramUsed = data.ram_used_gb;
          this.liveTelemetry.ramTotal = data.ram_total_gb;
          this.liveTelemetry.ramPercent = data.ram_percent;
        } catch (error) {
          // Fallamos en silencio para no ensuciar la consola si hay un micro-corte
        }
      }, 1000);
    },
    /**
     * Llama al backend en Rust para leer componentes físicos mediante WMI
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
     * Gestor de Arquetipos: Enciende o apaga módulos según el uso del equipo
     */
    applyProfile(profileName: string) {
      this.activeProfile = profileName;

      // 1. Apagamos todos los módulos para reiniciar el estado (Lienzo en blanco)
      (Object.keys(this.modules) as Array<keyof typeof this.modules>).forEach(
        (key) => {
          this.modules[key] = false;
        },
      );

      // 2. Encendemos los módulos correspondientes a cada perfil
      switch (profileName) {
        case "Competitivo":
          // Modo Competitivo Extremo: 0% input lag.
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
          // Programador + Gamer: VBS y Núcleos intactos para Docker/NodeJS.
          this.modules.peripheralLatency = true;
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.generalPerformance = true;
          this.modules.gpuDisplay = true;
          this.modules.smartStorage = true;
          this.modules.gameHooks = true;
          break;

        case "Programador":
          // Solo Programación: RAM libre y disco rápido.
          this.modules.debloat = true;
          this.modules.smartStorage = true;
          this.modules.generalPerformance = true;
          break;

        case "Home Office / Laptops":
          // Laptops y Oficina: Estabilidad y batería.
          this.modules.debloat = true;
          this.modules.smartStorage = true;
          this.modules.networkOptimized = true;
          break;

        case "Usuario Casual":
          // Navegación y Multimedia estándar.
          this.modules.debloat = true;
          this.modules.generalPerformance = true;
          this.modules.smartStorage = true;
          this.modules.gpuDisplay = true;
          break;
      }
    },
  },
});
