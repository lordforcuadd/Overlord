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
      <div class="flex items-center gap-2">
        <span
          v-if="store.hardwareInfo.isArm64"
          class="px-2 py-1 bg-yellow-500/20 text-yellow-300 rounded text-xs font-bold uppercase tracking-wider border border-yellow-500/30"
        >
          ARM64
        </span>
        <span
          class="px-2 py-1 bg-white/5 rounded text-xs font-bold text-gray-300 uppercase tracking-wider"
        >
          {{ store.hardwareInfo.isLaptop ? "Laptop" : "Desktop" }}
        </span>
      </div>
    </div>

    <div class="flex flex-col gap-3 text-xs md:text-sm font-mono text-gray-400">
      <div
        class="flex items-center justify-between border-b border-white/5 pb-2 gap-4"
      >
        <div class="flex items-center gap-2 text-gray-500 shrink-0">
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
        <div class="text-right truncate min-w-0 flex-1 pl-4">
          <span
            class="text-gray-200 block truncate"
            :title="store.hardwareInfo.motherboard"
          >
            {{ store.hardwareInfo.motherboard || "Buscando..." }}
          </span>
          <span
            v-if="store.hardwareInfo.biosVersion && store.hardwareInfo.biosVersion !== 'Desconocida'"
            class="text-[10px] text-gray-500 block truncate"
            :title="`BIOS ${store.hardwareInfo.biosVendor} ${store.hardwareInfo.biosVersion} (${store.hardwareInfo.biosDate})`"
          >
            BIOS: {{ store.hardwareInfo.biosVersion }} {{ store.hardwareInfo.biosDate ? '· ' + store.hardwareInfo.biosDate : '' }}
          </span>
        </div>
      </div>

      <div
        class="flex items-center justify-between border-b border-white/5 pb-2 gap-4"
      >
        <div class="flex items-center gap-2 text-gray-500 shrink-0">
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
        <div class="text-right truncate min-w-0 flex-1 pl-4 flex items-center justify-end gap-1.5">
          <span
            class="text-white truncate"
            :title="store.hardwareInfo.cpu"
          >
            {{ store.hardwareInfo.cpu || "Buscando..." }}
          </span>
          <span
            v-if="store.hardwareInfo.isX3d"
            class="px-1.5 py-0.5 rounded text-[10px] bg-red-500/20 text-red-300 font-bold border border-red-500/30 shrink-0"
            title="AMD Ryzen 3D V-Cache detectado. Enrutamiento IRQ activo."
          >
            X3D
          </span>
        </div>
      </div>

      <div
        class="flex items-center justify-between border-b border-white/5 pb-2 gap-4"
      >
        <div class="flex items-center gap-2 text-gray-500 shrink-0">
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
        <div class="text-right truncate min-w-0 flex-1 pl-4 flex items-center justify-end gap-1.5">
          <span
            class="text-yellow-400 font-bold truncate"
            :title="store.hardwareInfo.gpu"
          >
            {{ store.hardwareInfo.gpu || "Buscando..." }}
          </span>
          <span
            v-if="store.hardwareInfo.isRebarEnabled === true"
            class="text-[9px] px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-300 font-bold border border-emerald-500/30 shrink-0"
            title="Resizable BAR / SAM activo en BIOS y GPU"
          >
            ReBAR
          </span>
          <span
            v-else-if="store.hardwareInfo.isRebarEnabled === false"
            class="text-[9px] px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-300 font-bold border border-amber-500/30 shrink-0"
            title="Resizable BAR inactivo. Actívalo en BIOS para mayor rendimiento."
          >
            No ReBAR
          </span>
        </div>
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
        <div class="text-right flex items-center gap-2">
          <span class="text-white font-bold text-sm">
            {{
              store.hardwareInfo.ramGb !== undefined && store.hardwareInfo.ramGb > 0
                ? `${store.hardwareInfo.ramGb} GB`
                : "..."
            }}
          </span>
          <span
            v-if="
              store.hardwareInfo.ramSpeedMhz &&
              store.hardwareInfo.ramSpeedMhz > 0
            "
            class="text-gray-400 text-xs"
          >
            @ {{ store.hardwareInfo.ramSpeedMhz }} MHz
          </span>
          <span
            v-if="store.hardwareInfo.isXmpActive === false"
            class="text-[9px] px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-300 font-bold border border-amber-500/30"
            :title="
              store.hardwareInfo.ramMaxSpeedMhz &&
              store.hardwareInfo.ramMaxSpeedMhz > 0
                ? `Tu RAM corre a ${store.hardwareInfo.ramSpeedMhz} MHz (Kit soporta ${store.hardwareInfo.ramMaxSpeedMhz} MHz). Activa XMP/EXPO en BIOS.`
                : `Tu RAM corre por debajo de la frecuencia máxima soportada. Activa XMP/EXPO en BIOS.`
            "
          >
            XMP OFF
          </span>
          <span
            v-else-if="store.hardwareInfo.isXmpActive === true"
            class="text-[9px] px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-300 font-bold border border-emerald-500/30"
            title="Perfil XMP/EXPO o frecuencia óptima activa."
          >
            XMP ON
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

      <!-- Daemon Status & Log Console Bar -->
      <div class="flex items-center justify-between border-t border-white/5 pt-3 mt-1">
        <div class="flex items-center gap-2 min-w-0 flex-1 mr-2">
          <span
            class="w-2 h-2 rounded-full shrink-0"
            :class="store.daemonStatus.isInstalled ? 'bg-green-400 animate-pulse' : 'bg-gray-500'"
          ></span>
          <span
            class="text-[11px] text-gray-300 font-sans truncate"
            :title="store.daemonStatus.statusText"
          >
            {{ store.daemonStatus.statusText }}
          </span>
        </div>

        <button
          @click="store.openLogModal"
          class="px-2.5 py-1 rounded-lg bg-yellow-500/10 hover:bg-yellow-500/20 text-yellow-400 hover:text-yellow-300 text-xs font-bold transition-all flex items-center gap-1.5 border border-yellow-500/20 shrink-0 font-sans"
          title="Abrir Consola de Eventos y Logs"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
          <span>Logs & Auditoría</span>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useOverlordStore } from "../stores/overlordStore";
const store = useOverlordStore();
</script>
