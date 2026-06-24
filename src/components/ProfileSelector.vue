<template>
  <section class="mb-12">
    <div class="flex items-center gap-3 mb-5">
      <svg
        class="w-6 h-6 text-yellow-500"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
        ></path>
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
        ></path>
      </svg>
      <h2 class="text-xl md:text-2xl font-bold text-white tracking-wide">
        Perfiles de Optimización
      </h2>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
      <button
        v-for="profile in [
          'Competitivo',
          'Programador & Competitivo',
          'Programador',
          'Home Office / Laptops',
          'Usuario Casual',
          'Personalizado',
        ]"
        :key="profile"
        @click="store.applyProfile(profile)"
        class="px-4 py-3 rounded-xl text-sm font-bold transition-all duration-300 border text-center flex items-center justify-center min-h-[60px]"
        :class="
          store.activeProfile === profile
            ? 'bg-yellow-500/20 border-yellow-500/50 text-yellow-400 shadow-[0_0_15px_rgba(250,204,21,0.15)]'
            : 'bg-white/5 border-white/10 text-gray-400 hover:bg-white/10 hover:text-white'
        "
      >
        <span class="leading-tight">{{ profile }}</span>
      </button>
    </div>

    <div
      class="mt-5 px-4 py-3 bg-white/5 rounded-lg border border-white/5 flex items-start gap-3"
    >
      <svg
        class="w-5 h-5 text-gray-400 shrink-0 mt-0.5"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
        ></path>
      </svg>
      <p class="text-sm text-gray-300 font-medium leading-relaxed">
        <span v-if="store.activeProfile === 'Competitivo'"
          >Optimización máxima. Aísla el CPU, reduce latencia de periféricos y prioriza hilos de juego para 0%
          input lag. Recomendado para setups de alta gama.</span
        >
        <span v-else-if="store.activeProfile === 'Programador & Competitivo'"
          >Equilibrio perfecto. Mantiene la virtualización activa para Docker/Máquinas
          Virtuales, pero inyecta baja latencia y hooks a los motores de
          juego.</span
        >
        <span v-else-if="store.activeProfile === 'Programador'"
          >Optimiza el rendimiento del compilador, aplica caché de almacenamiento inteligente y reduce servicios innecesarios en segundo plano para desarrollo.</span
        >
        <span v-else-if="store.activeProfile === 'Home Office / Laptops'"
          >Prioriza la duración de la batería en Laptops y la estabilidad de la
          red para videollamadas.</span
        >
        <span v-else-if="store.activeProfile === 'Usuario Casual'"
          >El estándar. Windows 11 ultraligero para navegación y multimedia sin
          tweaks arriesgados.</span
        >
        <span v-else
          >Modo personalizado. Activa o desactiva los módulos manualmente según
          tus necesidades técnicas.</span
        >
      </p>
    </div>
  </section>
</template>

<script setup lang="ts">
import { useOverlordStore } from "../stores/overlordStore";
const store = useOverlordStore();
</script>
