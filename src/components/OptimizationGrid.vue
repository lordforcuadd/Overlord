<template>
  <main
    class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8 mb-32"
  >
    <ModuleCard
      v-for="(_, tweakId) in tweaksMetadata"
      :key="tweakId"
      :id="tweakId"
      :modelValue="store.modules[tweakId as keyof typeof store.modules]"
      :status="cardStatus[tweakId] || 'idle'"
      @update:modelValue="handleModuleUpdate(tweakId, $event)"
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
                v-model="game.optimize"
                :disabled="!game.detected"
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
import { useOverlordStore } from "../stores/overlordStore";
import { tweaksMetadata } from "../data/tweaksMetadata";
import ModuleCard from "./ModuleCard.vue";

defineProps<{
  cardStatus: Record<string, "idle" | "loading" | "success" | "error">;
}>();

const emit = defineEmits<{
  (e: "trigger-warning", payload: { key: string; message: string }): void;
}>();

const store = useOverlordStore();

const handleModuleUpdate = (tweakId: string, newValue: boolean) => {
  store.activeProfile = "Personalizado";
  store.modules[tweakId as keyof typeof store.modules] = newValue;
};

const handleWarningRequest = (payload: { id: string; warningText: string }) => {
  store.activeProfile = "Personalizado";

  emit("trigger-warning", {
    key: payload.id,
    message: payload.warningText,
  });
};
</script>
