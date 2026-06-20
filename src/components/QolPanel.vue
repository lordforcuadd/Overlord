<template>
  <div
    class="mb-12 rounded-2xl border border-white/10 bg-[#0a0a0a]/80 backdrop-blur-xl p-6 md:p-8 shadow-[0_0_30px_rgba(0,0,0,0.5)]"
  >
    <div class="mb-8 flex items-center gap-4 border-b border-white/5 pb-5">
      <div
        class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-yellow-500/10 border border-yellow-500/20"
      >
        <svg
          class="w-5 h-5 text-yellow-500"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"
          ></path>
        </svg>
      </div>
      <div>
        <h2 class="text-xl md:text-2xl font-bold text-white tracking-wide">
          Ajustes Instantáneos (QoL)
        </h2>
        <p class="text-sm text-gray-400 mt-1">Modificaciones de sistema</p>
      </div>
    </div>

    <div class="grid grid-cols-1 gap-8 md:grid-cols-2 xl:grid-cols-4">
      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2 mb-1 text-yellow-500 pl-1">
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
            />
          </svg>
          <h3 class="text-xs font-bold uppercase tracking-widest">
            Interfaz & UI
          </h3>
        </div>
        <div
          v-for="item in uiToggles"
          :key="item.id"
          class="flex items-center justify-between rounded-xl px-4 py-3.5 transition-all duration-300 border border-transparent hover:border-white/5 hover:bg-white/5"
          :class="getRowClass(item.id)"
        >
          <div class="pr-4">
            <div class="text-sm font-bold text-gray-200 leading-tight">
              {{ item.title }}
            </div>
            <div class="text-xs text-gray-400 mt-1.5 leading-relaxed">
              {{ getDescription(item.id) }}
            </div>
          </div>
          <button
            @click="!isScanning && applyToggle(item.id)"
            :disabled="isScanning || qolStatus[item.id] === 'loading'"
            :class="qol[item.id] ? 'bg-yellow-500' : 'bg-neutral-700'"
            class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span
              :class="qol[item.id] ? 'translate-x-5' : 'translate-x-0'"
              class="inline-block h-5 w-5 transform rounded-full bg-white shadow transition duration-200"
            ></span>
          </button>
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2 mb-1 text-yellow-500 pl-1">
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
            />
          </svg>
          <h3 class="text-xs font-bold uppercase tracking-widest">
            Privacidad & Sistema
          </h3>
        </div>
        <div
          v-for="item in privacyToggles"
          :key="item.id"
          class="flex items-center justify-between rounded-xl px-4 py-3.5 transition-all duration-300 border border-transparent hover:border-white/5 hover:bg-white/5"
          :class="getRowClass(item.id)"
        >
          <div class="pr-4">
            <div class="text-sm font-bold text-gray-200 leading-tight">
              {{ item.title }}
            </div>
            <div class="text-xs text-gray-400 mt-1.5 leading-relaxed">
              {{ getDescription(item.id) }}
            </div>
          </div>
          <button
            @click="!isScanning && applyToggle(item.id)"
            :disabled="isScanning || qolStatus[item.id] === 'loading'"
            :class="qol[item.id] ? 'bg-yellow-500' : 'bg-neutral-700'"
            class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span
              :class="qol[item.id] ? 'translate-x-5' : 'translate-x-0'"
              class="inline-block h-5 w-5 transform rounded-full bg-white shadow transition duration-200"
            ></span>
          </button>
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2 mb-1 text-yellow-500 pl-1">
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 10V3L4 14h7v7l9-11h-7z"
            />
          </svg>
          <h3 class="text-xs font-bold uppercase tracking-widest">
            Gaming & Atajos
          </h3>
        </div>
        <div
          v-for="item in gamingToggles"
          :key="item.id"
          class="flex items-center justify-between rounded-xl px-4 py-3.5 transition-all duration-300 border border-transparent hover:border-white/5 hover:bg-white/5"
          :class="getRowClass(item.id)"
        >
          <div class="pr-4">
            <div class="text-sm font-bold text-gray-200 leading-tight">
              {{ item.title }}
            </div>
            <div class="text-xs text-gray-400 mt-1.5 leading-relaxed">
              {{ getDescription(item.id) }}
            </div>
          </div>
          <button
            @click="!isScanning && applyToggle(item.id)"
            :disabled="isScanning || qolStatus[item.id] === 'loading'"
            :class="qol[item.id] ? 'bg-yellow-500' : 'bg-neutral-700'"
            class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span
              :class="qol[item.id] ? 'translate-x-5' : 'translate-x-0'"
              class="inline-block h-5 w-5 transform rounded-full bg-white shadow transition duration-200"
            ></span>
          </button>
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2 mb-1 text-yellow-500 pl-1">
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
            />
          </svg>
          <h3 class="text-xs font-bold uppercase tracking-widest">
            Explorador
          </h3>
        </div>
        <div
          v-for="item in explorerToggles"
          :key="item.id"
          class="flex items-center justify-between rounded-xl px-4 py-3.5 transition-all duration-300 border border-transparent hover:border-white/5 hover:bg-white/5"
          :class="getRowClass(item.id)"
        >
          <div class="pr-4">
            <div class="text-sm font-bold text-gray-200 leading-tight">
              {{ item.title }}
            </div>
            <div class="text-xs text-gray-400 mt-1.5 leading-relaxed">
              {{ getDescription(item.id) }}
            </div>
          </div>
          <button
            @click="!isScanning && applyToggle(item.id)"
            :disabled="isScanning || qolStatus[item.id] === 'loading'"
            :class="qol[item.id] ? 'bg-yellow-500' : 'bg-neutral-700'"
            class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span
              :class="qol[item.id] ? 'translate-x-5' : 'translate-x-0'"
              class="inline-block h-5 w-5 transform rounded-full bg-white shadow transition duration-200"
            ></span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { useOverlordStore } from "../stores/overlordStore";

const isScanning = ref(true);
const windowsBuild = ref(0);
const store = useOverlordStore();

type QolKeys =
  | "darkMode"
  | "showExtensions"
  | "classicMenu"
  | "disableBing"
  | "disableLockScreen"
  | "disableStickyKeys"
  | "cleanAltTab"
  | "taskbarLeft"
  | "showHiddenFiles"
  | "launchToThisPC"
  | "disableExplorerAds"
  | "disableScoobe"
  | "disableFilterKeys"
  | "disableCopilot"
  | "disableRecall"
  | "detailedBSoD"
  | "disableOneDrive"
  | "disableWidgets"
  | "zeroStartupDelay"
  | "enableGameMode"
  | "barebonesVisual";

type QolStatusKeys = {
  [K in QolKeys]: "idle" | "loading" | "success" | "error";
};

const qol = ref<Record<QolKeys, boolean>>({
  darkMode: false,
  showExtensions: false,
  classicMenu: false,
  disableBing: false,
  disableLockScreen: false,
  disableStickyKeys: false,
  cleanAltTab: false,
  taskbarLeft: false,
  showHiddenFiles: false,
  launchToThisPC: false,
  disableExplorerAds: false,
  disableScoobe: false,
  disableFilterKeys: false,
  disableCopilot: false,
  disableRecall: false,
  detailedBSoD: false,
  disableOneDrive: false,
  disableWidgets: false,
  zeroStartupDelay: false,
  enableGameMode: false,
  barebonesVisual: false,
});

const qolStatus = ref<QolStatusKeys>({
  darkMode: "idle",
  showExtensions: "idle",
  classicMenu: "idle",
  disableBing: "idle",
  disableLockScreen: "idle",
  disableStickyKeys: "idle",
  cleanAltTab: "idle",
  taskbarLeft: "idle",
  showHiddenFiles: "idle",
  launchToThisPC: "idle",
  disableExplorerAds: "idle",
  disableScoobe: "idle",
  disableFilterKeys: "idle",
  disableCopilot: "idle",
  disableRecall: "idle",
  detailedBSoD: "idle",
  disableOneDrive: "idle",
  disableWidgets: "idle",
  zeroStartupDelay: "idle",
  enableGameMode: "idle",
  barebonesVisual: "idle",
});

const uiToggles = [
  {
    id: "barebonesVisual" as const,
    title: "Rendimiento Visual (Barebones)",
    desc: "Optimiza efectos y animaciones conservando suavizado ClearType.",
  },
  {
    id: "darkMode" as const,
    title: "Modo Oscuro Global",
    desc: "Fuerza el tema oscuro nativo.",
  },
  {
    id: "showExtensions" as const,
    title: "Mostrar Extensiones",
    desc: "Hace visibles formatos como .exe, .ps1.",
  },
  { id: "classicMenu" as const, title: "Menú Clásico Win 11", desc: "" },
  {
    id: "taskbarLeft" as const,
    title: "Barra a la Izquierda (Win11)",
    desc: "Mueve los iconos al estilo clásico.",
  },
  {
    id: "cleanAltTab" as const,
    title: "Alt+Tab Limpio",
    desc: "Oculta las pestañas de Edge del atajo.",
  },
  {
    id: "detailedBSoD" as const,
    title: "Pantallazo Azul Detallado",
    desc: "Muestra códigos de error reales.",
  },
];

const privacyToggles = [
  {
    id: "disableBing" as const,
    title: "Erradicar Bing",
    desc: "Desactiva búsquedas y sugerencias web en el Menú Inicio.",
  },
  {
    id: "disableLockScreen" as const,
    title: "Ocultar Lock Screen",
    desc: "Va directo a la pantalla de contraseña.",
  },
  {
    id: "disableExplorerAds" as const,
    title: "Bloquear Ads Nativos",
    desc: "Oculta banners de OneDrive y Office.",
  },
  {
    id: "disableScoobe" as const,
    title: 'Ocultar "Terminemos de Configurar"',
    desc: "Bloquea pantallas de bienvenida y sugerencias post-update.",
  },
  {
    id: "disableCopilot" as const,
    title: "Erradicar MS Copilot",
    desc: "Bloquea el uso y telemetría de Copilot.",
  },
  {
    id: "disableRecall" as const,
    title: "Bloquear Windows Recall",
    desc: "Impide capturas de pantalla.",
  },
];

const explorerToggles = [
  {
    id: "showHiddenFiles" as const,
    title: "Mostrar Archivos Ocultos",
    desc: "Revela carpetas ocultas.",
  },
  {
    id: "launchToThisPC" as const,
    title: 'Iniciar en "Este Equipo"',
    desc: "Evita la vista de historial.",
  },
  {
    id: "disableOneDrive" as const,
    title: "Erradicar OneDrive",
    desc: "Desinstala y bloquea la nube.",
  },
  {
    id: "zeroStartupDelay" as const,
    title: "Cero Retraso de Arranque",
    desc: "Apps de inicio instantáneas.",
  },
];

const gamingToggles = [
  {
    id: "disableStickyKeys" as const,
    title: "Desactivar Sticky Keys",
    desc: "Evita minimizar juegos.",
  },
  {
    id: "disableFilterKeys" as const,
    title: "Desactivar Teclas Filtro",
    desc: "Bloquea alertas de Shift.",
  },
  {
    id: "disableWidgets" as const,
    title: "Erradicar Widgets",
    desc: "Elimina el panel de noticias.",
  },
  {
    id: "enableGameMode" as const,
    title: "Modo Juego",
    desc: "Prioriza hilos de juegos y apaga grabación GameDVR de fondo.",
  },
];

function getDescription(id: QolKeys): string {
  if (id === "classicMenu") {
    if (windowsBuild.value >= 27000) {
      return "⚠️ Usa ExplorerPatcher. El toggle refleja el estado real.";
    } else if (windowsBuild.value >= 26000) {
      return "⚠️ Solo con ExplorerPatcher. El toggle refleja el estado real.";
    } else if (windowsBuild.value >= 22000) {
      return "Recupera el clic derecho de Windows 10.";
    } else {
      return "Ya es clásico en Windows 10.";
    }
  }
  const all = [
    ...uiToggles,
    ...privacyToggles,
    ...explorerToggles,
    ...gamingToggles,
  ];
  const found = all.find((t) => t.id === id);
  return found ? found.desc : "";
}

function getRowClass(id: QolKeys) {
  const status = qolStatus.value[id];
  if (status === "loading") return "bg-yellow-900/20";
  if (status === "success") return "bg-green-900/20";
  if (status === "error") return "bg-red-900/20";
  return "bg-[#121212] border border-neutral-800/60";
}

onMounted(async () => {
  try {
    const jsonOutput = await invoke<string>("run_optimization_script", {
      scriptName: "get_qol",
      isLaptop: store.hardwareInfo.isLaptop,
      ramGb: store.hardwareInfo.ramGb ?? 8,
      gameList: "",
    });
    const data = JSON.parse(jsonOutput);
    const { windowsBuild: build, ...rest } = data;
    qol.value = rest as Record<QolKeys, boolean>;
    windowsBuild.value = build || 0;
  } catch (e) {
    console.error("[CRITICAL QOL SCAN ERROR]:", e);
  } finally {
    isScanning.value = false;
  }
});

async function applyToggle(settingKey: QolKeys) {
  if (qolStatus.value[settingKey] === "loading") return;
  const previousState = qol.value[settingKey];
  qol.value[settingKey] = !qol.value[settingKey];
  qolStatus.value[settingKey] = "loading";

  try {
    const isEnabledStr = qol.value[settingKey] ? "true" : "false";

    const output = await invoke<string>("run_optimization_script", {
      scriptName: "set_qol",
      isLaptop: store.hardwareInfo.isLaptop,
      ramGb: store.hardwareInfo.ramGb ?? 8,
      gameList: `${settingKey}:${isEnabledStr}`,
    });

    console.log(`[QoL Toggle Success] ${settingKey} | Output:`, output);
    qolStatus.value[settingKey] = "success";
    setTimeout(() => {
      if (qolStatus.value[settingKey] === "success")
        qolStatus.value[settingKey] = "idle";
    }, 1500);
  } catch (e) {
    console.error(`[ERROR] ${settingKey}:`, e);
    qolStatus.value[settingKey] = "error";
    qol.value[settingKey] = previousState;
    setTimeout(() => {
      if (qolStatus.value[settingKey] === "error")
        qolStatus.value[settingKey] = "idle";
    }, 2000);
  }
}
</script>
