<template>
  <div
    class="bg-[#0a0a0a]/60 backdrop-blur-md border border-white/5 rounded-2xl p-6 flex flex-col justify-between gap-5 relative hover:border-white/10 transition-colors group"
  >
    <div class="flex flex-col gap-3">
      <div class="flex justify-between items-start gap-4">
        <h3 class="text-xl font-bold text-white tracking-wide leading-tight">
          {{ meta.title }}
        </h3>
        <div class="flex items-center gap-2 shrink-0">
          <button
            @click="toggleDoc"
            class="p-1.5 rounded-lg bg-white/5 text-gray-400 hover:bg-white/10 hover:text-white transition-colors"
            title="Ver Detalles Técnicos"
          >
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
                d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
              ></path>
            </svg>
          </button>
          <span
            class="px-2.5 py-1 rounded-md text-xs font-black uppercase tracking-wider"
            :class="badgeClass"
          >
            {{ meta.riesgo }}
          </span>
        </div>
      </div>

      <p class="text-gray-400 text-sm leading-relaxed">
        {{ meta.description }}
      </p>

      <div
        v-if="showDoc"
        class="mt-2 p-4 bg-white/[0.02] border border-white/5 rounded-xl flex flex-col gap-3 text-xs font-mono text-gray-400"
      >
        <div>
          <span class="text-blue-400 font-bold">IMPACTO REAL:</span>
          <span class="text-gray-300"> {{ meta.impactoRendimiento }}</span>
        </div>
        <div>
          <span class="text-yellow-500 font-bold">REVERSIÓN EXACTA:</span>
          <span class="text-gray-300"> {{ meta.metodoReversion }}</span>
        </div>
        <div>
          <span class="text-emerald-400 font-bold">HARDWARE RECOMENDADO:</span>
          <span class="text-gray-300"> {{ meta.hardwareRecomendado }}</span>
        </div>
        <div>
          <span class="text-purple-400 font-bold">COMPATIBILIDAD:</span>
          <span class="text-gray-300"> {{ meta.windowsVersion }}</span>
        </div>
        <a
          :href="meta.fuenteOficial"
          target="_blank"
          class="text-yellow-500/70 hover:text-yellow-400 underline truncate block mt-1 font-sans"
        >
          Documentación Oficial de Microsoft →
        </a>
      </div>

      <ul class="flex flex-col gap-2 mt-2">
        <li
          v-for="(detail, i) in meta.details"
          :key="i"
          class="flex items-center gap-2 text-xs font-medium text-gray-300"
        >
          <svg
            class="w-3.5 h-3.5 text-yellow-500 shrink-0"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="3"
              d="M5 13l4 4L19 7"
            ></path>
          </svg>
          <span>{{ detail }}</span>
        </li>
      </ul>

      <slot></slot>
    </div>

    <div
      class="flex justify-between items-center border-t border-white/5 pt-4 mt-2"
    >
      <span class="text-xs font-mono text-gray-500 uppercase tracking-widest">
        {{ statusText }}
      </span>
      <label class="relative inline-flex items-center cursor-pointer">
        <input
          type="checkbox"
          :checked="modelValue"
          @change="handleToggleAttempt"
          :disabled="status === 'loading'"
          class="sr-only peer"
        />
        <div
          class="w-10 h-5 bg-neutral-800 rounded-full peer peer-checked:after:translate-x-5 peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-gray-400 after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-yellow-500 peer-checked:after:bg-black"
        ></div>
      </label>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { tweaksMetadata } from "../data/tweaksMetadata";

const props = defineProps<{
  id: string;
  modelValue: boolean;
  status: "idle" | "loading" | "success" | "error";
}>();

const emit = defineEmits<{
  (e: "update:modelValue", value: boolean): void;
  (e: "request-warning", payload: { id: string; warningText: string }): void;
}>();

const showDoc = ref(false);

const meta = computed(() => tweaksMetadata[props.id]);

const toggleDoc = () => {
  showDoc.value = !showDoc.value;
};

const handleToggleAttempt = (e: Event) => {
  const target = e.target as HTMLInputElement;
  const isChecking = target.checked;

  if (meta.value.warning && isChecking) {
    target.checked = false;

    emit("request-warning", {
      id: props.id,
      warningText: meta.value.warning,
    });
  } else {
    emit("update:modelValue", isChecking);
  }
};

const badgeClass = computed(() => {
  switch (meta.value.riesgo) {
    case "Seguro":
      return "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20";
    case "Balanceado":
      return "bg-blue-500/10 text-blue-400 border border-blue-500/20";
    case "Experimental":
      return "bg-red-500/10 text-red-400 border border-red-500/20";
    default:
      return "bg-white/5 text-gray-400";
  }
});

const statusText = computed(() => {
  switch (props.status) {
    case "loading":
      return "Inyectando...";
    case "success":
      return "Optimizado Al 100%";
    case "error":
      return "Fallo";
    default:
      return "No Optimizado";
  }
});
</script>
