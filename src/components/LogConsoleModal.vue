<template>
  <div
    v-if="store.isLogModalOpen"
    class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md transition-all duration-300 animate-fade-in"
    @click.self="store.closeLogModal"
  >
    <div
      class="bg-[#0b0b0e] border border-yellow-500/30 w-full max-w-4xl max-h-[85vh] rounded-2xl flex flex-col shadow-[0_0_50px_rgba(234,179,8,0.15)] overflow-hidden"
    >
      <!-- Modal Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-white/10 bg-white/[0.02]"
      >
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-lg bg-yellow-500/10 border border-yellow-500/20 text-yellow-400">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
          </div>
          <div>
            <h2 class="text-lg font-bold text-white tracking-wide flex items-center gap-2">
              CONSOLA DE EVENTOS, LOGS & HISTORIAL
              <span class="text-xs px-2 py-0.5 rounded bg-yellow-500/20 text-yellow-300 font-mono">
                DIAGNÓSTICO
              </span>
            </h2>
            <p class="text-xs text-gray-400">
              Auditoría en tiempo real de operaciones, inyecciones de kernel y actividad del daemon
            </p>
          </div>
        </div>

        <button
          @click="store.closeLogModal"
          class="p-2 rounded-xl text-gray-400 hover:text-white hover:bg-white/10 transition-colors"
          title="Cerrar Consola"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Tab Switcher & Action Bar -->
      <div class="flex flex-wrap items-center justify-between px-6 py-3 border-b border-white/5 bg-black/40 gap-3">
        <div class="flex items-center gap-2">
          <button
            @click="activeTab = 'overlord'"
            :class="[
              'px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2',
              activeTab === 'overlord'
                ? 'bg-yellow-500/20 text-yellow-300 border border-yellow-500/40 shadow-[0_0_15px_rgba(234,179,8,0.2)]'
                : 'text-gray-400 hover:text-white hover:bg-white/5 border border-transparent'
            ]"
          >
            <span class="w-2 h-2 rounded-full bg-yellow-400"></span>
            Logs del Sistema
          </button>

          <button
            @click="activeTab = 'daemon'"
            :class="[
              'px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2',
              activeTab === 'daemon'
                ? 'bg-blue-500/20 text-blue-300 border border-blue-500/40 shadow-[0_0_15px_rgba(59,130,246,0.2)]'
                : 'text-gray-400 hover:text-white hover:bg-white/5 border border-transparent'
            ]"
          >
            <span
              :class="[
                'w-2 h-2 rounded-full',
                store.daemonStatus.isInstalled ? 'bg-green-400' : 'bg-gray-500'
              ]"
            ></span>
            Daemon SYSTEM
            <span
              v-if="store.daemonStatus.activeGame"
              class="px-1.5 py-0.5 rounded text-[10px] bg-blue-500/30 text-blue-200"
            >
              {{ store.daemonStatus.activeGame }}
            </span>
          </button>

          <button
            @click="activeTab = 'history'"
            :class="[
              'px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2',
              activeTab === 'history'
                ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 shadow-[0_0_15px_rgba(16,185,129,0.2)]'
                : 'text-gray-400 hover:text-white hover:bg-white/5 border border-transparent'
            ]"
          >
            <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
            Historial de Inyecciones
            <span
              v-if="store.history.length > 0"
              class="px-1.5 py-0.5 rounded text-[10px] bg-emerald-500/30 text-emerald-200 font-mono"
            >
              {{ store.history.length }}
            </span>
          </button>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center gap-2">
          <button
            @click="refreshLogs"
            :disabled="isLoading"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-white/5 hover:bg-white/10 text-gray-300 hover:text-white transition-all flex items-center gap-1.5 border border-white/5 disabled:opacity-50"
            title="Refrescar contenido"
          >
            <svg
              :class="['w-3.5 h-3.5', isLoading ? 'animate-spin' : '']"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
              />
            </svg>
            <span>Refrescar</span>
          </button>

          <button
            @click="copyActiveContent"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-white/5 hover:bg-white/10 text-gray-300 hover:text-white transition-all flex items-center gap-1.5 border border-white/5"
            title="Copiar contenido al portapapeles"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"
              />
            </svg>
            <span>{{ isCopied ? "¡Copiado!" : "Copiar" }}</span>
          </button>

          <button
            v-if="activeTab === 'history' && store.history.length > 0"
            @click="store.clearHistory"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-500/10 hover:bg-red-500/20 text-red-300 transition-all flex items-center gap-1.5 border border-red-500/20"
            title="Borrar historial local"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
              />
            </svg>
            <span>Limpiar</span>
          </button>
        </div>
      </div>

      <!-- Tab Content Area -->
      <div class="flex-1 overflow-y-auto p-6 font-mono text-xs leading-relaxed max-h-[60vh]">
        <!-- Overlord Logs Tab -->
        <div v-if="activeTab === 'overlord'" class="space-y-1">
          <div v-if="overlordLogs" class="whitespace-pre-wrap select-all text-gray-300">
            <div
              v-for="(line, idx) in formattedOverlordLogs"
              :key="'ov-' + idx"
              :class="getLineClass(line)"
            >
              {{ line }}
            </div>
          </div>
          <div v-else class="text-gray-500 text-center py-12">
            No hay registros de eventos en Overlord actualmente.
          </div>
        </div>

        <!-- Daemon Logs Tab -->
        <div v-else-if="activeTab === 'daemon'" class="space-y-1">
          <div
            class="p-3 mb-4 rounded-xl bg-blue-500/10 border border-blue-500/20 text-blue-300 flex items-center justify-between"
          >
            <div class="flex items-center gap-2 font-sans text-xs">
              <span class="font-bold">ESTADO DEL DAEMON:</span>
              <span>{{ store.daemonStatus.statusText }}</span>
            </div>
            <div class="font-mono text-[11px] text-blue-400">
              Poller: 15s · SYSTEM
            </div>
          </div>

          <div v-if="daemonLogs" class="whitespace-pre-wrap select-all text-gray-300">
            <div
              v-for="(line, idx) in formattedDaemonLogs"
              :key="'dm-' + idx"
              :class="getLineClass(line)"
            >
              {{ line }}
            </div>
          </div>
          <div v-else class="text-gray-500 text-center py-12">
            El daemon de prioridad no se encuentra instalado o aún no ha registrado actividad.
          </div>
        </div>

        <!-- History Tab -->
        <div v-else-if="activeTab === 'history'" class="space-y-3 font-sans">
          <div v-if="store.history.length === 0" class="text-gray-500 text-center py-12">
            No se han registrado inyecciones de optimización todavía en esta sesión.
          </div>
          <div
            v-for="entry in store.history"
            :key="entry.id"
            class="p-3 rounded-xl border transition-all flex items-start justify-between gap-4 bg-white/[0.02]"
            :class="[
              entry.status === 'success'
                ? 'border-emerald-500/20 hover:border-emerald-500/40'
                : entry.status === 'error'
                ? 'border-red-500/30 hover:border-red-500/50'
                : 'border-yellow-500/20 hover:border-yellow-500/40'
            ]"
          >
            <div class="flex items-start gap-3">
              <div
                class="w-6 h-6 rounded-lg flex items-center justify-center shrink-0 mt-0.5"
                :class="[
                  entry.status === 'success'
                    ? 'bg-emerald-500/20 text-emerald-400'
                    : entry.status === 'error'
                    ? 'bg-red-500/20 text-red-400'
                    : 'bg-yellow-500/20 text-yellow-400'
                ]"
              >
                <svg v-if="entry.status === 'success'" class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                <svg v-else-if="entry.status === 'error'" class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
                <svg v-else class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>

              <div>
                <div class="flex items-center gap-2">
                  <span class="text-sm font-bold text-white">{{ entry.action }}</span>
                  <span
                    class="text-[10px] px-1.5 py-0.5 rounded font-mono"
                    :class="[
                      entry.status === 'success'
                        ? 'bg-emerald-500/20 text-emerald-300'
                        : entry.status === 'error'
                        ? 'bg-red-500/20 text-red-300'
                        : 'bg-yellow-500/20 text-yellow-300'
                    ]"
                  >
                    {{ entry.status.toUpperCase() }}
                  </span>
                </div>
                <p v-if="entry.details" class="text-xs text-gray-400 mt-1 font-mono">
                  {{ entry.details }}
                </p>
              </div>
            </div>

            <div class="text-right shrink-0">
              <span class="text-xs text-gray-500 font-mono block">{{ entry.timestamp }}</span>
              <span v-if="entry.durationMs > 0" class="text-[11px] text-yellow-400/80 font-mono">
                {{ entry.durationMs }}ms
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer Info -->
      <div class="px-6 py-3 border-t border-white/5 bg-black/40 flex items-center justify-between text-xs text-gray-500">
        <div class="flex items-center gap-2">
          <span class="w-1.5 h-1.5 rounded-full bg-yellow-500"></span>
          <span>Overlord v4.6.0 · Monitoreo y Trazabilidad Activos</span>
        </div>
        <button
          @click="store.closeLogModal"
          class="text-gray-400 hover:text-white transition-colors"
        >
          Cerrar [ESC]
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { useOverlordStore } from "../stores/overlordStore";
import { copyToClipboard } from "../utils/styleHelpers";

const store = useOverlordStore();

const activeTab = ref<"overlord" | "daemon" | "history">("overlord");
const overlordLogs = ref("");
const daemonLogs = ref("");
const isLoading = ref(false);
const isCopied = ref(false);

const formattedOverlordLogs = computed(() => {
  return overlordLogs.value.split("\n").filter((l) => l.trim().length > 0);
});

const formattedDaemonLogs = computed(() => {
  return daemonLogs.value.split("\n").filter((l) => l.trim().length > 0);
});

function getLineClass(line: string) {
  if (line.includes("[ERROR]") || line.includes("FALLO") || line.includes("Error")) {
    return "text-red-400 font-bold";
  }
  if (line.includes("[WARN]") || line.includes("[WARNING]") || line.includes("Advertencia")) {
    return "text-yellow-400";
  }
  if (line.includes("[INFO]") || line.includes("exitosamente") || line.includes("Iniciando")) {
    return "text-blue-300";
  }
  if (line.includes("ALTA") || line.includes("V-Cache") || line.includes("Afinidad")) {
    return "text-emerald-400 font-semibold";
  }
  return "text-gray-400";
}

async function fetchLogs() {
  isLoading.value = true;
  try {
    const [ovLogs, dLogs] = await Promise.all([
      invoke<string>("read_overlord_log").catch((e) => `Error al leer logs: ${e}`),
      invoke<string>("read_daemon_log").catch((e) => `Error al leer daemon: ${e}`),
      store.fetchDaemonStatus().catch(() => {}),
    ]);
    overlordLogs.value = ovLogs;
    daemonLogs.value = dLogs;
  } finally {
    isLoading.value = false;
  }
}

async function refreshLogs() {
  await fetchLogs();
}

async function copyActiveContent() {
  let content = "";
  if (activeTab.value === "overlord") {
    content = overlordLogs.value;
  } else if (activeTab.value === "daemon") {
    content = `[DAEMON STATUS]: ${store.daemonStatus.statusText}\n\n${daemonLogs.value}`;
  } else {
    content = JSON.stringify(store.history, null, 2);
  }

  await copyToClipboard(content);
  isCopied.value = true;
  setTimeout(() => {
    isCopied.value = false;
  }, 2000);
}

watch(
  () => store.isLogModalOpen,
  (open) => {
    if (open) {
      fetchLogs();
    }
  }
);

onMounted(() => {
  if (store.isLogModalOpen) {
    fetchLogs();
  }
});
</script>

<style scoped>
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: scale(0.98);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.animate-fade-in {
  animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}
</style>
