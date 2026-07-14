<template>
  <main
    class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8 mb-32"
  >
    <ModuleCard
      v-for="(_, tweakId) in tweaksMetadata"
      :key="tweakId"
      :id="tweakId as string"
      :modelValue="getModuleValue(tweakId)"
      :status="cardStatus[tweakId as string] || 'idle'"
      @update:modelValue="handleModuleUpdate(tweakId as string, $event)"
      @request-warning="handleWarningRequest"
    >
      <template v-if="tweakId === 'gameHooks'">
        <div
          class="flex flex-col gap-3 mt-4 bg-[#0a0a0a] p-4 rounded-xl border border-white/10"
        >
          <!-- Contenedor scrollable para la lista de juegos -->
          <div class="flex flex-col gap-2.5 max-h-48 overflow-y-auto pr-1">
            <div
              v-for="(game, index) in store.gameList"
              :key="index"
              class="flex items-center justify-between"
            >
              <span
                class="text-xs font-mono font-medium truncate pr-2"
                :class="game.detected ? (game.manual ? 'text-orange-400' : 'text-yellow-400') : 'text-gray-600'"
                :title="game.name + ' (' + game.exe + ')'"
              >
                {{ game.name }}
              </span>
              <div class="flex items-center gap-2">
                <button
                  v-if="game.manual"
                  @click="store.removeManualGame(index)"
                  class="text-red-500 hover:text-red-400 text-xs font-extrabold px-1 transition-colors focus:outline-none"
                  title="Eliminar juego manual"
                >
                  ✕
                </button>
                <label class="relative inline-flex items-center cursor-pointer shrink-0">
                  <input
                    type="checkbox"
                    :checked="game.optimize"
                    @change="store.toggleGameOptimization(index, ($event.target as HTMLInputElement).checked)"
                    :disabled="!game.detected"
                    class="sr-only peer"
                  />
                  <div
                    class="w-8 h-4 bg-neutral-700 rounded-full peer peer-checked:after:translate-x-4 peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:bg-yellow-500"
                  ></div>
                </label>
              </div>
            </div>
          </div>
          
          <!-- Agregar juego manual -->
          <div class="flex flex-col gap-2 p-1 border-t border-white/5 pt-3 mt-1">
            <span class="text-[9px] font-bold text-gray-500 uppercase tracking-widest">Añadir Juego Manual</span>
            <div class="flex flex-col gap-2">
              <input 
                v-model="manualGameName"
                placeholder="Nombre (ej. Minecraft)"
                class="w-full bg-[#121212] border border-white/10 rounded-lg px-2.5 py-1.5 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-yellow-500/50"
              />
              <input 
                v-model="manualGameExe"
                placeholder="Ejecutable (ej. javaw.exe)"
                class="w-full bg-[#121212] border border-white/10 rounded-lg px-2.5 py-1.5 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-yellow-500/50"
              />
              <button 
                @click="addManualGame"
                class="w-full bg-yellow-500/10 hover:bg-yellow-500/20 text-yellow-500 hover:text-yellow-400 font-bold py-2 rounded-lg text-xs transition-colors"
              >
                Añadir Juego
              </button>
            </div>
          </div>

          <hr class="border-white/5 my-1" />
          
          <div class="flex items-center justify-between mt-1 pt-1">
            <div class="flex flex-col pr-2">
              <span class="text-xs font-bold text-gray-300">Servicio de Fondo</span>
              <span class="text-[10px] text-gray-500 mt-0.5 leading-tight">Mantener prioridad alta sin la app abierta</span>
            </div>
            <label class="relative inline-flex items-center cursor-pointer shrink-0">
              <input
                type="checkbox"
                :checked="store.priorityServiceSelected"
                @change="handleServiceToggle($event)"
                :disabled="isServiceLoading"
                class="sr-only peer"
              />
              <div
                class="w-8 h-4 bg-neutral-700 rounded-full peer peer-checked:after:translate-x-4 peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:bg-yellow-500"
              ></div>
            </label>
          </div>
        </div>
      </template>
    </ModuleCard>
  </main>
</template>

<script setup lang="ts">
import { ref } from "vue";
import Swal from "sweetalert2";
import { overlordSwalConfig } from "../utils/swalConfig";
import { useOverlordStore } from "../stores/overlordStore";
import { tweaksMetadata } from "../data/tweaksMetadata";
import ModuleCard from "./ModuleCard.vue";

const props = defineProps<{
  cardStatus: Record<string, "idle" | "loading" | "success" | "error">;
}>();

const emit = defineEmits<{
  (e: "trigger-warning", payload: { key: string; message: string }): void;
}>();

const store = useOverlordStore();
const isServiceLoading = ref(false);
const manualGameName = ref("");
const manualGameExe = ref("");

function addManualGame() {
  const name = manualGameName.value.trim();
  const exe = manualGameExe.value.trim();
  if (!name || !exe) {
    Swal.fire({
      title: "Campos Incompletos",
      text: "Por favor, especifica el nombre del juego y el archivo ejecutable.",
      icon: "warning",
      ...overlordSwalConfig,
    });
    return;
  }

  const exeRegex = /^[^\\/:*?"<>|\s]+\.exe$/i;
  if (!exeRegex.test(exe)) {
    Swal.fire({
      title: "Ejecutable Inválido",
      text: "El nombre del ejecutable debe terminar en '.exe' y no contener espacios ni caracteres no válidos de Windows (\\ / : * ? \" < > |).",
      icon: "error",
      ...overlordSwalConfig,
    });
    return;
  }

  store.addManualGame(name, exe);
  manualGameName.value = "";
  manualGameExe.value = "";
}



const getModuleValue = (id: string | number | symbol) => {
  return store.modules[id as keyof typeof store.modules];
};

const handleModuleUpdate = (tweakId: string, newValue: boolean) => {
  store.updateModule(tweakId, newValue);
};

const handleWarningRequest = (payload: { id: string; warningText: string }) => {
  emit("trigger-warning", {
    key: payload.id,
    message: payload.warningText,
  });
};

const handleServiceToggle = async (event: Event) => {
  if (isServiceLoading.value) return;

  const target = event.target as HTMLInputElement;
  const isChecked = target.checked;

  if (isChecked && props.cardStatus['gameHooks'] !== 'success') {
    // Revertir el estado visual en el input inmediatamente
    target.checked = !isChecked;
    
    await Swal.fire({
      title: "Módulo Requerido",
      text: "Para activar el Servicio de Fondo, primero debes aplicar con éxito el módulo de 'Game Hooks'.",
      icon: "warning",
      ...overlordSwalConfig,
    });
    return;
  }

    if (isChecked) {
      const confirm = await Swal.fire({
        title: "¿Instalar Servicio de Fondo?",
        html: "<p>Esta acción instalará un <b>proceso persistente</b> (Daemon) en Windows que seguirá ejecutándose incluso después de cerrar Overlord.</p><p class='mt-2'>Su función es monitorear e inyectar prioridad alta a los juegos en tiempo real de forma autónoma.</p>",
        icon: "warning",
        showCancelButton: true,
        confirmButtonText: "Sí, instalar e iniciar",
        cancelButtonText: "Cancelar",
        ...overlordSwalConfig,
      });

      if (!confirm.isConfirmed) {
        target.checked = false;
        return;
      }
    }

    isServiceLoading.value = true;
    try {
      await store.togglePriorityService(isChecked);
  } catch (err) {
    console.error("Fallo al alternar el servicio de prioridades:", err);
    // Revertir el estado visual en caso de error
    target.checked = !isChecked;
    await Swal.fire({
      title: "Error de Servicio",
      text: "No se pudo alternar el Servicio de Fondo en el sistema.",
      icon: "error",
      ...overlordSwalConfig,
    });
  } finally {
    isServiceLoading.value = false;
  }
};
</script>


