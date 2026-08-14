import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { useOverlordStore } from "../stores/overlordStore";
import { tweaksMetadata, PROFILE_CONFIGS } from "../data/tweaksMetadata";
import { buildExpectedProfileState } from "../stores/profileLogic";
import { copyToClipboard } from "../utils/styleHelpers";
import Swal from "sweetalert2";

const cardStatus = ref<
  Record<string, "idle" | "loading" | "success" | "error">
>({});
const isBackingUp = ref(false);
const isReverting = ref(false);
const isExecutingAll = ref(false);

export function useOrchestrator(overlordSwalConfig: any) {
  const store = useOverlordStore();

  async function crearRespaldo() {
    isBackingUp.value = true;
    const wasAlreadyBusy = store.isGlobalBusy;
    if (!wasAlreadyBusy) store.setGlobalBusy(true);
    try {
      await invoke("run_optimization_script", {
        scriptName: "crear_respaldo",
        isLaptop: store.hardwareInfo.isLaptop,
        ramGb: store.hardwareInfo.ramGb || 8,
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
      if (String(error).includes("[WARNING]")) {
        const confirmBypass = await Swal.fire({
          title: "ADVERTENCIA DE VSS",
          html: "No se pudo crear el Punto de Restauración del sistema (el servicio VSS de Windows está inactivo o usas un sistema modificado).<br><br><b>¿Deseas continuar de todos modos?</b> Las optimizaciones y los respaldos locales del Registro de Overlord funcionarán normalmente.",
          icon: "warning",
          showCancelButton: true,
          confirmButtonText: "SÍ, CONTINUAR",
          cancelButtonText: "CANCELAR",
          ...overlordSwalConfig,
        });
        if (confirmBypass.isConfirmed) {
          store.restorePointCreated = true;
        }
      } else {
        await Swal.fire({
          title: "ERROR DE RESPALDO",
          text: "No se pudo comprobar la integridad del servicio VSS u Overlord no cuenta con privilegios de Administrador.",
          icon: "error",
          ...overlordSwalConfig,
        });
      }
    } finally {
      isBackingUp.value = false;
      if (!wasAlreadyBusy) store.setGlobalBusy(false);
    }
  }

  async function ejecutarTodo() {
    if (isExecutingAll.value || store.isGlobalBusy) return;

    const modulosActivos = Object.entries(store.modules)
      .filter(([_, isEnabled]) => isEnabled)
      .map(([key]) => key);

    if (modulosActivos.length === 0) return;

    store.setGlobalBusy(true);
    isExecutingAll.value = true;
    try {
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

      const modulosExitosos: string[] = [];
      let failedModTitle = "";
      let failedModReason = "";
      let failedModRawError = "";
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
            ramGb: store.hardwareInfo.ramGb || 8,
            gameList: gameListOpt,
          });

          if (modKey === "gameHooks" && gameListOpt) {
            store.isMonitorRunning = true;
            await invoke("start_game_priority_monitor", {
              gameListRaw: gameListOpt,
            });
            await store.togglePriorityService(store.priorityServiceSelected);
          }

          cardStatus.value[modKey] = "success";
          store.modules[modKey as keyof typeof store.modules] = true;
          modulosExitosos.push(tweaksMetadata[modKey]?.title || modKey);
        } catch (errorOutput) {
          console.error(`[FALLO EN MÓDULO ${modKey}]:`, errorOutput);
          invoke("log_from_js", {
            msg: `[FALLO EN MÓDULO ${modKey}]: ${String(errorOutput)}`,
          }).catch(() => {});
          cardStatus.value[modKey] = "error";

          const errStr = String(errorOutput);
          const lines = errStr.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
          const meaningful = lines.filter(
            (l) =>
              !/^\$\w+\s*=/.test(l) &&
              !l.startsWith("#") &&
              !l.startsWith("+") &&
              !l.startsWith("At line:") &&
              !l.startsWith("En línea:") &&
              !l.includes("CategoryInfo") &&
              !l.includes("FullyQualifiedErrorId")
          );
          failedModRawError = errStr;
          failedModTitle = tweaksMetadata[modKey]?.title || modKey;
          failedModReason = (meaningful.length > 0 ? meaningful[0] : errStr).substring(0, 150);
          huboError = true;
          break;
        }
      }

      if (huboError) {
        try {
          await invoke("stop_game_priority_monitor").catch((err) => {
            console.error("[RUST MONITOR STOP FAIL ON ROLLBACK]:", err);
          });

          await store.togglePriorityService(false).catch((err) => {
            console.error("[SYSTEM DAEMON UNINSTALL FAIL ON ROLLBACK]:", err);
          });

          await invoke("run_optimization_script", {
            scriptName: "10_revertir",
            isLaptop: store.hardwareInfo.isLaptop,
            ramGb: store.hardwareInfo.ramGb || 8,
            gameList: "",
          });
        } catch (rollbackErr) {
          console.error("[AUTO-ROLLBACK FAIL]:", rollbackErr);
        }

        const textoExitos =
          modulosExitosos.length > 0
            ? `Los módulos <b>${modulosExitosos.join(", ")}</b> se habían aplicado, pero se ejecutó un rollback automático por seguridad.`
            : "Ningún módulo previo pudo completarse.";

        await Swal.fire({
          title: "OPTIMIZACIÓN FALLIDA",
          html: `
            <div class='text-left text-sm text-gray-300'>
              <p class='mb-2'>${textoExitos}</p>
              <p class='mb-1 font-semibold text-gray-200'>El módulo <b>${failedModTitle}</b> falló durante la inyección:</p>
              <div class='max-h-40 overflow-y-auto bg-black/50 p-3 rounded-lg border border-red-500/30 text-xs text-red-400 font-mono select-all my-2 whitespace-pre-wrap leading-relaxed'>${failedModReason}</div>
              <p class='text-xs text-gray-400 mt-2'>El sistema ha sido revertido a su estado inicial por seguridad.</p>
            </div>
          `,
          icon: "error",
          showDenyButton: true,
          denyButtonText: "📋 Copiar Error",
          confirmButtonText: "Entendido",
          ...overlordSwalConfig,
        }).then(async (res) => {
          if (res.isDenied) {
            await copyToClipboard(failedModRawError);
            Swal.fire({
              title: "¡Copiado!",
              text: "El detalle del error ha sido copiado al portapapeles.",
              icon: "success",
              timer: 2000,
              showConfirmButton: false,
              ...overlordSwalConfig,
            });
          }
        });
        return;
      }

      await syncModulesStatus();

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
          try {
            await invoke("run_optimization_script", {
              scriptName: "shutdown",
              isLaptop: false,
              ramGb: 0,
              gameList: "",
            });
          } catch (err) {
            console.error("Fallo al ejecutar reinicio del sistema:", err);
            await Swal.fire({
              title: "ERROR AL REINICIAR",
              text: "No se pudo iniciar el proceso de reinicio. Reinicia tu PC manualmente para aplicar los cambios.",
              icon: "error",
              ...overlordSwalConfig,
            });
          }
        }
      }
    } finally {
      isExecutingAll.value = false;
      store.setGlobalBusy(false);
    }
  }

  async function revertirStock() {
    if (store.isGlobalBusy) return;

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
    store.setGlobalBusy(true);
    try {
      // 1. Detener el monitor dinámico en Rust
      await invoke("stop_game_priority_monitor").catch((err) => {
        console.error("[RUST MONITOR STOP FAIL]:", err);
      });

      // 2. Desinstalar el servicio/daemon de prioridad SYSTEM
      await store.togglePriorityService(false).catch((err) => {
        console.error("[SYSTEM DAEMON UNINSTALL FAIL]:", err);
      });

      await invoke("run_optimization_script", {
        scriptName: "10_revertir",
        isLaptop: store.hardwareInfo.isLaptop,
        ramGb: store.hardwareInfo.ramGb || 8,
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
      await Swal.fire({
        title: "ERROR EN REVERSIÓN",
        text: `No se pudo restaurar el estado de fábrica de Windows: ${error}`,
        icon: "error",
        ...overlordSwalConfig,
      });
    } finally {
      isReverting.value = false;
      store.setGlobalBusy(false);
    }
  }

  async function syncModulesStatus() {
    try {
      const jsonStatus = await invoke<string>("run_optimization_script", {
        scriptName: "get_modules_status",
        isLaptop: store.hardwareInfo.isLaptop,
        ramGb: store.hardwareInfo.ramGb || 8,
        gameList: "",
      });

      const realStatus = JSON.parse(jsonStatus);
      Object.keys(realStatus).forEach((key) => {
        const moduleKey = key as keyof typeof store.modules;
        const isApplied = !!realStatus[moduleKey];
        store.modules[moduleKey] = isApplied;
        cardStatus.value[moduleKey] = isApplied ? "success" : "idle";
      });

      const { isLaptop, tier } = store.hardwareInfo;
      let matchedProfile = "Personalizado";
      for (const [profileName, profileMods] of Object.entries(PROFILE_CONFIGS)) {
        const expected = buildExpectedProfileState(profileMods, { isLaptop, tier });

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


