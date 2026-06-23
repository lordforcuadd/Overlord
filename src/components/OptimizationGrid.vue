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
          <div
            v-for="(game, index) in store.gameList"
            :key="index"
            class="flex items-center justify-between"
          >
            <span
              class="text-xs font-mono font-medium"
              :class="game.detected ? 'text-yellow-400' : 'text-gray-600'"
            >
              {{ game.name }}
            </span>
            <label class="relative inline-flex items-center cursor-pointer">
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

          <hr class="border-white/5 my-1" />
          
          <div class="flex items-center justify-between mt-1 pt-1">
            <div class="flex flex-col pr-2">
              <span class="text-xs font-bold text-gray-300">Servicio de Fondo</span>
              <span class="text-[10px] text-gray-500 mt-0.5 leading-tight">Mantener prioridad alta sin la app abierta</span>
            </div>
            <label class="relative inline-flex items-center cursor-pointer shrink-0">
              <input
                type="checkbox"
                v-model="store.priorityServiceSelected"
                @change="handleServiceToggle"
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

const handleServiceToggle = async () => {
  if (isServiceLoading.value) return;
  isServiceLoading.value = true;
  
  try {
    const checked = store.priorityServiceSelected;
    if (props.cardStatus['gameHooks'] === 'success') {
      await store.togglePriorityService(checked);
    }
  } catch (err) {
    console.error("Fallo al alternar el servicio de prioridades:", err);
  } finally {
    isServiceLoading.value = false;
  }
};
</script>
