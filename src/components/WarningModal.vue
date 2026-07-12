<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
  >
    <div
      class="bg-[#0a0a0a] border border-red-500/30 max-w-md w-full rounded-2xl p-6 shadow-[0_0_40px_rgba(239,68,68,0.15)] flex flex-col gap-4"
    >
      <div class="flex items-center gap-3 text-red-500">
        <svg
          class="w-8 h-8 shrink-0"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
          ></path>
        </svg>
        <h2 class="text-xl font-black tracking-tight uppercase text-white">
          Confirmación de Riesgo
        </h2>
      </div>

      <p
        class="text-gray-400 text-sm leading-relaxed"
        v-html="DOMPurify.sanitize(message)"
      ></p>

      <div class="flex gap-3 mt-2">
        <button
          @click="emit('cancel')"
          class="flex-1 py-3 bg-zinc-800 hover:bg-zinc-700 text-gray-300 font-bold rounded-xl transition-colors text-sm uppercase tracking-wider"
        >
          Cancelar
        </button>
        <button
          @click="emit('confirm')"
          class="flex-1 py-3 bg-red-500 hover:bg-red-400 text-black font-black rounded-xl transition-all text-sm uppercase tracking-widest shadow-[0_0_15px_rgba(239,68,68,0.3)]"
        >
          Confirmar
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import DOMPurify from "dompurify";

defineProps<{
  isOpen: boolean;
  message: string;
}>();

const emit = defineEmits(["confirm", "cancel"]);
</script>
