<script setup lang="ts">
import { computed } from "vue";
import { useOverlordStore } from "../stores/overlordStore";
import { useBenchmark } from "../composables/useBenchmark";

const store = useOverlordStore();
const { isTesting, executeBenchmark } = useBenchmark();

const improvementNetwork = computed(() => {
  if (!store.benchmarks.before.measured || !store.benchmarks.after.measured)
    return null;
  const diff =
    store.benchmarks.before.networkLatency -
    store.benchmarks.after.networkLatency;
  const pct = (diff / store.benchmarks.before.networkLatency) * 100;
  return {
    ms: diff,
    percent: Math.max(0, Math.round(pct)),
    positive: diff > 0,
  };
});

const improvementDns = computed(() => {
  if (!store.benchmarks.before.measured || !store.benchmarks.after.measured)
    return null;
  const diff =
    store.benchmarks.before.dnsResolution -
    store.benchmarks.after.dnsResolution;
  const pct = (diff / store.benchmarks.before.dnsResolution) * 100;
  return {
    ms: diff,
    percent: Math.max(0, Math.round(pct)),
    positive: diff > 0,
  };
});
</script>

<template>
  <div
    class="bg-zinc-950 border border-zinc-800/80 rounded-xl p-6 shadow-2xl shadow-black/40 relative overflow-hidden"
  >
    <div
      class="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-transparent via-cyan-500/40 to-transparent"
    ></div>

    <div
      class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6"
    >
      <div>
        <h2
          class="text-md font-mono font-bold text-zinc-100 tracking-wider flex items-center gap-2"
        >
          <span
            class="h-2 w-2 rounded-full bg-cyan-500 animate-pulse shadow-lg shadow-cyan-500"
          ></span>
          OVERLORD CORE BENCHMARK
        </h2>
        <p class="text-[11px] text-zinc-400 mt-0.5 tracking-wide">
          Muestreo dinámico de latencia de red TCP e hilos de resolución de
          nombres.
        </p>
      </div>
      <div
        class="self-start sm:self-center px-3 py-1 text-[10px] font-mono font-bold uppercase rounded border border-zinc-700/60 bg-zinc-900 text-cyan-400 tracking-wider"
      >
        {{ store.hardwareInfo.tier }}
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
      <div
        class="p-5 rounded-lg bg-zinc-900/20 border border-zinc-800/60 flex flex-col justify-between transition-all duration-300 hover:border-zinc-700/50"
      >
        <div>
          <div
            class="text-[10px] font-mono font-bold text-zinc-500 uppercase tracking-widest mb-3 flex items-center gap-1.5"
          >
            <span class="w-1.5 h-1.5 rounded-full bg-zinc-600"></span>
            Módulo Pre-Optimización
          </div>
          <div
            v-if="store.benchmarks.before.measured"
            class="space-y-2.5 font-mono"
          >
            <div
              class="flex justify-between items-center bg-zinc-950/40 p-2 rounded border border-zinc-900"
            >
              <span class="text-xs text-zinc-400">Latencia TCP:</span>
              <span class="text-xs font-bold text-zinc-300"
                >{{ store.benchmarks.before.networkLatency }} ms</span
              >
            </div>
            <div
              class="flex justify-between items-center bg-zinc-950/40 p-2 rounded border border-zinc-900"
            >
              <span class="text-xs text-zinc-400">Resolución DNS:</span>
              <span class="text-xs font-bold text-zinc-300"
                >{{ store.benchmarks.before.dnsResolution }} ms</span
              >
            </div>
          </div>
          <div
            v-else
            class="text-xs font-mono text-zinc-500 italic py-4 tracking-wide"
          >
            Esperando captura inicial del entorno...
          </div>
        </div>
        <button
          @click="executeBenchmark('before')"
          :disabled="isTesting"
          class="mt-5 w-full py-2.5 px-4 bg-zinc-900 hover:bg-zinc-800 text-zinc-300 hover:text-white text-xs font-mono font-bold rounded border border-zinc-700/50 transition-all duration-200 disabled:opacity-40 active:scale-[0.99]"
        >
          {{ isTesting ? "EJECUTANDO..." : "ESCANEAR ENTORNO INICIAL" }}
        </button>
      </div>

      <div
        class="p-5 rounded-lg bg-zinc-900/20 border border-zinc-800/60 flex flex-col justify-between transition-all duration-300 hover:border-cyan-950/60"
      >
        <div>
          <div
            class="text-[10px] font-mono font-bold text-cyan-500 uppercase tracking-widest mb-3 flex items-center gap-1.5"
          >
            <span
              class="w-1.5 h-1.5 rounded-full bg-cyan-500 shadow-sm shadow-cyan-500"
            ></span>
            Entorno Núcleo Saneado
          </div>
          <div
            v-if="store.benchmarks.after.measured"
            class="space-y-2.5 font-mono"
          >
            <div
              class="flex justify-between items-center bg-zinc-950/40 p-2 rounded border border-cyan-950/30"
            >
              <span class="text-xs text-zinc-400">Latencia TCP:</span>
              <span class="text-xs font-bold text-cyan-400"
                >{{ store.benchmarks.after.networkLatency }} ms</span
              >
            </div>
            <div
              class="flex justify-between items-center bg-zinc-950/40 p-2 rounded border border-cyan-950/30"
            >
              <span class="text-xs text-zinc-400">Resolución DNS:</span>
              <span class="text-xs font-bold text-cyan-400"
                >{{ store.benchmarks.after.dnsResolution }} ms</span
              >
            </div>
          </div>
          <div
            v-else
            class="text-xs font-mono text-zinc-500 italic py-4 tracking-wide"
          >
            Pendiente de ejecucion post-inyeccion...
          </div>
        </div>
        <button
          @click="executeBenchmark('after')"
          :disabled="isTesting"
          class="mt-5 w-full py-2.5 px-4 bg-cyan-950/30 hover:bg-cyan-900/50 text-cyan-400 hover:text-cyan-300 text-xs font-mono font-bold rounded border border-cyan-800/60 transition-all duration-200 disabled:opacity-40 active:scale-[0.99] shadow-sm shadow-cyan-950"
        >
          {{ isTesting ? "EJECUTANDO..." : "ESCANEAR ENTORNO OPTIMIZADO" }}
        </button>
      </div>
    </div>

    <div
      v-if="improvementNetwork || improvementDns"
      class="p-4 rounded-lg bg-zinc-900/40 border border-zinc-800/60 grid grid-cols-1 md:grid-cols-2 gap-4 font-mono relative"
    >
      <div
        class="flex items-center gap-3 p-2 rounded bg-zinc-950/40 border border-zinc-900"
      >
        <div
          class="p-2 rounded bg-cyan-950/40 text-cyan-400 border border-cyan-900/60"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 10V3L4 14h7v7l9-11h-7z"
            />
          </svg>
        </div>
        <div>
          <div class="text-[9px] text-zinc-500 uppercase tracking-wider">
            Delta Respuesta TCP
          </div>
          <div
            class="text-xs font-bold tracking-tight"
            :class="
              improvementNetwork?.positive
                ? 'text-emerald-400'
                : 'text-zinc-400'
            "
          >
            {{
              improvementNetwork?.positive
                ? `+ ${improvementNetwork.percent}% Velocidad`
                : "Estable / Sin Variacion"
            }}
          </div>
        </div>
      </div>

      <div
        class="flex items-center gap-3 p-2 rounded bg-zinc-950/40 border border-zinc-900"
      >
        <div
          class="p-2 rounded bg-cyan-950/40 text-cyan-400 border border-cyan-900/60"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
        </div>
        <div>
          <div class="text-[9px] text-zinc-500 uppercase tracking-wider">
            Delta Consultas DNS
          </div>
          <div
            class="text-xs font-bold tracking-tight"
            :class="
              improvementDns?.positive ? 'text-emerald-400' : 'text-zinc-400'
            "
          >
            {{
              improvementDns?.positive
                ? `+ ${improvementDns.percent}% Respuesta`
                : "Estable / Sin Variacion"
            }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
