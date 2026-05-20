<template>
  <div
    class="bg-[#16161657] border border-white/5 rounded-2xl p-6 relative overflow-hidden mb-10"
  >
    <div
      class="absolute top-0 right-0 w-64 h-64 bg-yellow-500/5 blur-[100px] rounded-full pointer-events-none"
    ></div>

    <div class="flex items-center gap-3 mb-6 relative z-10">
      <div
        class="w-8 h-8 rounded-lg bg-yellow-500/10 flex items-center justify-center border border-yellow-500/20"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-4 h-4 text-yellow-500"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path
            fill-rule="evenodd"
            d="M14.615 1.595a.75.75 0 01.359.852L12.982 9.75h7.268a.75.75 0 01.548 1.262l-10.5 11.25a.75.75 0 01-1.272-.71l1.992-7.302H3.75a.75.75 0 01-.548-1.262l10.5-11.25a.75.75 0 01.913-.143z"
            clip-rule="evenodd"
          />
        </svg>
      </div>
      <div>
        <h2 class="text-white font-bold tracking-wide uppercase text-sm">
          Acciones de Windows
        </h2>
        <p class="text-gray-500 text-xs">
          Acciones para mejorar y reparar windows
        </p>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 relative z-10">
      <button
        v-for="action in quickActions"
        :key="action.id"
        @click="runAction(action.id)"
        :disabled="isExecutingGlobal"
        :class="[
          'group relative flex items-start gap-4 p-4 rounded-xl border transition-all duration-300 text-left overflow-hidden',
          status[action.id] === 'success'
            ? 'bg-green-900/10 border-green-500/30'
            : status[action.id] === 'error'
              ? 'bg-red-900/10 border-red-500/30'
              : 'bg-[#1a1a1a] border-white/5 hover:border-yellow-500/30 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:border-white/5',
        ]"
      >
        <div
          :class="[
            'w-10 h-10 rounded-lg flex items-center justify-center shrink-0 transition-colors duration-300',
            status[action.id] === 'success'
              ? 'bg-green-500/20 text-green-400'
              : status[action.id] === 'error'
                ? 'bg-red-500/20 text-red-400'
                : status[action.id] === 'loading'
                  ? 'bg-yellow-500/10 text-yellow-500'
                  : 'bg-[#222] text-gray-400 group-hover:bg-yellow-500/10 group-hover:text-yellow-500',
          ]"
        >
          <svg
            v-if="status[action.id] === 'idle'"
            v-html="action.icon"
            class="w-5 h-5"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          ></svg>

          <svg
            v-else-if="status[action.id] === 'loading'"
            class="animate-spin w-5 h-5"
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

          <svg
            v-else-if="status[action.id] === 'success'"
            class="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M5 13l4 4L19 7"
            ></path>
          </svg>

          <svg
            v-else
            class="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M6 18L18 6M6 6l12 12"
            ></path>
          </svg>
        </div>

        <div>
          <h3
            :class="[
              'text-sm font-semibold transition-colors duration-300',
              status[action.id] === 'success'
                ? 'text-green-400'
                : status[action.id] === 'error'
                  ? 'text-red-400'
                  : status[action.id] === 'loading'
                    ? 'text-yellow-500'
                    : 'text-gray-200 group-hover:text-white',
            ]"
          >
            {{
              status[action.id] === "loading"
                ? "Ejecutando..."
                : status[action.id] === "success"
                  ? "¡Completado!"
                  : status[action.id] === "error"
                    ? "Falló la ejecución"
                    : action.title
            }}
          </h3>
          <p
            class="text-xs mt-1 leading-relaxed"
            :class="
              status[action.id] !== 'idle' ? 'text-gray-400' : 'text-gray-500'
            "
          >
            {{ action.desc }}
          </p>
        </div>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { resolveResource } from "@tauri-apps/api/path";

const isExecutingGlobal = ref(false);

const status = ref({
  PurgeRAM: "idle",
  DeepClean: "idle",
  RepairOS: "idle",
  FlushNet: "idle",
});

const quickActions = [
  {
    id: "PurgeRAM",
    title: "Purgar RAM",
    desc: "Aniquila el micro-stuttering liberando la memoria en espera.",
    icon: '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />',
  },
  {
    id: "DeepClean",
    title: "Limpieza Profunda",
    desc: "Fuerza el Sagerun para vaciar basura residual del sistema.",
    icon: '<path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />',
  },
  {
    id: "RepairOS",
    title: "Reparar Sistema",
    desc: "Ejecuta SFC y DISM. Útil contra pantallazos azules. (Puede demorar entre 15 a 20min)",
    icon: '<path stroke-linecap="round" stroke-linejoin="round" d="M11.42 15.17L17.25 21A2.652 2.652 0 0021 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 11-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 004.486-6.336l-3.276 3.277a3.004 3.004 0 01-2.25-2.25l3.276-3.276a4.5 4.5 0 00-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437l1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008z" />',
  },
  {
    id: "FlushNet",
    title: "Liberar Red (DNS)",
    desc: "Resetea Winsock y la caché DNS para reparar el Ping.",
    icon: '<path stroke-linecap="round" stroke-linejoin="round" d="M12.75 19.5v-.75a7.5 7.5 0 00-7.5-7.5H4.5m0-6.75h.75c7.87 0 14.25 6.38 14.25 14.25v.75M6 18.75a.75.75 0 11-1.5 0 .75.75 0 011.5 0z" />',
  },
];

const runAction = async (actionId) => {
  if (isExecutingGlobal.value || status.value[actionId] === "loading") return;

  isExecutingGlobal.value = true;
  status.value[actionId] = "loading";

  try {
    let rawPath = await resolveResource("scripts/quick_actions.ps1");
    let cleanPath = rawPath.replace(/^\\\\\\?\\\\/, "");

    const args = ["-Action", actionId];

    const response = await invoke("run_powershell_generic", {
      scriptPath: cleanPath,
      argsList: args,
    });

    console.log(`[Overlord Quick Action] ${actionId} ->`, response);
    status.value[actionId] = "success";
  } catch (error) {
    console.error(`[Overlord Error] Fallo en acción ${actionId}:`, error);
    status.value[actionId] = "error";
  } finally {
    isExecutingGlobal.value = false;
    setTimeout(() => {
      status.value[actionId] = "idle";
    }, 3500);
  }
};
</script>
