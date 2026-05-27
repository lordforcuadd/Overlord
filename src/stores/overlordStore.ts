import { defineStore } from "pinia";
import { invoke } from "@tauri-apps/api/core";

export const useOverlordStore = defineStore("overlord", {
  state: () => ({
    hardwareInfo: {
      cpu: "",
      gpu: "",
      motherboard: "",
      ram: 0,
      ramSpeed: 0,
      isLaptop: false,
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
    moduleSpecs: {
      peripheralLatency: { riesgo: "Seguro" },
      debloat: { riesgo: "Seguro" },
      networkOptimized: { riesgo: "Seguro" },
      generalPerformance: { riesgo: "Avanzado" },
      gpuDisplay: { riesgo: "Avanzado" },
      irqAffinity: { riesgo: "Kernel" },
      smartStorage: { riesgo: "Seguro" },
      deepTelemetry: { riesgo: "Kernel" },
      powerProfiles: { riesgo: "Avanzado" },
      gameHooks: { riesgo: "Kernel" },
    },
    gameList: [] as Array<{
      name: string;
      exe: string;
      detected: boolean;
      optimize: boolean;
    }>,
    activeProfile: "Personalizado",
    restorePointCreated: false,
    telemetryInterval: null as any,
  }),
  actions: {
    async detectHardware() {
      try {
        const info: any = await invoke("get_hardware_info");
        this.hardwareInfo.cpu = info.cpu;
        this.hardwareInfo.gpu = info.gpu;
        this.hardwareInfo.motherboard = info.motherboard;
        this.hardwareInfo.ram = info.ram_gb;
        this.hardwareInfo.ramSpeed = info.ram_speed;
        this.hardwareInfo.isLaptop = info.is_laptop;

        const lowerCpu = info.cpu.toLowerCase();
        if (
          lowerCpu.includes("12700k") ||
          lowerCpu.includes("i7") ||
          info.ram_gb >= 32
        ) {
          this.hardwareInfo.tier = "Gama Alta Extreme";
        } else if (info.ram_gb >= 16) {
          this.hardwareInfo.tier = "Gama Media-Alta";
        } else {
          this.hardwareInfo.tier = "Gama Estándar";
        }
      } catch (e) {
        console.error(e);
      }
    },
    async scanGames() {
      try {
        const games: any = await invoke("scan_games");
        this.gameList = games.map((g: any) => ({
          ...g,
          optimize: g.detected,
        }));
      } catch (e) {
        console.error(e);
      }
    },
    startTelemetryPolling() {
      if (this.telemetryInterval) return;
      this.telemetryInterval = setInterval(async () => {
        try {
          const metrics: any = await invoke("get_live_telemetry");
          this.liveTelemetry.cpuUsage = metrics.cpu_usage;
          this.liveTelemetry.ramUsed = metrics.ram_used_gb;
          this.liveTelemetry.ramTotal = metrics.ram_total_gb;
          this.liveTelemetry.ramPercent = metrics.ram_percent;
        } catch (e) {
          console.error(e);
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

      switch (profile) {
        case "Competitivo":
          this.modules.peripheralLatency = true;
          this.modules.debloat = true;
          this.modules.networkOptimized = true;
          this.modules.generalPerformance = true;
          this.modules.gpuDisplay = true;
          this.modules.irqAffinity = !this.hardwareInfo.isLaptop;
          this.modules.smartStorage = true;
          this.modules.deepTelemetry = true;
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
