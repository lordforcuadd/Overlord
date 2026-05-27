<template>
  <div
    class="relative min-h-screen bg-[#050505] text-gray-200 font-sans p-6 md:p-10 overflow-x-hidden z-0"
  >
    <div
      class="fixed top-[-10%] left-[-5%] w-[500px] h-[500px] bg-yellow-500/10 rounded-full blur-[120px] -z-10 pointer-events-none"
    ></div>
    <div
      class="fixed bottom-[-10%] right-[-5%] w-[400px] h-[400px] bg-yellow-500/10 rounded-full blur-[120px] -z-10 pointer-events-none"
    ></div>

    <div class="max-w-7xl mx-auto relative z-10">
      <header
        class="mb-14 flex flex-col lg:flex-row justify-between items-start lg:items-center border-b border-white/10 pb-8 gap-8"
      >
        <div class="flex items-center gap-4">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-12 h-12 md:w-16 md:h-16 text-yellow-500 shrink-0 transform hover:scale-105 transition-transform duration-300"
          >
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M2 21L2 9L8.5 14L12 2 15.5 14L22 9L22 21H2ZM13 8L9 14H11.5L11 20L15 14H12.5L13 8Z"
            />
          </svg>
          <div>
            <h1
              class="text-5xl md:text-6xl font-black tracking-tighter text-white"
            >
              OVER<span class="text-yellow-500">LORD</span>
            </h1>
            <p
              class="text-gray-400 mt-1 font-medium tracking-widest uppercase text-xs md:text-sm"
            >
              Optimizador de Windows v2.5
            </p>
          </div>
        </div>

        <HardwareSidebar />
      </header>

      <QuickActions />

      <QolPanel />

      <div
        class="mb-6 flex items-center justify-between bg-white/5 border border-white/10 p-4 rounded-xl max-w-xs"
      >
        <span class="text-sm font-bold uppercase tracking-wider text-gray-300"
          >Modo Simulación (Dry-Run)</span
        >
        <label class="relative inline-flex items-center cursor-pointer">
          <input type="checkbox" v-model="isDryRun" class="sr-only peer" />
          <div
            class="w-9 h-5 bg-zinc-700 rounded-full relative peer peer-checked:after:translate-x-4 peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-blue-500"
          ></div>
        </label>
      </div>

      <ProfileSelector />

      <OptimizationGrid
        :cardStatus="cardStatus"
        @trigger-warning="openWarningModal"
      />

      <footer
        class="mb-24 flex flex-col items-center gap-6 border-t border-white/5 pt-10"
      >
        <div
          class="flex flex-col md:flex-row justify-center gap-4 w-full md:w-auto"
        >
          <button
            @click="crearRespaldo"
            :disabled="isBackingUp"
            class="group bg-blue-500/10 backdrop-blur-md border border-blue-500/30 text-blue-400 hover:bg-blue-500/20 hover:text-blue-300 font-bold py-4 px-8 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(59,130,246,0.1)] flex items-center justify-center gap-3 w-full md:w-auto disabled:opacity-50"
          >
            <svg
              v-if="isBackingUp"
              class="animate-spin h-5 w-5"
              viewBox="0 0 24 24"
            >
              <circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              ></circle>
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              ></path>
            </svg>
            <svg
              v-else
              class="h-5 w-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
              ></path>
            </svg>
            <span>{{
              isBackingUp ? "Protegiendo Sistema..." : "Crear Punto de Respaldo"
            }}</span>
          </button>

          <button
            @click="revertirStock"
            :disabled="isReverting"
            class="bg-red-500/10 backdrop-blur-md border border-red-500/30 text-red-400 hover:bg-red-500/20 hover:text-red-300 font-bold py-4 px-8 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(239,68,68,0.1)] flex items-center justify-center gap-3 w-full md:w-auto disabled:opacity-50"
          >
            <svg
              v-if="isReverting"
              class="animate-spin h-5 w-5"
              viewBox="0 0 24 24"
            >
              <circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              ></circle>
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              ></path>
            </svg>
            <svg
              v-else
              class="h-5 w-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0019 16V8a1 1 0 00-1.6-.8l-5.333 4zM4.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0011 16V8a1 1 0 00-1.6-.8l-5.334 4z"
              ></path>
            </svg>
            <span>{{
              isReverting ? "Restaurando Windows..." : "Revertir Cambios"
            }}</span>
          </button>
        </div>
      </footer>
    </div>
  </div>

  <div
    class="fixed bottom-0 left-0 w-full bg-[#050505]/90 backdrop-blur-xl border-t border-white/10 p-5 z-40 flex justify-center items-center shadow-[0_-10px_40px_rgba(0,0,0,0.5)]"
  >
    <div
      class="max-w-7xl w-full flex flex-col md:flex-row justify-between items-center gap-5 px-4"
    >
      <div class="flex items-center gap-4">
        <div
          class="w-12 h-12 rounded-full bg-yellow-500/20 flex items-center justify-center border border-yellow-500/50 shadow-[0_0_15px_rgba(250,204,21,0.2)]"
        >
          <svg
            class="w-6 h-6 text-yellow-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 10V3L4 14h7v7l9-11h-7z"
            ></path>
          </svg>
        </div>
        <div>
          <h3 class="text-white font-bold text-xl leading-tight">Optimizar</h3>
          <p class="text-gray-400 text-sm mt-1">
            Perfil:
            <span class="text-yellow-400 font-bold uppercase">{{
              store.activeProfile
            }}</span>
            <span class="mx-2 text-gray-600">|</span>
            Módulos:
            <span class="text-white font-bold">{{
              Object.values(store.modules).filter((v) => v).length
            }}</span>
            / 10
          </p>
        </div>
      </div>

      <button
        @click="ejecutarTodo"
        :disabled="
          isExecutingAll ||
          Object.values(store.modules).filter((v) => v).length === 0
        "
        class="bg-yellow-500 hover:bg-yellow-400 text-black font-black uppercase tracking-widest py-3 md:py-4 px-10 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(250,204,21,0.3)] disabled:opacity-50 flex items-center gap-3"
      >
        <span v-if="isExecutingAll">Optimizando...</span>
        <span v-else>EJECUTAR OVERLORD</span>
      </button>
    </div>
  </div>

  <WarningModal
    :isOpen="warningModalOpen"
    :message="warningModalMessage"
    @confirm="confirmDangerousTweak"
    @cancel="cancelDangerousTweak"
  />
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from "vue";
import QolPanel from "./components/QolPanel.vue";
import Swal from "sweetalert2";
import QuickActions from "./components/QuickActions.vue";
import { invoke } from "@tauri-apps/api/core";
import { useOverlordStore } from "./stores/overlordStore";
import HardwareSidebar from "./components/HardwareSidebar.vue";
import ProfileSelector from "./components/ProfileSelector.vue";
import OptimizationGrid from "./components/OptimizationGrid.vue";
import WarningModal from "./components/WarningModal.vue";

const store = useOverlordStore();
const cardStatus = ref<
  Record<string, "idle" | "loading" | "success" | "error">
>({});
const isBackingUp = ref(false);
const isReverting = ref(false);
const isExecutingAll = ref(false);
const isDryRun = ref(false);

const warningModalOpen = ref(false);
const warningModalMessage = ref("");
const pendingTweakKey = ref("");

const scriptMap: Record<string, string> = {
  peripheralLatency: "01_perifericos.ps1",
  debloat: "02_debloat.ps1",
  networkOptimized: "03_red.ps1",
  generalPerformance: "04_rendimiento.ps1",
  gpuDisplay: "05_gpu_display.ps1",
  irqAffinity: "06_irq_affinity.ps1",
  smartStorage: "07_almacenamiento.ps1",
  deepTelemetry: "08_telemetria.ps1",
  powerProfiles: "09_energia.ps1",
  gameHooks: "11_game_hooks.ps1",
};

const overlordSwalConfig = {
  background: "rgba(15, 15, 15, 0.75)",
  color: "#e5e5e5",
  iconColor: "#eab308",
  confirmButtonColor: "#eab308",
  cancelButtonColor: "#27272a",
  customClass: {
    popup:
      "backdrop-blur-md border border-yellow-500/30 shadow-[0_0_25px_rgba(234,179,8,0.15)] rounded-2xl",
    title: "text-yellow-500 font-extrabold tracking-wider",
    htmlContainer: "text-gray-300",
    confirmButton:
      "text-black font-bold tracking-wide hover:scale-105 transition-transform duration-200",
    cancelButton:
      "text-gray-300 border border-zinc-600 hover:bg-zinc-700 transition-colors duration-200",
  },
};

const openWarningModal = (payload: { key: string; message: string }) => {
  pendingTweakKey.value = payload.key;
  warningModalMessage.value = payload.message;
  warningModalOpen.value = true;
};

const confirmDangerousTweak = () => {
  const key = pendingTweakKey.value as keyof typeof store.modules;
  store.modules[key] = true;
  warningModalOpen.value = false;
};

const cancelDangerousTweak = () => {
  const key = pendingTweakKey.value as keyof typeof store.modules;
  store.modules[key] = false;
  warningModalOpen.value = false;
};

async function ejecutarTodo() {
  if (isExecutingAll.value) return;

  const modulosActivos = Object.entries(store.modules)
    .filter(([_, isEnabled]) => isEnabled)
    .map(([key]) => key);

  if (modulosActivos.length === 0) return;

  if (isDryRun.value) {
    isExecutingAll.value = true;

    Swal.fire({
      title: "SIMULACIÓN ACTIVA",
      text: "Procesando entorno de prueba secuencial...",
      allowOutsideClick: false,
      didOpen: () => {
        Swal.showLoading();
      },
      ...overlordSwalConfig,
    });

    for (const modKey of modulosActivos) {
      cardStatus.value[modKey] = "loading";
      await new Promise((resolve) => setTimeout(resolve, 1000));
      cardStatus.value[modKey] = "success";
      store.modules[modKey as keyof typeof store.modules] = false;
    }

    isExecutingAll.value = false;

    await Swal.fire({
      title: "SIMULACIÓN COMPLETADA",
      text: "Modo Dry-Run finalizado. Las tarjetas visuales respondieron correctamente sin alterar el registro real.",
      icon: "success",
      ...overlordSwalConfig,
    });
    return;
  }

  if (!store.restorePointCreated) {
    const alertConfirm = await Swal.fire({
      title: "RESPALDO REQUERIDO",
      html: "Para inyectar optimizaciones de nivel Kernel con seguridad, Overlord creará un <b class='text-yellow-400'>Punto de Restauración</b> de respaldo obligatorio.",
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

  for (const modKey of modulosActivos) {
    const scriptName = scriptMap[modKey];
    if (!scriptName) continue;

    cardStatus.value[modKey] = "loading";
    try {
      let gameListOpt = null;
      if (modKey === "gameHooks") {
        gameListOpt = store.gameList
          .filter((g) => g.optimize)
          .map((g) => g.exe)
          .join(",");
      }

      await invoke("run_powershell_async", {
        scriptName: scriptName,
        isLaptop: store.hardwareInfo.isLaptop,
        ramGb: store.hardwareInfo.ram,
        gameList: gameListOpt,
      });

      cardStatus.value[modKey] = "success";
      store.modules[modKey as keyof typeof store.modules] = false;
    } catch (errorOutput) {
      cardStatus.value[modKey] = "error";
    }
  }

  isExecutingAll.value = false;

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
      await invoke("run_powershell_async", {
        scriptName: "shutdown.ps1",
        isLaptop: false,
        ramGb: 0,
        gameList: "",
      });
    }
  }
}

onMounted(async () => {
  await store.detectHardware();
  await store.scanGames();
  store.startTelemetryPolling();

  try {
    const jsonStatus = await invoke<string>("run_powershell_generic", {
      scriptName: "get_modules_status.ps1",
      argsList: [],
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
  } catch (e) {}
});

onUnmounted(() => {
  store.stopTelemetryPolling();
});

async function crearRespaldo() {
  isBackingUp.value = true;
  try {
    await invoke("run_powershell_generic", {
      scriptName: "crear_respaldo.ps1",
      argsList: [],
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
      text: "No se pudo comprobar la integridad del servicio VSS.",
      icon: "error",
      ...overlordSwalConfig,
    });
  } finally {
    isBackingUp.value = false;
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
    await invoke("run_powershell_generic", {
      scriptName: "10_revertir.ps1",
      argsList: [],
    });
    store.restorePointCreated = false;

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
  } finally {
    isReverting.value = false;
  }
}
</script>

<style>
body {
  margin: 0;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
::-webkit-scrollbar {
  width: 8px;
}
::-webkit-scrollbar-track {
  background: #050505;
}
::-webkit-scrollbar-thumb {
  background: #222;
  border-radius: 10px;
}
::-webkit-scrollbar-thumb:hover {
  background: #fab005;
}
</style>
