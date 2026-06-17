import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { useOverlordStore } from "../stores/overlordStore";
import { tweaksMetadata } from "../data/tweaksMetadata";
import Swal from "sweetalert2";

export function useOrchestrator(overlordSwalConfig: any) {
  const store = useOverlordStore();
  const cardStatus = ref<
    Record<string, "idle" | "loading" | "success" | "error">
  >({});
  const isBackingUp = ref(false);
  const isReverting = ref(false);
  const isExecutingAll = ref(false);

  async function crearRespaldo() {
    isBackingUp.value = true;
    try {
      await invoke("run_optimization_script", {
        scriptName: "crear_respaldo",
        isLaptop: store.hardwareInfo.isLaptop,
        ramGb: store.hardwareInfo.ramGb ?? 8,
        gameList: "",
      });
      store.restorePointCreated = true;
      await Swal.fire({
        title: "¡Punto Creado!",
        text: "El sistema ha sido blindado con éxito.",
        icon: "success",
        ...overlordSwalConfig,
      });
    } catch (error) {
      store.restorePointCreated = false;
      await Swal.fire({
        title: "ERROR DE RESPALDO",
        text: "No se pudo comprobar la integridad del servicio VSS u Overlord no cuenta con privilegios de Administrador.",
        icon: "error",
        ...overlordSwalConfig,
      });
    } finally {
      isBackingUp.value = false;
    }
  }

  async function ejecutarTodo() {
    if (isExecutingAll.value) return;

    const modulosActivos = Object.entries(store.modules)
      .filter(([_, isEnabled]) => isEnabled)
      .map(([key]) => key);

    if (modulosActivos.length === 0) return;

    await store.checkBackupStatus();

    if (!store.backupExists) {
      const alertConfirm = await Swal.fire({
        title: "RESPALDO REQUERIDO",
        html: "Para inyectar optimizaciones de nivel Kernel con seguridad, Overlord creará un respaldo obligatorio.",
        icon: "info",
        showCancelButton: true,
        confirmButtonText: "SÍ, BLINDAR SISTEMA",
        cancelButtonText: "CANCELAR",
        ...overlordSwalConfig,
      });

      if (!alertConfirm.isConfirmed) return;
      await crearRespaldo();
      if (!store.restorePointCreated) return;
    }

    isExecutingAll.value = true;

    const modulosExitosos: string[] = [];
    let moduloFallido: string | null = null;
    let huboError = false;

    for (const modKey of modulosActivos) {
      const scriptName = tweaksMetadata[modKey]?.scriptName;
      if (!scriptName) continue;

      cardStatus.value[modKey] = "loading";
      try {
        let gameListOpt = "";
        if (modKey === "gameHooks") {
          gameListOpt = store.gameList
            .filter((g) => g.optimize)
            .map((g) => g.exe)
            .join(",");
        }

        await invoke("run_optimization_script", {
          scriptName: scriptName.replace(".ps1", ""),
          isLaptop: store.hardwareInfo.isLaptop,
          ramGb: store.hardwareInfo.ramGb ?? 8,
          gameList: gameListOpt,
        });

        if (modKey === "gameHooks" && gameListOpt) {
          store.isMonitorRunning = true;
          await invoke("start_game_priority_monitor", {
            gameListRaw: gameListOpt,
          });
          await store.togglePriorityService(store.priorityServiceSelected);
          console.log(
            `[RUST MONITOR]: Hilo dinámico de prioridad alta inicializado con éxito. Servicio de fondo configurado: ${store.priorityServiceSelected}`,
          );
        }

        cardStatus.value[modKey] = "success";
        store.modules[modKey as keyof typeof store.modules] = false;
        modulosExitosos.push(tweaksMetadata[modKey]?.title || modKey);
      } catch (errorOutput) {
        console.error(`[FALLO EN MÓDULO ${modKey}]:`, errorOutput);
        cardStatus.value[modKey] = "error";

        moduloFallido = `${tweaksMetadata[modKey]?.title || modKey}<br><span class='text-xs text-red-500 font-mono'>Motivo: ${String(errorOutput).substring(0, 80)}...</span>`;
        huboError = true;
        break;
      }
    }

    isExecutingAll.value = false;

    if (huboError) {
      const textoExitos =
        modulosExitosos.length > 0
          ? `Los módulos <b>${modulosExitosos.join(", ")}</b> se aplicaron correctamente.`
          : "Ningún módulo previo pudo completarse.";

      await Swal.fire({
        title: "OPTIMIZACIÓN PARCIAL",
        html: `${textoExitos}<br><br>El módulo <b>${moduloFallido}</b> falló durante la inyección.<br><br>Puedes revertir todo el sistema al estado de fábrica desde el botón Revertir.`,
        icon: "error",
        ...overlordSwalConfig,
      });
      return;
    }

    if (modulosActivos.length > 0) {
      const result = await Swal.fire({
        title: "SISTEMA OPTIMIZADO",
        html: "Es <b class='text-yellow-500'>OBLIGATORIO</b> reiniciar para inyectar los cambios en el Kernel.",
        icon: "success",
        confirmButtonText: "SÍ, REINICIAR AHORA",
        cancelButtonText: "MÁS TARDE",
        showCancelButton: true,
        ...overlordSwalConfig,
      });

      if (result.isConfirmed) {
        await invoke("run_optimization_script", {
          scriptName: "shutdown",
          isLaptop: false,
          ramGb: 0,
          gameList: "",
        });
      }
    }
  }

  async function revertirStock() {
    const result = await Swal.fire({
      title: "ATENCIÓN",
      text: "¿Estás seguro de revertir los cambios y volver a stock?",
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: "SÍ, REVERTIR",
      cancelButtonText: "CANCELAR",
      ...overlordSwalConfig,
    });

    if (!result.isConfirmed) return;

    isReverting.value = true;
    try {
      await invoke("run_optimization_script", {
        scriptName: "10_revertir",
        isLaptop: store.hardwareInfo.isLaptop,
        ramGb: store.hardwareInfo.ramGb ?? 8,
        gameList: "",
      });
      store.restorePointCreated = false;
      store.isMonitorRunning = false;

      Object.keys(cardStatus.value).forEach((key) => {
        cardStatus.value[key] = "idle";
        store.modules[key as keyof typeof store.modules] = false;
      });

      await Swal.fire({
        title: "SISTEMA REVERTIDO",
        text: "Reinicia tu PC para aplicar los valores de fábrica.",
        icon: "success",
        ...overlordSwalConfig,
      });
    } catch (error) {
      console.error("[FALLO EN REVERSIÓN]:", error);
    } finally {
      isReverting.value = false;
    }
  }

  async function syncModulesStatus() {
    try {
      const jsonStatus = await invoke<string>("run_optimization_script", {
        scriptName: "get_modules_status",
        isLaptop: store.hardwareInfo.isLaptop,
        ramGb: store.hardwareInfo.ramGb ?? 8,
        gameList: "",
      });

      const realStatus = JSON.parse(jsonStatus);
      Object.keys(realStatus).forEach((key) => {
        const moduleKey = key as keyof typeof store.modules;
        if (realStatus[moduleKey]) {
          cardStatus.value[moduleKey] = "success";
          store.modules[moduleKey] = false;
        } else {
          cardStatus.value[moduleKey] = "idle";
          store.modules[moduleKey] = false;
        }
      });

      const { isLaptop, tier } = store.hardwareInfo;
      const profileConfigs: Record<string, string[]> = {
        Competitivo: [
          "peripheralLatency", "debloat", "networkOptimized", "generalPerformance",
          "gpuDisplay", "irqAffinity", "smartStorage", "deepTelemetry", "powerProfiles",
          "gameHooks", "disableMitigations"
        ],
        "Programador & Competitivo": [
          "peripheralLatency", "debloat", "networkOptimized", "generalPerformance",
          "gpuDisplay", "smartStorage", "powerProfiles", "gameHooks", "disableMitigations"
        ],
        Programador: ["debloat", "networkOptimized", "smartStorage"],
        "Home Office / Laptops": ["debloat", "networkOptimized", "smartStorage"],
        "Usuario Casual": ["debloat", "smartStorage"]
      };

      let matchedProfile = "Personalizado";
      for (const [profileName, profileMods] of Object.entries(profileConfigs)) {
        let expected: Record<string, boolean> = {
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
          disableMitigations: false
        };

        profileMods.forEach((mod) => {
          if (mod === "irqAffinity" && isLaptop) return;
          if (mod === "powerProfiles" && isLaptop) return;
          if (mod === "networkOptimized" && isLaptop) return;
          if (mod === "irqAffinity" && tier === "Gama Estándar") return;
          if (mod === "disableMitigations" && tier !== "Gama Estándar") return;
          expected[mod] = true;
        });

        let isMatch = true;
        for (const modKey of Object.keys(expected)) {
          if (!!realStatus[modKey] !== expected[modKey]) {
            isMatch = false;
            break;
          }
        }

        if (isMatch) {
          matchedProfile = profileName;
          break;
        }
      }
      store.activeProfile = matchedProfile;
    } catch (e) {
      console.error("[ERROR AL CARGAR ESTADOS INICIALES]:", e);
    }
  }

  return {
    cardStatus,
    isBackingUp,
    isReverting,
    isExecutingAll,
    crearRespaldo,
    ejecutarTodo,
    revertirStock,
    syncModulesStatus,
  };
}
