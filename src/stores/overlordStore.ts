import { defineStore } from "pinia";
import { invoke } from "@tauri-apps/api/core";

interface HardwarePayload {
  cpu: string;
  gpu: string;
  motherboard: string;
  ram_gb: number;
  ram_speed: number;
  is_laptop: boolean;
  is_hybrid: boolean;
  is_x3d: boolean;
}

interface TelemetryPayload {
  cpu_usage: number;
  ram_used_gb: number;
  ram_total_gb: number;
  ram_percent: number;
}

interface GamePayload {
  name: string;
  exe: string;
  detected: boolean;
}

interface BenchmarkData {
  networkLatency: number;
  dnsResolution: number;
  measured: boolean;
}

export const useOverlordStore = defineStore("overlord", {
  state: () => ({
    hardwareInfo: {
      cpu: "",
      gpu: "",
      motherboard: "",
      ram: 0,
      ramSpeed: 0,
      isLaptop: false,
      isHybrid: false,
      isX3d: false,
      tier: "Detectando...",
    },
    liveTelemetry: {
      cpuUsage: 0,
      ramUsed: 0,
      ramTotal: 0,
      ramPercent: 0,
    },
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
    gameList: [] as Array<{
      name: string;
      exe: string;
      detected: boolean;
      optimize: boolean;
    }>,
    benchmarks: {
      before: {
        networkLatency: 0,
        dnsResolution: 0,
        measured: false,
      } as BenchmarkData,
      after: {
        networkLatency: 0,
        dnsResolution: 0,
        measured: false,
      } as BenchmarkData,
    },
    activeProfile: "Personalizado",
    restorePointCreated: false,
    backupExists: false,
    telemetryInterval: null as any,
  }),
  actions: {
    async checkBackupStatus() {
      try {
        this.backupExists = await invoke<boolean>("check_backup_exists");
        if (this.backupExists) {
          this.restorePointCreated = true;
        }
      } catch (e) {
        console.error("[ERROR CHECKING REGISTRY BACKUP]:", e);
        this.backupExists = false;
      }
    },
    async detectHardware() {
      try {
        const info = await invoke<HardwarePayload>("get_hardware_info");
        this.hardwareInfo.cpu = info.cpu;
        this.hardwareInfo.gpu = info.gpu;
        this.hardwareInfo.motherboard = info.motherboard;
        this.hardwareInfo.ram = info.ram_gb;
        this.hardwareInfo.ramSpeed = info.ram_speed;
        this.hardwareInfo.isLaptop = info.is_laptop;
        this.hardwareInfo.isHybrid = info.is_hybrid;
        this.hardwareInfo.isX3d = info.is_x3d;

        const lowerCpu = info.cpu.toLowerCase();
        const lowerGpu = info.gpu.toLowerCase();

        if (
          info.is_x3d ||
          lowerCpu.includes("12700k") ||
          lowerCpu.includes("i9") ||
          lowerCpu.includes("ryzen 9") ||
          info.ram_gb >= 32
        ) {
          this.hardwareInfo.tier = "Gama Alta Extreme";
        } else if (
          info.ram_gb >= 16 ||
          lowerGpu.includes("rtx") ||
          lowerGpu.includes("rx 6")
        ) {
          this.hardwareInfo.tier = "Gama Media-Alta";
        } else {
          this.hardwareInfo.tier = "Gama Estándar";
        }
        await this.checkBackupStatus();
      } catch (e) {
        console.error("[ERROR DETECTANDO HARDWARE]:", e);
      }
    },
    async scanGames() {
      try {
        const games = await invoke<GamePayload[]>("scan_games");
        this.gameList = games.map((g) => ({
          ...g,
          optimize: g.detected,
        }));
      } catch (e) {
        console.error("[ERROR ESCANEANDO CATÁLOGO DE JUEGOS]:", e);
      }
    },
    startTelemetryPolling() {
      if (this.telemetryInterval) return;
      this.telemetryInterval = setInterval(async () => {
        try {
          const metrics = await invoke<TelemetryPayload>("get_live_telemetry");
          this.liveTelemetry.cpuUsage = metrics.cpu_usage;
          this.liveTelemetry.ramUsed = metrics.ram_used_gb;
          this.liveTelemetry.ramTotal = metrics.ram_total_gb;
          this.liveTelemetry.ramPercent = metrics.ram_percent;
        } catch (e) {
          console.error("[TELEMETRY POLL FAIL]:", e);
        }
      }, 2000);
    },
    stopTelemetryPolling() {
      if (this.telemetryInterval) {
        clearInterval(this.telemetryInterval);
        this.telemetryInterval = null;
      }
    },
    applyProfile(profile: string) {
      this.activeProfile = profile;
      if (profile === "Personalizado") return;

      Object.keys(this.modules).forEach((key) => {
        this.modules[key as keyof typeof this.modules] = false;
      });

      const isHighEnd = this.hardwareInfo.tier === "Gama Alta Extreme";

      switch (profile) {
        case "Competitivo":
          this.modules.peripheralLatency = true;
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.generalPerformance = true;
          this.modules.gpuDisplay = true;
          this.modules.irqAffinity =
            isHighEnd &&
            !this.hardwareInfo.isLaptop &&
            !this.hardwareInfo.isHybrid;
          this.modules.smartStorage = true;
          this.modules.deepTelemetry = isHighEnd;
          this.modules.powerProfiles = !this.hardwareInfo.isLaptop;
          this.modules.gameHooks = true;
          break;
        case "Programador & Competitivo":
          this.modules.peripheralLatency = true;
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.generalPerformance = true;
          this.modules.gpuDisplay = true;
          this.modules.smartStorage = true;
          this.modules.powerProfiles = !this.hardwareInfo.isLaptop;
          this.modules.gameHooks = true;
          break;
        case "Programador":
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.smartStorage = true;
          break;
        case "Home Office / Laptops":
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.smartStorage = true;
          break;
        case "Usuario Casual":
          this.modules.debloat = true;
          this.modules.smartStorage = true;
          break;
      }
    },
  },
});
