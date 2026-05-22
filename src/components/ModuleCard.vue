<template>
  <div
    class="flex flex-col h-full rounded-2xl border p-5 transition-all duration-300 relative overflow-hidden group"
    :class="
      modelValue
        ? 'border-yellow-500/40 bg-[#121212] shadow-[0_4px_20px_rgba(250,204,21,0.05)]'
        : 'border-neutral-800 bg-[#0a0a0a]/80 hover:bg-[#121212] hover:border-neutral-700 hover:-translate-y-1'
    "
  >
    <div
      class="absolute top-0 left-0 w-1 h-full transition-all duration-300"
      :class="
        modelValue
          ? 'bg-yellow-500 shadow-[0_0_15px_rgba(250,204,21,0.5)]'
          : 'bg-transparent'
      "
    ></div>

    <div class="flex-grow pl-3 flex flex-col">
      <div class="flex justify-between items-start gap-4 pr-1">
        <h3
          class="text-lg font-bold leading-tight transition-colors duration-300"
          :class="
            modelValue
              ? 'text-yellow-400'
              : 'text-gray-200 group-hover:text-yellow-400'
          "
        >
          {{ title }}
        </h3>

        <button
          @click="$emit('update:modelValue', !modelValue)"
          :class="modelValue ? 'bg-yellow-500' : 'bg-neutral-700'"
          class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none"
        >
          <span
            :class="modelValue ? 'translate-x-5' : 'translate-x-0'"
            class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
          ></span>
        </button>
      </div>

      <p class="text-xs md:text-sm text-gray-400 mt-2.5 leading-relaxed">
        {{ description }}
      </p>

      <div class="mt-3" v-if="$slots.default">
        <slot></slot>
      </div>

      <details class="mt-4 group/details">
        <summary
          class="text-xs text-yellow-500 font-semibold cursor-pointer select-none hover:text-yellow-400 transition-colors list-none flex items-center gap-1.5 outline-none"
        >
          <svg
            class="w-3.5 h-3.5 transition-transform duration-200 group-open/details:rotate-90"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 5l7 7-7 7"
            ></path>
          </svg>
          Ver Mas
        </summary>
        <ul class="mt-3 pl-4 border-l border-white/10 flex flex-col gap-1.5">
          <li
            v-for="(detail, index) in details"
            :key="index"
            class="text-[11px] md:text-xs text-gray-400 font-mono"
          >
            <span class="text-yellow-600/80 mr-1.5">-></span>{{ detail }}
          </li>
        </ul>
      </details>
    </div>

    <div class="mt-auto pt-6 flex justify-end items-center pl-3">
      <span
        v-if="status === 'loading'"
        class="text-xs font-bold text-yellow-400 bg-yellow-500/10 border border-yellow-500/20 px-3 py-1.5 rounded-full flex items-center gap-1.5"
      >
        <svg
          class="animate-spin h-3.5 w-3.5 text-yellow-400"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
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
        Aplicando...
      </span>

      <span
        v-else-if="status === 'error'"
        class="text-xs font-bold text-red-400 bg-red-500/10 border border-red-500/20 px-3 py-1.5 rounded-full flex items-center gap-1.5"
      >
        <svg
          class="w-3.5 h-3.5"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M6 18L18 6M6 6l12 12"
          ></path>
        </svg>
        Error
      </span>

      <span
        v-else-if="status === 'success'"
        class="text-xs font-bold text-green-400 bg-green-500/10 border border-green-500/20 px-3 py-1.5 rounded-full flex items-center gap-1.5"
      >
        <svg
          class="w-3.5 h-3.5"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M5 13l4 4L19 7"
          ></path>
        </svg>
        Optimizado
      </span>

      <span
        v-else
        class="text-xs font-medium text-gray-500 uppercase tracking-wider bg-neutral-800/50 px-3 py-1.5 rounded-full border border-neutral-700/50"
      >
        No Aplicado
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps({
  title: String,
  description: String,
  scriptName: String,
  details: {
    type: Array as () => string[],
    default: () => [],
  },
  modelValue: {
    type: Boolean,
    default: false,
  },
  status: {
    type: String as () => "idle" | "loading" | "success" | "error",
    default: "idle",
  },
});

defineEmits(["update:modelValue"]);
</script>
