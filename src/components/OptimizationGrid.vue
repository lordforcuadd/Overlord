<template>
  <main
    class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8 mb-32"
  >
    <ModuleCard
      id="peripheralLatency"
      :modelValue="store.modules.peripheralLatency"
      @update:modelValue="handleToggle('peripheralLatency', $event, '')"
      :status="cardStatus.peripheralLatency || 'idle'"
    />

    <ModuleCard
      id="debloat"
      :modelValue="store.modules.debloat"
      @update:modelValue="handleToggle('debloat', $event, '')"
      :status="cardStatus.debloat || 'idle'"
    />

    <ModuleCard
      id="networkOptimized"
      :modelValue="store.modules.networkOptimized"
      @update:modelValue="handleToggle('networkOptimized', $event, '')"
      :status="cardStatus.networkOptimized || 'idle'"
    />

    <ModuleCard
      id="generalPerformance"
      :modelValue="store.modules.generalPerformance"
      @update:modelValue="
        handleToggle(
          'generalPerformance',
          $event,
          'Atención: Este ajuste desactiva los parches de mitigación Spectre y Meltdown del procesador para mitigar el input lag del Kernel. Esto incrementa el rendimiento entre un 1% y 3%, pero reduce la protección contra vulnerabilidades de aislamiento de memoria de la CPU.',
        )
      "
      :status="cardStatus.generalPerformance || 'idle'"
    />

    <ModuleCard
      id="gpuDisplay"
      :modelValue="store.modules.gpuDisplay"
      @update:modelValue="
        handleToggle(
          'gpuDisplay',
          $event,
          'Este tweak deshabilita el Multi-Plane Overlay (MPO) de Windows y altera las prioridades del DWM. Tu pantalla parpadeará momentáneamente durante la inyección.',
        )
      "
      :status="cardStatus.gpuDisplay || 'idle'"
    />

    <ModuleCard
      id="irqAffinity"
      :modelValue="store.modules.irqAffinity"
      @update:modelValue="
        handleToggle(
          'irqAffinity',
          $event,
          'Advertencia crítica de Kernel: Al reordenar las máscaras de afinidad de hardware de las interrupciones IRQ de red, estás enlazando controladores de red físicos a núcleos dedicados. Un error en la lectura del chipset de la placa base podría congelar el controlador de red hasta aplicar la reversión.',
        )
      "
      :status="cardStatus.irqAffinity || 'idle'"
    />

    <ModuleCard
      id="smartStorage"
      :modelValue="store.modules.smartStorage"
      @update:modelValue="handleToggle('smartStorage', $event, '')"
      :status="cardStatus.smartStorage || 'idle'"
    />

    <ModuleCard
      id="deepTelemetry"
      :modelValue="store.modules.deepTelemetry"
      @update:modelValue="
        handleToggle(
          'deepTelemetry',
          $event,
          'Advertencia de Seguridad Avanzada: Deshabilitar por completo la seguridad basada en virtualización (VBS) e integridad de código protegida por hipervisor (HVCI) incrementa drásticamente los FPS mínimos en juegos, pero anula por completo el aislamiento defensivo del Kernel de Windows 11 frente a exploits avanzados. Adicionalmente, sistemas antitrampas estrictos como Vanguard podrían exigir que estas opciones permanezcan encendidas en ciertos entornos.',
        )
      "
      :status="cardStatus.deepTelemetry || 'idle'"
    />

    <ModuleCard
      id="powerProfiles"
      :modelValue="store.modules.powerProfiles"
      @update:modelValue="handleToggle('powerProfiles', $event, '')"
      :status="cardStatus.powerProfiles || 'idle'"
    />

    <ModuleCard
      id="gameHooks"
      :modelValue="store.modules.gameHooks"
      @update:modelValue="
        handleToggle(
          'gameHooks',
          $event,
          'Alerta Máxima de Bloqueo Anti-Cheats: Modificar las llaves Image File Execution Options (IFEO) e inyectar prioridades forzadas a ejecutables competitivos como VALORANT-Win64-Shipping.exe o cs2.exe puede ser interpretado por ganchos de nivel de Kernel antitrampas (como Riot Vanguard, Easy Anti-Cheat o BattlEye) como un intento malicioso de manipulación o secuestro de memoria de proceso. Existe un riesgo latente de falsos positivos o penalizaciones automáticas en tu cuenta.',
        )
      "
      :status="cardStatus.gameHooks || 'idle'"
    >
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
    </ModuleCard>
  </main>
</template>

<script setup lang="ts">
import { useOverlordStore } from "../stores/overlordStore";
import ModuleCard from "./ModuleCard.vue";

defineProps<{
  cardStatus: Record<string, "idle" | "loading" | "success" | "error">;
}>();

const emit = defineEmits(["trigger-warning"]);
const store = useOverlordStore();

const handleToggle = (
  key: keyof typeof store.modules,
  value: boolean,
  warningMessage: string,
) => {
  store.activeProfile = "Personalizado";

  if (
    value &&
    (store.moduleSpecs[key].riesgo === "Avanzado" ||
      store.moduleSpecs[key].riesgo === "Kernel")
  ) {
    store.modules[key] = true;
    emit("trigger-warning", { key, message: warningMessage });
  } else {
    store.modules[key] = value;
  }
};
</script>
