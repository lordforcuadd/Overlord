<script setup lang="ts">
import { computed } from "vue";
import { useOverlordStore } from "../stores/overlordStore";

const store = useOverlordStore();

const executeBenchmark = async (fase: "before" | "after") => {
  await store.ejecutarNetworkBenchmark(fase);
};

const improvementNetwork = computed(() => {
  if (!store.benchmarks.before.measured || !store.benchmarks.after.measured)
    return null;
  const diff =
    store.benchmarks.before.networkLatency -
    store.benchmarks.after.networkLatency;
  const pct =
    store.benchmarks.before.networkLatency > 0
      ? (diff / store.benchmarks.before.networkLatency) * 100
      : 0;
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
  const pct =
    store.benchmarks.before.dnsResolution > 0
      ? (diff / store.benchmarks.before.dnsResolution) * 100
      : 0;
  return {
    ms: diff,
    percent: Math.max(0, Math.round(pct)),
    positive: diff > 0,
  };
});

const maxNetworkValue = computed(() => {
  return Math.max(
    store.benchmarks.before.networkLatency,
    store.benchmarks.after.networkLatency,
    1,
  );
});

const maxDnsValue = computed(() => {
  return Math.max(
    store.benchmarks.before.dnsResolution,
    store.benchmarks.after.dnsResolution,
    1,
  );
});
</script>

<template>
  <div
    class="bg-zinc-950 border border-zinc-800/60 rounded-xl p-5 shadow-2xl shadow-black/80 relative overflow-hidden select-none"
  >
    <div
      class="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-cyan-500/60 to-transparent"
    ></div>

    <div
      class="flex items-center justify-between gap-4 border-b border-zinc-900 pb-4 mb-4"
    >
      <div class="flex items-center gap-3">
        <div class="relative flex h-2.5 w-2.5">
          <span
            class="animate-ping absolute inline-flex h-full w-full rounded-full bg-cyan-400 opacity-75"
          ></span>
          <span
            class="relative inline-flex rounded-full h-2.5 w-2.5 bg-cyan-500 shadow-md shadow-cyan-500/50"
          ></span>
        </div>
        <div>
          <h2
            class="text-xs font-mono font-black text-zinc-100 tracking-widest flex items-center gap-2"
          >
            OVERLORD NETWORK CORE
          </h2>
          <p
            class="text-[10px] font-mono text-zinc-500 mt-0.5 tracking-tight uppercase"
          >
            Muestreo dinamico de latencia TCP e hilos DNS
          </p>
        </div>
      </div>
      <div
        class="px-2.5 py-0.5 text-[9px] font-mono font-bold uppercase rounded border border-cyan-500/20 bg-cyan-950/20 text-cyan-400 tracking-widest"
      >
        {{ store.hardwareInfo.tier }}
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4">
      <div
        class="p-4 rounded-lg bg-zinc-900/10 border border-zinc-900 flex flex-col justify-between transition-all duration-300 hover:border-zinc-800"
      >
        <div>
          <div
            class="text-[9px] font-mono font-bold text-zinc-500 uppercase tracking-widest mb-3 flex items-center gap-2"
          >
            <svg
              class="h-3.5 w-3.5 text-zinc-600"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <circle cx="12" cy="12" r="10" />
              <polyline points="12 6 12 12 16 14" />
            </svg>
            Entorno Base Inicial
          </div>

          <div
            v-if="store.benchmarks.before.measured"
            class="space-y-3 font-mono"
          >
            <!-- Grafica Latencia TCP Base -->
            <div>
              <div class="flex justify-between items-center text-[11px] mb-1">
                <span class="text-zinc-400">Latencia TCP</span>
                <span class="text-zinc-300 font-bold"
                  >{{ store.benchmarks.before.networkLatency }} ms</span
                >
              </div>
              <div class="w-full bg-zinc-900 h-1 rounded-sm overflow-hidden">
                <div
                  class="bg-zinc-600 h-full transition-all duration-500"
                  :style="{
                    width: `${(store.benchmarks.before.networkLatency / maxNetworkValue) * 100}%`,
                  }"
                ></div>
              </div>
            </div>

            <div>
              <div class="flex justify-between items-center text-[11px] mb-1">
                <span class="text-zinc-400">Resolucion DNS</span>
                <span class="text-zinc-300 font-bold"
                  >{{ store.benchmarks.before.dnsResolution }} ms</span
                >
              </div>
              <div class="w-full bg-zinc-900 h-1 rounded-sm overflow-hidden">
                <div
                  class="bg-zinc-600 h-full transition-all duration-500"
                  :style="{
                    width: `${(store.benchmarks.before.dnsResolution / maxDnsValue) * 100}%`,
                  }"
                ></div>
              </div>
            </div>
          </div>

          <div
            v-else
            class="text-[11px] font-mono text-zinc-600 italic py-4 flex items-center gap-2 border border-dashed border-zinc-900 rounded p-2 justify-center bg-zinc-950/20"
          >
            Esperando telemetria de red...
          </div>
        </div>

        <button
          @click="executeBenchmark('before')"
          :disabled="store.isBenchmarkTesting"
          class="mt-4 w-full py-2 px-3 bg-zinc-900 hover:bg-zinc-800 text-zinc-400 hover:text-zinc-200 text-[10px] font-mono font-bold rounded border border-zinc-800 transition-all duration-150 disabled:opacity-40 active:scale-[0.98]"
        >
          {{ store.isBenchmarkTesting ? "ANALIZANDO..." : "CALIBRAR ENTORNO INICIAL" }}
        </button>
      </div>

      <div
        class="p-4 rounded-lg bg-cyan-950/5 border border-zinc-900 flex flex-col justify-between transition-all duration-300 hover:border-cyan-950/40 relative"
      >
        <div>
          <div
            class="text-[9px] font-mono font-bold text-cyan-500 uppercase tracking-widest mb-3 flex items-center gap-2"
          >
            <svg
              class="h-3.5 w-3.5 text-cyan-500 animate-pulse"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z"
              />
              <path d="m2 12 5-3 5 3 5-3 5 3" />
            </svg>
            Inyeccion Nucleo Saneado
          </div>

          <div
            v-if="store.benchmarks.after.measured"
            class="space-y-3 font-mono"
          >
            <div>
              <div class="flex justify-between items-center text-[11px] mb-1">
                <span class="text-zinc-400">Latencia TCP</span>
                <span class="text-cyan-400 font-bold flex items-center gap-1.5">
                  {{ store.benchmarks.after.networkLatency }} ms
                  <span
                    v-if="improvementNetwork?.positive"
                    class="text-[9px] text-emerald-400 bg-emerald-500/10 px-1 rounded"
                    >-{{ improvementNetwork.percent }}%</span
                  >
                </span>
              </div>
              <div class="w-full bg-zinc-900 h-1 rounded-sm overflow-hidden">
                <div
                  class="bg-gradient-to-r from-cyan-500 to-emerald-400 h-full transition-all duration-500 shadow-lg shadow-cyan-500/50"
                  :style="{
                    width: `${(store.benchmarks.after.networkLatency / maxNetworkValue) * 100}%`,
                  }"
                ></div>
              </div>
            </div>

            <div>
              <div class="flex justify-between items-center text-[11px] mb-1">
                <span class="text-zinc-400">Resolucion DNS</span>
                <span class="text-cyan-400 font-bold flex items-center gap-1.5">
                  {{ store.benchmarks.after.dnsResolution }} ms
                  <span
                    v-if="improvementDns?.positive"
                    class="text-[9px] text-emerald-400 bg-emerald-500/10 px-1 rounded"
                    >-{{ improvementDns.percent }}%</span
                  >
                </span>
              </div>
              <div class="w-full bg-zinc-900 h-1 rounded-sm overflow-hidden">
                <div
                  class="bg-gradient-to-r from-cyan-500 to-emerald-400 h-full transition-all duration-500 shadow-lg shadow-cyan-500/50"
                  :style="{
                    width: `${(store.benchmarks.after.dnsResolution / maxDnsValue) * 100}%`,
                  }"
                ></div>
              </div>
            </div>
          </div>

          <div
            v-else
            class="text-[11px] font-mono text-zinc-600 italic py-4 flex items-center gap-2 border border-dashed border-zinc-900 rounded p-2 justify-center bg-zinc-950/20"
          >
            {{ !store.benchmarks.before.measured ? "Requiere calibracion inicial..." : "Bloque de optimizacion inactivo" }}
          </div>
        </div>

        <button
          @click="executeBenchmark('after')"
          :disabled="store.isBenchmarkTesting || !store.benchmarks.before.measured"
          class="mt-4 w-full py-2 px-3 bg-cyan-950/20 hover:bg-cyan-900/30 text-cyan-400 text-[10px] font-mono font-bold rounded border border-cyan-800/40 transition-all duration-150 disabled:opacity-30 disabled:cursor-not-allowed active:scale-[0.98] shadow-sm shadow-cyan-950/50"
          :title="!store.benchmarks.before.measured ? 'Primero debes calibrar el entorno inicial' : ''"
        >
          {{ store.isBenchmarkTesting ? "ANALIZANDO..." : "ESCANEAR MEJORA FILTRADA" }}
        </button>
      </div>
    </div>

    <div
      v-if="improvementNetwork || improvementDns"
      class="p-3 rounded-lg bg-zinc-900/30 border border-zinc-900 grid grid-cols-2 gap-3 font-mono"
    >
      <div
        class="flex items-center gap-2.5 p-2 rounded bg-zinc-950/50 border border-zinc-900"
      >
        <div
          class="p-1.5 rounded bg-cyan-950/40 text-cyan-400 border border-cyan-900/30"
        >
          <svg
            class="h-3.5 w-3.5"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
          </svg>
        </div>
        <div>
          <div class="text-[8px] text-zinc-500 uppercase tracking-widest">
            Delta Trafico TCP
          </div>
          <div
            class="text-[11px] font-black tracking-tight"
            :class="
              improvementNetwork?.positive
                ? 'text-emerald-400'
                : 'text-zinc-500'
            "
          >
            {{
              improvementNetwork?.positive
                ? `+ ${improvementNetwork.percent}% EFICIENCIA`
                : "SIN VARIACION"
            }}
          </div>
        </div>
      </div>

      <div
        class="flex items-center gap-2.5 p-2 rounded bg-zinc-950/50 border border-zinc-900"
      >
        <div
          class="p-1.5 rounded bg-cyan-950/40 text-cyan-400 border border-cyan-900/30"
        >
          <svg
            class="h-3.5 w-3.5"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
        </div>
        <div>
          <div class="text-[8px] text-zinc-500 uppercase tracking-widest">
            Resolucion Nombres
          </div>
          <div
            class="text-[11px] font-black tracking-tight"
            :class="
              improvementDns?.positive ? 'text-emerald-400' : 'text-zinc-500'
            "
          >
            {{
              improvementDns?.positive
                ? `+ ${improvementDns.percent}% FLUIDEZ`
                : "SIN VARIACION"
            }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
