import { defineStore } from "pinia";
import { invoke } from "@tauri-apps/api/core";
import { PROFILE_CONFIGS } from "../data/tweaksMetadata";
import { buildExpectedProfileState } from "./profileLogic";

interface HardwarePayload {
  cpu: string;
  cpuBrand: string;
  cpuVendor: string;
  cpuFrequency: number;
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
    isGlobalBusy: false,
    hardwareError: false,
    hardwareInfo: {
      cpu: "",
      cpuBrand: "",
      cpuVendor: "",
      cpuFrequency: 0,
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
      manual?: boolean;
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
    setGlobalBusy(value: boolean) {
      this.isGlobalBusy = value;
    },
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
        this.hardwareInfo.cpuBrand = info.cpuBrand;
        this.hardwareInfo.cpuVendor = info.cpuVendor;
        this.hardwareInfo.cpuFrequency = info.cpuFrequency;
        this.hardwareInfo.gpu = info.gpu;
        this.hardwareInfo.motherboard = info.motherboard;
        this.hardwareInfo.ramGb = info.ramGb;
        this.hardwareInfo.ramSpeedMhz = info.ramSpeedMhz ?? 0;
        this.hardwareInfo.isLaptop = info.isLaptop;
        this.hardwareInfo.isHybrid = info.isHybrid;
        this.hardwareInfo.isX3d = info.isX3d;
        this.hardwareInfo.isSsd = info.isSsd;

        const isIntel = info.cpuVendor.toLowerCase().includes("intel");
        const isAmd = info.cpuVendor.toLowerCase().includes("amd");
        const brand = info.cpuBrand;
        const lowerGpu = info.gpu.toLowerCase();

        const isIntelHighCpu = isIntel && (
          brand.includes("i9") || 
          brand.includes("Ultra 9") || 
          brand.includes("Ultra 7") || 
          brand.includes("i7-12") || 
          brand.includes("i7-13") || 
          brand.includes("i7-14") || 
          brand.includes("i7 12") || 
          brand.includes("i7 13") || 
          brand.includes("i7 14")
        );

        const isAmdHighCpu = isAmd && (
          info.isX3d ||
          brand.includes("Ryzen 9") ||
          brand.includes("Ryzen 7 7") ||
          brand.includes("Ryzen 7 8") ||
          brand.includes("Ryzen 7 9") ||
          brand.includes("Ryzen 5 7") ||
          brand.includes("Ryzen 5 8") ||
          brand.includes("Ryzen 5 9")
        );

        if (
          isIntelHighCpu ||
          isAmdHighCpu ||
          info.ramGb >= 32
        ) {
          this.hardwareInfo.tier = "Gama Alta";
        } else if (
          info.ramGb >= 16 ||
          lowerGpu.includes("rtx") ||
          lowerGpu.includes("rx 6") ||
          lowerGpu.includes("rx 7") ||
          lowerGpu.includes("rx 8") ||
          lowerGpu.includes("rx 9") ||
          lowerGpu.includes("intel arc") ||
          lowerGpu.includes("arc a") ||
          lowerGpu.includes("arc b")
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
        await invoke("log_from_js", {
          msg: `detectHardware done: isLaptop=${this.hardwareInfo.isLaptop}, cpu=${this.hardwareInfo.cpu}, motherboard=${this.hardwareInfo.motherboard}`
        });
      } catch (e) {
        console.error("[ERROR DETECTANDO HARDWARE]:", e);
        this.hardwareError = true;
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
      this.setGlobalBusy(true);
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
      } finally {
        this.setGlobalBusy(false);
      }
    },
    async scanGames() {
      try {
        const games = await invoke<GamePayload[]>("fetch_games");
        const manualGames = this.gameList.filter((g) => g.manual);
        const scanned = games.map((g) => ({
          ...g,
          optimize: g.detected,
          manual: false,
        }));
        this.gameList = [...scanned, ...manualGames];
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

      const activeModules = PROFILE_CONFIGS[profile] || [];
      const { isLaptop, tier } = this.hardwareInfo;
      const expected = buildExpectedProfileState(activeModules, { isLaptop, tier });

      Object.keys(expected).forEach((key) => {
        this.modules[key as keyof typeof this.modules] = expected[key];
      });
      // Consentimiento separado: No autoseleccionar el daemon de fondo SYSTEM
      invoke("log_from_js", {
        msg: `applyProfile done: profile=${profile}, isLaptop=${isLaptop}, tier=${tier}, activeModules=${JSON.stringify(activeModules)}, modulesState=${JSON.stringify(this.modules)}`
      }).catch(() => {});
    },
    async ejecutarNetworkBenchmark(fase: "before" | "after") {
      if (this.isBenchmarkTesting || this.isGlobalBusy) return;
      this.isBenchmarkTesting = true;
      this.setGlobalBusy(true);

      try {
        const result = await invoke<{ tcp_latency: number; dns_latency: number }>("run_benchmark");

        this.benchmarks[fase].networkLatency = result.tcp_latency;
        this.benchmarks[fase].dnsResolution = result.dns_latency;
        this.benchmarks[fase].measured = true;
      } catch (e) {
        console.error("[BENCHMARK CRITICAL FAIL]:", e);

        this.benchmarks[fase].networkLatency = 999;
        this.benchmarks[fase].dnsResolution = 999;
        this.benchmarks[fase].measured = true;
      } finally {
        this.isBenchmarkTesting = false;
        this.setGlobalBusy(false);
      }
    },
    updateModule(tweakId: string, value: boolean) {
      this.activeProfile = "Personalizado";
      this.modules[tweakId as keyof typeof this.modules] = value;
    },
    toggleGameOptimization(index: number, optimize: boolean) {
      if (index >= 0 && index < this.gameList.length) {
        this.gameList[index].optimize = optimize;
      }
    },
    addManualGame(name: string, exe: string) {
      if (!name || !exe) return;
      let cleanExe = exe.trim();
      if (!cleanExe.toLowerCase().endsWith(".exe")) {
        cleanExe += ".exe";
      }
      const exists = this.gameList.some(
        (g) => g.exe.toLowerCase() === cleanExe.toLowerCase()
      );
      if (!exists) {
        this.gameList.push({
          name: name.trim(),
          exe: cleanExe,
          detected: true,
          optimize: true,
          manual: true,
        });
      }
    },
  },
});
