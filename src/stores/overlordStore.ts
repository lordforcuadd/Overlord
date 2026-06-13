import { defineStore } from "pinia";
import { invoke } from "@tauri-apps/api/core";

interface HardwarePayload {
  cpu: string;
  gpu: string;
  motherboard: string;
  ramGb: number;
  ramSpeedMhz: number | null;
  isLaptop: boolean;
  isHybrid: boolean;
  isX3d: boolean;
  isSsd: boolean;
}

interface TelemetryPayload {
  cpu_usage: number;
  ram_used: number;
  ram_total: number;
  ram_percentage: number;
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
      ramGb: 0,
      ramSpeedMhz: 0,
      isLaptop: false,
      isHybrid: false,
      isX3d: false,
      isSsd: true,
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
      disableMitigations: false,
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
    isMonitorRunning: false,
    isPriorityServiceInstalled: false,
    priorityServiceSelected: false,
    telemetryInterval: null as any,
    isInitialized: false,
    isBenchmarkTesting: false,
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
        const info = await invoke<HardwarePayload>("fetch_hardware");

        this.hardwareInfo.cpu = info.cpu;
        this.hardwareInfo.gpu = info.gpu;
        this.hardwareInfo.motherboard = info.motherboard;
        this.hardwareInfo.ramGb = info.ramGb;
        this.hardwareInfo.ramSpeedMhz = info.ramSpeedMhz ?? 0;
        this.hardwareInfo.isLaptop = info.isLaptop;
        this.hardwareInfo.isHybrid = info.isHybrid;
        this.hardwareInfo.isX3d = info.isX3d;
        this.hardwareInfo.isSsd = info.isSsd;

        const lowerCpu = info.cpu.toLowerCase();
        const lowerGpu = info.gpu.toLowerCase();

        if (
          info.isX3d ||
          lowerCpu.includes("12700k") ||
          lowerCpu.includes("i9") ||
          lowerCpu.includes("ryzen 9") ||
          info.ramGb >= 32
        ) {
          this.hardwareInfo.tier = "Gama Alta";
        } else if (
          info.ramGb >= 16 ||
          lowerGpu.includes("rtx") ||
          lowerGpu.includes("rx 6")
        ) {
          this.hardwareInfo.tier = "Gama Media-Alta";
        } else {
          this.hardwareInfo.tier = "Gama Estándar";
        }
        await this.checkBackupStatus();
        await this.checkPriorityServiceStatus();
        if (!this.isInitialized) {
          this.priorityServiceSelected = this.isPriorityServiceInstalled;
        }
      } catch (e) {
        console.error("[ERROR DETECTANDO HARDWARE]:", e);
      }
    },
    async checkPriorityServiceStatus() {
      try {
        const status = await invoke<string>("run_optimization_script", {
          scriptName: "manage_priority_service",
          isLaptop: this.hardwareInfo.isLaptop,
          ramGb: this.hardwareInfo.ramGb,
          gameList: "status:",
        });
        this.isPriorityServiceInstalled = status.trim() === "installed";
        if (!this.isInitialized) {
          this.priorityServiceSelected = this.isPriorityServiceInstalled;
        }
      } catch (e) {
        console.error("[ERROR CHECKING PRIORITY SERVICE STATUS]:", e);
        this.isPriorityServiceInstalled = false;
        if (!this.isInitialized) {
          this.priorityServiceSelected = false;
        }
      }
    },
    async togglePriorityService(enable: boolean) {
      try {
        const gameListOpt = this.gameList
          .filter((g) => g.optimize)
          .map((g) => g.exe)
          .join(",");

        const action = enable ? "install" : "uninstall";
        const status = await invoke<string>("run_optimization_script", {
          scriptName: "manage_priority_service",
          isLaptop: this.hardwareInfo.isLaptop,
          ramGb: this.hardwareInfo.ramGb,
          gameList: `${action}:${gameListOpt}`,
        });

        this.isPriorityServiceInstalled = status.trim() === "installed";
        this.priorityServiceSelected = this.isPriorityServiceInstalled;
      } catch (e) {
        console.error(`[ERROR TOGGLING PRIORITY SERVICE ${enable}]:`, e);
        await this.checkPriorityServiceStatus();
      }
    },
    async scanGames() {
      try {
        const games = await invoke<GamePayload[]>("fetch_games");
        this.gameList = games.map((g) => ({
          ...g,
          optimize: g.detected,
        }));
      } catch (e) {
        console.error("[ERROR ESCANEANDO CATÁLOGO DE JUEGOS]:", e);
      }
    },
    startTelemetryPolling() {
      if (this.telemetryInterval) {
        clearInterval(this.telemetryInterval);
      }
      this.telemetryInterval = setInterval(async () => {
        try {
          const metrics = await invoke<TelemetryPayload>("get_live_telemetry");
          this.liveTelemetry.cpuUsage = metrics.cpu_usage;
          this.liveTelemetry.ramUsed = metrics.ram_used;
          this.liveTelemetry.ramTotal = metrics.ram_total;
          this.liveTelemetry.ramPercent = metrics.ram_percentage;
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

      const { isLaptop, isHybrid } = this.hardwareInfo;

      const profileConfigs: Record<string, string[]> = {
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
          "disableMitigations",
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
        Programador: ["debloat", "networkOptimized", "smartStorage"],
        "Home Office / Laptops": [
          "debloat",
          "networkOptimized",
          "smartStorage",
        ],
        "Usuario Casual": ["debloat", "smartStorage"],
      };

      const activeModules = profileConfigs[profile] || [];

      let hasGameHooks = false;
      activeModules.forEach((mod) => {
        if (mod === "irqAffinity" && isLaptop)
          return;
        if (mod === "powerProfiles" && isLaptop) return;

        this.modules[mod as keyof typeof this.modules] = true;
        if (mod === "gameHooks") {
          hasGameHooks = true;
        }
      });
      this.priorityServiceSelected = hasGameHooks;
    },
    async ejecutarNetworkBenchmark(fase: "before" | "after") {
      if (this.isBenchmarkTesting) return;
      this.isBenchmarkTesting = true;

      try {
        const result = await invoke<{ tcp_latency: number; dns_latency: number }>("run_benchmark");

        this.benchmarks[fase].networkLatency = result.tcp_latency;
        this.benchmarks[fase].dnsResolution = result.dns_latency;
        this.benchmarks[fase].measured = true;

        console.log(
          `[Overlord Benchmark] Fase ${fase} completada - TCP: ${result.tcp_latency}ms, DNS: ${result.dns_latency}ms`,
        );
      } catch (e) {
        console.error("[BENCHMARK CRITICAL FAIL]:", e);

        this.benchmarks[fase].networkLatency = 999;
        this.benchmarks[fase].dnsResolution = 999;
        this.benchmarks[fase].measured = true;
      } finally {
        this.isBenchmarkTesting = false;
      }
    },
  },
});
