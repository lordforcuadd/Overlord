<template>
  <div
    v-if="store.isAppxModalOpen"
    class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md transition-all duration-300 animate-fade-in"
    @click.self="store.closeAppxModal"
  >
    <div
      class="bg-[#0b0b0e] border border-yellow-500/30 w-full max-w-4xl max-h-[90vh] rounded-2xl flex flex-col shadow-[0_0_50px_rgba(234,179,8,0.15)] overflow-hidden"
    >
      <!-- Modal Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-white/10 bg-white/[0.02]"
      >
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-xl bg-yellow-500/10 border border-yellow-500/20 text-yellow-400">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
              />
            </svg>
          </div>
          <div>
            <h2 class="text-lg font-bold text-white tracking-wide flex items-center gap-2">
              GESTOR DE BLOATWARE APPX
              <span class="text-xs px-2 py-0.5 rounded bg-yellow-500/20 text-yellow-300 font-mono">
                CURADO 1:1
              </span>
            </h2>
            <p class="text-xs text-gray-400">
              Desinstalación selectiva con copias de seguridad en registro para reversión simétrica
            </p>
          </div>
        </div>

        <button
          @click="store.closeAppxModal"
          class="p-2 rounded-xl text-gray-400 hover:text-white hover:bg-white/10 transition-colors"
          title="Cerrar Gestor"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Controls & Filter Bar -->
      <div class="px-6 py-3.5 border-b border-white/5 bg-black/40 flex flex-col md:flex-row gap-3 items-stretch md:items-center justify-between">
        <!-- Tab Filters -->
        <div class="flex items-center gap-1.5 overflow-x-auto">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            @click="activeTab = tab.id"
            :class="[
              'px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 shrink-0',
              activeTab === tab.id
                ? 'bg-yellow-500/20 text-yellow-300 border border-yellow-500/40'
                : 'text-gray-400 hover:text-white hover:bg-white/5 border border-transparent'
            ]"
          >
            <span>{{ tab.label }}</span>
            <span class="text-[10px] px-1.5 py-0.2 rounded-full bg-white/10 font-mono">
              {{ tab.count }}
            </span>
          </button>
        </div>

        <!-- Search Bar -->
        <div class="relative w-full md:w-64 shrink-0">
          <svg
            class="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar app o paquete..."
            class="w-full bg-[#121214] border border-white/10 rounded-xl pl-9 pr-8 py-1.5 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-yellow-500/50"
          />
          <button
            v-if="searchQuery"
            @click="searchQuery = ''"
            class="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white text-xs"
          >
            ✕
          </button>
        </div>
      </div>

      <!-- Quick Action Buttons -->
      <div class="px-6 py-2.5 bg-white/[0.01] border-b border-white/5 flex flex-wrap items-center justify-between gap-2 text-xs">
        <div class="flex items-center gap-2">
          <button
            @click="selectSafeOnly"
            :disabled="isLoading || isProcessing"
            class="px-3 py-1 rounded-lg bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 font-semibold transition-colors disabled:opacity-50"
          >
            ✓ Seleccionar Seguros
          </button>
          <button
            @click="deselectAll"
            :disabled="isLoading || isProcessing || selectedIds.size === 0"
            class="px-3 py-1 rounded-lg bg-white/5 hover:bg-white/10 text-gray-300 border border-white/10 font-semibold transition-colors disabled:opacity-50"
          >
            Deseleccionar Todo
          </button>
        </div>

        <div class="flex items-center gap-3 text-gray-400">
          <span>Seleccionadas: <b class="text-yellow-400">{{ selectedCount }}</b></span>
          <span class="text-gray-600">|</span>
          <button
            v-if="backedUpCount > 0"
            @click="restoreAllBackedUp"
            :disabled="isLoading || isProcessing"
            class="text-xs text-yellow-400 hover:text-yellow-300 underline font-medium flex items-center gap-1 disabled:opacity-50"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Restaurar {{ backedUpCount }} respaldadas
          </button>
        </div>
      </div>

      <!-- Package List -->
      <div class="flex-1 overflow-y-auto px-6 py-4 space-y-2.5 min-h-[280px]">
        <div v-if="isLoading" class="flex flex-col items-center justify-center py-16 gap-3 text-gray-400">
          <div class="w-8 h-8 border-2 border-yellow-500 border-t-transparent rounded-full animate-spin"></div>
          <p class="text-xs font-mono">Escaneando paquetes AppX instalados en el sistema...</p>
        </div>

        <div v-else-if="filteredPackages.length === 0" class="text-center py-16 text-gray-500 text-xs font-mono">
          No se encontraron paquetes coincidentes con el filtro actual.
        </div>

        <div
          v-else
          v-for="pkg in filteredPackages"
          :key="pkg.id"
          :class="[
            'p-3 rounded-xl border transition-all flex items-center justify-between gap-4',
            pkg.category === 'system'
              ? 'bg-[#121216]/50 border-white/5 opacity-70'
              : selectedIds.has(pkg.id)
                ? 'bg-yellow-500/[0.06] border-yellow-500/40'
                : 'bg-[#121214] border-white/5 hover:border-white/10'
          ]"
        >
          <!-- Left: Checkbox + Info -->
          <div class="flex items-center gap-3.5 flex-1 min-w-0">
            <!-- Checkbox -->
            <input
              type="checkbox"
              :checked="selectedIds.has(pkg.id)"
              :disabled="pkg.category === 'system' || !pkg.installed || isProcessing"
              @change="toggleSelection(pkg.id)"
              class="w-4 h-4 rounded border-gray-600 text-yellow-500 focus:ring-yellow-500/20 bg-neutral-800 disabled:opacity-30 disabled:cursor-not-allowed shrink-0 cursor-pointer"
            />

            <div class="flex flex-col gap-0.5 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-sm font-bold text-white truncate">{{ pkg.name }}</span>
                <span
                  class="px-1.5 py-0.2 rounded text-[10px] font-extrabold uppercase tracking-wider shrink-0"
                  :class="getCategoryBadgeClass(pkg.category)"
                >
                  {{ getCategoryLabel(pkg.category) }}
                </span>
                <span
                  v-if="pkg.backedUp"
                  class="px-1.5 py-0.2 rounded text-[10px] font-bold uppercase tracking-wider bg-yellow-500/20 text-yellow-300 border border-yellow-500/30 shrink-0"
                >
                  Respaldada
                </span>
              </div>
              <p class="text-xs text-gray-400 truncate">{{ pkg.description }}</p>
              <div class="flex items-center gap-3 text-[11px] text-gray-500 font-mono mt-0.5">
                <span class="truncate">{{ pkg.id }}</span>
                <span v-if="pkg.version">• v{{ pkg.version }}</span>
              </div>
            </div>
          </div>

          <!-- Right: Status / Restore Action -->
          <div class="flex items-center gap-3 shrink-0">
            <span
              v-if="pkg.installed"
              class="flex items-center gap-1.5 text-xs font-semibold text-emerald-400"
            >
              <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
              Instalado
            </span>
            <span
              v-else
              class="flex items-center gap-1.5 text-xs font-semibold text-gray-500"
            >
              <span class="w-2 h-2 rounded-full bg-gray-600"></span>
              No presente
            </span>

            <button
              v-if="pkg.backedUp"
              @click="restoreSingle(pkg.id)"
              :disabled="isProcessing"
              class="px-2.5 py-1 rounded-lg text-xs bg-yellow-500/10 hover:bg-yellow-500/20 text-yellow-300 border border-yellow-500/30 font-semibold transition-colors disabled:opacity-50 flex items-center gap-1"
              title="Restaurar esta app desde la copia de seguridad"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              Restaurar
            </button>
          </div>
        </div>
      </div>

      <!-- Modal Footer -->
      <div class="px-6 py-4 border-t border-white/10 bg-black/60 flex flex-col sm:flex-row items-center justify-between gap-3">
        <div class="text-xs text-gray-400">
          <span v-if="selectedCount === 0">Selecciona aplicaciones para desinstalar.</span>
          <span v-else>
            Se desinstalarán <b class="text-white">{{ selectedCount }}</b> aplicaciones seleccionadas.
          </span>
        </div>

        <div class="flex items-center gap-3 w-full sm:w-auto">
          <button
            @click="store.closeAppxModal"
            class="flex-1 sm:flex-none px-4 py-2 rounded-xl text-xs font-bold text-gray-400 hover:text-white hover:bg-white/5 border border-white/5 transition-colors"
          >
            Cancelar
          </button>
          <button
            @click="removeSelected"
            :disabled="selectedCount === 0 || isProcessing"
            class="flex-1 sm:flex-none px-5 py-2 rounded-xl text-xs font-bold bg-red-500/20 hover:bg-red-500/30 text-red-300 border border-red-500/40 transition-all flex items-center justify-center gap-2 shadow-[0_0_20px_rgba(239,68,68,0.2)] disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <svg v-if="isProcessing" class="w-3.5 h-3.5 animate-spin" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <svg v-else class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
            <span>Desinstalar Seleccionadas ({{ selectedCount }})</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from "vue";
import { invoke } from "@tauri-apps/api/core";
import Swal from "sweetalert2";
import { overlordSwalConfig } from "../utils/swalConfig";
import { useOverlordStore } from "../stores/overlordStore";

export interface AppxPackageItem {
  id: string;
  name: string;
  category: "safe" | "caution" | "system";
  description: string;
  installed: boolean;
  provisioned: boolean;
  backedUp: boolean;
  version: string;
  packageFullName: string;
  installLocation: string;
}

const store = useOverlordStore();

const packages = ref<AppxPackageItem[]>([]);
const selectedIds = ref<Set<string>>(new Set());
const searchQuery = ref("");
const activeTab = ref<"all" | "safe" | "caution" | "system">("all");
const isLoading = ref(false);
const isProcessing = ref(false);

const tabs = computed(() => [
  { id: "all" as const, label: "Todos", count: packages.value.length },
  { id: "safe" as const, label: "Seguros", count: packages.value.filter((p) => p.category === "safe").length },
  { id: "caution" as const, label: "Precaución", count: packages.value.filter((p) => p.category === "caution").length },
  { id: "system" as const, label: "Protegidos", count: packages.value.filter((p) => p.category === "system").length },
]);

const selectedCount = computed(() => selectedIds.value.size);
const backedUpCount = computed(() => packages.value.filter((p) => p.backedUp).length);

const filteredPackages = computed(() => {
  return packages.value.filter((pkg) => {
    // Tab filter
    if (activeTab.value !== "all" && pkg.category !== activeTab.value) {
      return false;
    }
    // Search query
    if (searchQuery.value.trim()) {
      const q = searchQuery.value.toLowerCase().trim();
      const matchName = pkg.name.toLowerCase().includes(q);
      const matchId = pkg.id.toLowerCase().includes(q);
      const matchDesc = pkg.description.toLowerCase().includes(q);
      if (!matchName && !matchId && !matchDesc) {
        return false;
      }
    }
    return true;
  });
});

async function fetchPackages() {
  isLoading.value = true;
  try {
    const raw = await invoke<string>("run_optimization_script", {
      scriptName: "manage_appx",
      isLaptop: store.hardwareInfo.isLaptop,
      ramGb: store.hardwareInfo.ramGb || 8,
      gameList: "list",
    });
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      packages.value = parsed as AppxPackageItem[];
    }
  } catch (e) {
    console.error("[CRITICAL APPX SCAN ERROR]:", e);
    invoke("log_from_js", {
      msg: `[CRITICAL APPX SCAN ERROR]: ${String(e)}`,
    }).catch(() => {});
  } finally {
    isLoading.value = false;
  }
}

watch(
  () => store.isAppxModalOpen,
  (isOpen) => {
    if (isOpen) {
      fetchPackages();
    } else {
      selectedIds.value.clear();
      searchQuery.value = "";
    }
  }
);

onMounted(() => {
  if (store.isAppxModalOpen) {
    fetchPackages();
  }
});

function toggleSelection(id: string) {
  if (selectedIds.value.has(id)) {
    selectedIds.value.delete(id);
  } else {
    selectedIds.value.add(id);
  }
}

function selectSafeOnly() {
  selectedIds.value.clear();
  for (const pkg of packages.value) {
    if (pkg.category === "safe" && pkg.installed) {
      selectedIds.value.add(pkg.id);
    }
  }
}

function deselectAll() {
  selectedIds.value.clear();
}

function getCategoryBadgeClass(category: string) {
  switch (category) {
    case "safe":
      return "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30";
    case "caution":
      return "bg-amber-500/20 text-amber-400 border border-amber-500/30";
    case "system":
      return "bg-blue-500/20 text-blue-400 border border-blue-500/30";
    default:
      return "bg-gray-500/20 text-gray-400 border border-gray-500/30";
  }
}

function getCategoryLabel(category: string) {
  switch (category) {
    case "safe":
      return "Seguro";
    case "caution":
      return "Precaución";
    case "system":
      return "Protegido";
    default:
      return category;
  }
}

async function removeSelected() {
  if (selectedIds.value.size === 0 || isProcessing.value) return;

  const count = selectedIds.value.size;
  const names = packages.value
    .filter((p) => selectedIds.value.has(p.id))
    .map((p) => p.name)
    .slice(0, 5)
    .join(", ");
  const extra = count > 5 ? ` y ${count - 5} más` : "";

  const confirm = await Swal.fire({
    title: "¿DESINSTALAR BLOATWARE APPX?",
    text: `Se desinstalarán ${count} aplicaciones (${names}${extra}). Se creará una copia de seguridad en el registro para permitir su restauración exacta en cualquier momento.`,
    icon: "warning",
    showCancelButton: true,
    confirmButtonText: "SÍ, DESINSTALAR",
    cancelButtonText: "CANCELAR",
    ...overlordSwalConfig,
  });

  if (!confirm.isConfirmed) return;

  isProcessing.value = true;
  store.setGlobalBusy(true);

  try {
    const listStr = Array.from(selectedIds.value).join(",");
    const resRaw = await invoke<string>("run_optimization_script", {
      scriptName: "manage_appx",
      isLaptop: store.hardwareInfo.isLaptop,
      ramGb: store.hardwareInfo.ramGb || 8,
      gameList: `remove:${listStr}`,
    });

    const parsed = JSON.parse(resRaw);
    const removedCount = parsed.removed?.length || 0;

    await Swal.fire({
      title: "PURGA COMPLETADA",
      text: `Se han desinstalado y respaldado exitosamente ${removedCount} aplicaciones del sistema.`,
      icon: "success",
      ...overlordSwalConfig,
    });

    selectedIds.value.clear();
    await fetchPackages();
  } catch (error) {
    console.error("[ERROR DESINSTALANDO APPX]:", error);
    await Swal.fire({
      title: "ERROR EN REMOCIÓN",
      text: `Fallo al desinstalar paquetes seleccionados: ${String(error)}`,
      icon: "error",
      ...overlordSwalConfig,
    });
  } finally {
    isProcessing.value = false;
    store.setGlobalBusy(false);
  }
}

async function restoreSingle(id: string) {
  if (isProcessing.value) return;
  const pkg = packages.value.find((p) => p.id === id);
  const pkgName = pkg ? pkg.name : id;

  const confirm = await Swal.fire({
    title: "¿RESTAURAR APLICACIÓN?",
    text: `¿Deseas restaurar ${pkgName} desde su copia de seguridad registrada en Overlord?`,
    icon: "question",
    showCancelButton: true,
    confirmButtonText: "SÍ, RESTAURAR",
    cancelButtonText: "CANCELAR",
    ...overlordSwalConfig,
  });

  if (!confirm.isConfirmed) return;

  isProcessing.value = true;
  store.setGlobalBusy(true);

  try {
    await invoke<string>("run_optimization_script", {
      scriptName: "manage_appx",
      isLaptop: store.hardwareInfo.isLaptop,
      ramGb: store.hardwareInfo.ramGb || 8,
      gameList: `restore:${id}`,
    });

    await Swal.fire({
      title: "RESTAURACIÓN EXITOSA",
      text: `${pkgName} ha sido restaurada en el sistema.`,
      icon: "success",
      ...overlordSwalConfig,
    });

    await fetchPackages();
  } catch (error) {
    console.error("[ERROR RESTAURANDO APPX]:", error);
    await Swal.fire({
      title: "ERROR AL RESTAURAR",
      text: `No se pudo restaurar la aplicación: ${String(error)}`,
      icon: "error",
      ...overlordSwalConfig,
    });
  } finally {
    isProcessing.value = false;
    store.setGlobalBusy(false);
  }
}

async function restoreAllBackedUp() {
  if (isProcessing.value || backedUpCount.value === 0) return;

  const count = backedUpCount.value;
  const confirm = await Swal.fire({
    title: "¿RESTAURAR TODAS LAS COPIAS?",
    text: `Se re-registrarán en Windows las ${count} aplicaciones respaldadas por Overlord en este equipo.`,
    icon: "question",
    showCancelButton: true,
    confirmButtonText: "SÍ, RESTAURAR TODAS",
    cancelButtonText: "CANCELAR",
    ...overlordSwalConfig,
  });

  if (!confirm.isConfirmed) return;

  isProcessing.value = true;
  store.setGlobalBusy(true);

  try {
    await invoke<string>("run_optimization_script", {
      scriptName: "manage_appx",
      isLaptop: store.hardwareInfo.isLaptop,
      ramGb: store.hardwareInfo.ramGb || 8,
      gameList: "restore:all",
    });

    await Swal.fire({
      title: "RESTAURACIÓN MASIVA EXITOSA",
      text: `Se han restaurado las aplicaciones respaldadas en el sistema.`,
      icon: "success",
      ...overlordSwalConfig,
    });

    await fetchPackages();
  } catch (error) {
    console.error("[ERROR RESTAURANDO TODAS LAS APPX]:", error);
    await Swal.fire({
      title: "ERROR EN RESTAURACIÓN",
      text: `Fallo al restaurar aplicaciones: ${String(error)}`,
      icon: "error",
      ...overlordSwalConfig,
    });
  } finally {
    isProcessing.value = false;
    store.setGlobalBusy(false);
  }
}
</script>
