<template>
  <div
    class="bg-[#0a0a0a]/80 backdrop-blur-xl border border-yellow-500/20 p-5 rounded-2xl flex flex-col gap-4 shadow-[0_0_30px_rgba(250,204,21,0.05)] w-full lg:w-auto lg:min-w-[380px]"
  >
    <div class="flex items-center justify-between border-b border-white/5 pb-3">
      <div class="flex items-center gap-3">
        <div class="relative flex h-3 w-3">
          <span
            class="animate-ping absolute inline-flex h-full w-full rounded-full bg-yellow-400 opacity-75"
          ></span>
          <span
            class="relative inline-flex rounded-full h-3 w-3 bg-yellow-500"
          ></span>
        </div>
        <span
          class="text-sm font-bold text-yellow-400 tracking-widest uppercase"
        >
          Perfil: {{ store.hardwareInfo.tier }}
        </span>
      </div>
      <span
        class="px-2 py-1 bg-white/5 rounded text-xs font-bold text-gray-300 uppercase tracking-wider"
      >
        {{ store.hardwareInfo.isLaptop ? "Laptop" : "Desktop" }}
      </span>
    </div>

    <div class="flex flex-col gap-3 text-xs md:text-sm font-mono text-gray-400">
      <div
        class="flex items-center justify-between border-b border-white/5 pb-2 gap-4"
      >
        <div class="flex items-center gap-2 text-gray-500">
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
              d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"
            ></path>
          </svg>
          <span>PLACA</span>
        </div>
        <span
          class="text-gray-200 text-right truncate max-w-[150px] sm:max-w-[300px] lg:max-w-[180px] xl:max-w-[240px]"
          :title="store.hardwareInfo.motherboard"
        >
          {{ store.hardwareInfo.motherboard || "Buscando..." }}
        </span>
      </div>

      <div
        class="flex items-center justify-between border-b border-white/5 pb-2 gap-4"
      >
        <div class="flex items-center gap-2 text-gray-500">
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
              d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
            ></path>
          </svg>
          <span>CPU</span>
        </div>
        <span
          class="text-white text-right truncate max-w-[150px] sm:max-w-[300px] lg:max-w-[180px] xl:max-w-[240px]"
          :title="store.hardwareInfo.cpu"
        >
          {{ store.hardwareInfo.cpu || "Buscando..." }}
        </span>
      </div>

      <div
        class="flex items-center justify-between border-b border-white/5 pb-2 gap-4"
      >
        <div class="flex items-center gap-2 text-gray-500">
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
              d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
            ></path>
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
            ></path>
          </svg>
          <span>GPU</span>
        </div>
        <span
          class="text-yellow-400 font-bold text-right truncate max-w-[150px] sm:max-w-[300px] lg:max-w-[180px] xl:max-w-[240px]"
          :title="store.hardwareInfo.gpu"
        >
          {{ store.hardwareInfo.gpu || "Buscando..." }}
        </span>
      </div>

      <div
        class="flex items-center justify-between border-b border-white/5 pb-2"
      >
        <div class="flex items-center gap-2 text-gray-500">
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
              d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4"
            ></path>
          </svg>
          <span>RAM</span>
        </div>
        <div class="text-right">
          <span class="text-white font-bold text-sm">
            {{
              store.hardwareInfo.ramGb
                ? `${store.hardwareInfo.ramGb} GB`
                : "..."
            }}
          </span>
          <span
            v-if="
              store.hardwareInfo.ramSpeedMhz &&
              store.hardwareInfo.ramSpeedMhz > 0
            "
            class="text-gray-500 text-xs ml-2"
          >
            @ {{ store.hardwareInfo.ramSpeedMhz }} MHz
          </span>
        </div>
      </div>

      <div class="flex flex-col gap-1.5 pt-2">
        <div
          class="flex justify-between text-xs font-bold uppercase tracking-wider"
        >
          <span class="text-gray-500">Uso CPU</span>
          <span class="text-white"
            >{{ Number(store.liveTelemetry.cpuUsage).toFixed(1) }}%</span
          >
        </div>
        <div
          class="w-full bg-white/5 h-2 rounded-full overflow-hidden border border-white/5"
        >
          <div
            class="bg-yellow-500 h-full transition-all duration-500 ease-out"
            :style="{ width: store.liveTelemetry.cpuUsage + '%' }"
          ></div>
        </div>
      </div>

      <div class="flex flex-col gap-1.5 pt-1">
        <div
          class="flex justify-between text-xs font-bold uppercase tracking-wider"
        >
          <span class="text-gray-500">Uso RAM</span>
          <span class="text-white">
            {{ Number(store.liveTelemetry.ramUsed).toFixed(2) }} /
            {{ Number(store.liveTelemetry.ramTotal).toFixed(2) }} GB ({{
              Number(store.liveTelemetry.ramPercent).toFixed(1)
            }}%)
          </span>
        </div>
        <div
          class="w-full bg-white/5 h-2 rounded-full overflow-hidden border border-white/5"
        >
          <div
            class="bg-blue-500 h-full transition-all duration-500 ease-out"
            :style="{ width: store.liveTelemetry.ramPercent + '%' }"
          ></div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useOverlordStore } from "../stores/overlordStore";
const store = useOverlordStore();
</script>
