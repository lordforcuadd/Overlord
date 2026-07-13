<template>
  <div class="mt-12 bg-gradient-to-r from-red-500/5 to-orange-500/5 border border-red-500/20 rounded-2xl p-6 lg:p-8 relative overflow-hidden mb-12">
    <div class="absolute top-0 right-0 w-64 h-64 bg-red-500/10 blur-[100px] rounded-full pointer-events-none"></div>

    <div class="flex flex-col lg:flex-row gap-8 items-start lg:items-center justify-between relative z-10">
      <div class="flex-1">
        <div class="flex items-center gap-3 mb-3">
          <div class="w-10 h-10 rounded-lg bg-red-500/10 flex items-center justify-center border border-red-500/20 text-red-500">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
            </svg>
          </div>
          <h2 class="text-2xl font-black tracking-tight text-white uppercase">Central de Restauracion</h2>
        </div>
        <p class="text-gray-400 text-sm leading-relaxed max-w-2xl">
          El nucleo de Overlord esta disenado para ser seguro, pero puedes forzar la creacion de puntos de restauracion nativos de Windows, o revertir todos los cambios y volver al estado original de fabrica.
        </p>
      </div>

      <div class="flex flex-col sm:flex-row gap-4 w-full lg:w-auto shrink-0">
        <button
          @click="crearRespaldo"
          :disabled="isBackingUp || store.isGlobalBusy"
          class="flex items-center justify-center gap-2 px-6 py-4 bg-zinc-800 hover:bg-zinc-700 text-gray-200 font-bold rounded-xl transition-all disabled:opacity-50 border border-zinc-700"
        >
          <svg v-if="!isBackingUp" xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path><polyline points="17 21 17 13 7 13 7 21"></polyline><polyline points="7 3 7 8 15 8"></polyline></svg>
          <svg v-else class="animate-spin w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          {{ isBackingUp ? "CREANDO..." : "CREAR PUNTO DE RESPALDO" }}
        </button>

        <button
          @click="confirmarReversion"
          :disabled="isReverting || store.isGlobalBusy"
          class="flex items-center justify-center gap-2 px-6 py-4 bg-red-500 hover:bg-red-400 text-black font-black rounded-xl transition-all disabled:opacity-50 shadow-[0_0_20px_rgba(239,68,68,0.3)]"
        >
          <svg v-if="!isReverting" xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"></path><path d="M3 3v5h5"></path></svg>
          <svg v-else class="animate-spin w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          {{ isReverting ? "RESTAURANDO..." : "RESTAURAR A FABRICA" }}
        </button>
      </div>
    </div>

    <WarningModal
      :isOpen="warningModalOpen"
      :message="warningMessage"
      @confirm="ejecutarReversion"
      @cancel="warningModalOpen = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, inject } from "vue";
import { useOverlordStore } from "../stores/overlordStore";
import { useOrchestrator } from "../composables/useOrchestrator";
import WarningModal from "./WarningModal.vue";

const store = useOverlordStore();
const swalConfig = inject("swalConfig") || {};
const { isBackingUp, isReverting, crearRespaldo, revertirStock } = useOrchestrator(swalConfig);

const warningModalOpen = ref(false);
const warningMessage = ref(
  "Estas a punto de revertir TODOS los cambios realizados por Overlord. Esto restaurara el estado del Kernel, la telemetria, y las mitigaciones a la configuracion original de Windows de forma permanente.<br><br><b>¿Estas completamente seguro de que deseas desarmar Overlord?</b>"
);

function confirmarReversion() {
  warningModalOpen.value = true;
}

async function ejecutarReversion() {
  warningModalOpen.value = false;
  await revertirStock();
}
</script>
