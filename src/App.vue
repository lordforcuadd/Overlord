<template>
  <div
    class="relative min-h-screen bg-[#050505] text-gray-200 font-sans p-6 md:p-10 overflow-x-hidden z-0"
  >
    <div
      class="fixed top-[-10%] left-[-5%] w-[500px] h-[500px] bg-yellow-500/10 rounded-full blur-[120px] -z-10 pointer-events-none"
    ></div>
    <div
      class="fixed bottom-[-10%] right-[-5%] w-[400px] h-[400px] bg-yellow-500/10 rounded-full blur-[120px] -z-10 pointer-events-none"
    ></div>

    <div class="max-w-7xl mx-auto relative z-10">
      <header
        class="mb-14 flex flex-col lg:flex-row justify-between items-start lg:items-center border-b border-white/10 pb-8 gap-8"
      >
        <div class="flex items-center gap-4">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-12 h-12 md:w-16 md:h-16 text-yellow-500 shrink-0 transform hover:scale-105 transition-transform duration-300"
          >
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M2 21L2 9L8.5 14L12 2L15.5 14L22 9L22 21H2ZM13 8L9 14H11.5L11 20L15 14H12.5L13 8Z"
            />
          </svg>

          <div>
            <h1
              class="text-5xl md:text-6xl font-black tracking-tighter text-white"
            >
              OVER<span class="text-yellow-500">LORD</span>
            </h1>
            <p
              class="text-gray-400 mt-1 font-medium tracking-widest uppercase text-xs md:text-sm"
            >
              Optimizador de Windows v1.0
            </p>
          </div>
        </div>

        <div
          class="bg-[#0a0a0a]/80 backdrop-blur-xl border border-yellow-500/20 p-5 rounded-2xl flex flex-col gap-4 shadow-[0_0_30px_rgba(250,204,21,0.05)] w-full lg:w-auto lg:min-w-[380px]"
        >
          <div
            class="flex items-center justify-between border-b border-white/5 pb-3"
          >
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

          <div
            class="flex flex-col gap-3 text-xs md:text-sm font-mono text-gray-400"
          >
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
                class="text-gray-200 text-right truncate max-w-[600px]"
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
                class="text-white text-right truncate max-w-[600px]]"
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
                class="text-yellow-400 font-bold text-right truncate max-w-[600px]"
                :title="store.hardwareInfo.gpu"
              >
                {{ store.hardwareInfo.gpu || "Buscando..." }}
              </span>
            </div>

            <div class="flex items-center justify-between pt-1">
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
                    store.hardwareInfo.ram
                      ? `${store.hardwareInfo.ram} GB`
                      : "..."
                  }}
                </span>
                <span
                  v-if="store.hardwareInfo.ramSpeed"
                  class="text-gray-500 text-xs ml-2"
                >
                  @ {{ store.hardwareInfo.ramSpeed }} MT/s
                </span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <QuickActions />

      <QolPanel />

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
              >Inyección máxima. Aísla el CPU y apaga seguridad virtual para 0%
              input lag. Recomendado para setups de alta gama.</span
            >
            <span
              v-else-if="store.activeProfile === 'Programador & Competitivo'"
              >Equilibrio perfecto. Mantiene VBS activo para Docker/Máquinas
              Virtuales, pero inyecta baja latencia y hooks a los motores de
              juego.</span
            >
            <span v-else-if="store.activeProfile === 'Programador'"
              >Optimiza el compilador y la RAM liberando servicios de telemetría
              sin tocar el comportamiento del Kernel.</span
            >
            <span v-else-if="store.activeProfile === 'Home Office / Laptops'"
              >Prioriza la duración de la batería en Laptops y la estabilidad de
              la red para videollamadas.</span
            >
            <span v-else-if="store.activeProfile === 'Usuario Casual'"
              >El estándar. Windows 11 ultraligero para navegación y multimedia
              sin tweaks arriesgados.</span
            >
            <span v-else
              >Modo personalizado. Activa o desactiva los módulos manualmente
              según tus necesidades técnicas.</span
            >
          </p>
        </div>
      </section>

      <main
        class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8 mb-32"
      >
        <ModuleCard
          title="Latencia de Periféricos"
          description="Erradica el input delay reescribiendo las colas de interrupción de hardware y el procesado de entrada."
          scriptName="01_perifericos.ps1"
          v-model="store.modules.peripheralLatency"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.peripheralLatency || 'idle'"
          :details="[
            'Habilita MSI Mode (Message Signaled Interrupts)',
            'Bloquea USB Selective Suspend',
            'Fuerza Timer Resolution a 0.5ms',
            'Anula la aceleración de ratón (Raw Tracking)',
          ]"
        />

        <ModuleCard
          title="Limpieza Segura y Debloat"
          description="Libera RAM y CPU destruyendo telemetría profunda y servicios parásitos, sin romper herramientas de trabajo."
          scriptName="02_debloat.ps1"
          v-model="store.modules.debloat"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.debloat || 'idle'"
          :details="[
            'Bloqueo de AllowTelemetry vía GPO',
            'Purga de Apps UWP y Bloatware preinstalado',
            'Apaga tareas CEIP',
            'Black Viper Method Seguro',
          ]"
        />

        <ModuleCard
          title="Network & TCP/IP Stack"
          description="Destruye el empaquetamiento de red para que tus clics se envíen al servidor en el milisegundo exacto."
          scriptName="03_red.ps1"
          v-model="store.modules.networkOptimized"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.networkOptimized || 'idle'"
          :details="[
            'Deshabilita Algoritmo de Nagle',
            'Ajusta NetworkThrottlingIndex a FFFFFFFF',
            'Fuerza MTU a 1500',
            'Purgado de Caché DNS',
          ]"
        />

        <ModuleCard
          title="Rendimiento y Memoria"
          description="Gestión inteligente de RAM. Corta los estranguladores de CPU y limita el consumo de los antivirus."
          scriptName="04_rendimiento.ps1"
          v-model="store.modules.generalPerformance"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.generalPerformance || 'idle'"
          :details="[
            'Limita Defender al 25% de uso',
            'Desactiva Paginación del Kernel',
            'Inyecta Plan Ultimate Performance',
            'Purga cachés DirectX',
          ]"
        />

        <ModuleCard
          title="GPU & Display Engine"
          description="Secuestra el programador multimedia (MMCSS) para darle a la GPU prioridad absoluta sobre el sistema."
          scriptName="05_gpu_display.ps1"
          v-model="store.modules.gpuDisplay"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.gpuDisplay || 'idle'"
          :details="[
            'Forza SystemResponsiveness al 0%',
            'Ajusta DWM.exe a Prioridad High',
            'Habilita HAGS (Hardware Scheduling)',
            'Destruye overlays GameDVR',
          ]"
        />

        <ModuleCard
          title="Aislamiento de Núcleos (IRQ)"
          description="Aleja el tráfico de red del Núcleo 0 para evitar que interrumpa el renderizado y los FPS del juego."
          scriptName="06_irq_affinity.ps1"
          v-model="store.modules.irqAffinity"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.irqAffinity || 'idle'"
          :details="[
            'Configura IRQ8Priority a 1',
            'Aplica DevicePolicy 4 a la red',
            'Fuerza interrupciones a núcleos secundarios',
            'Estabiliza Frame Pacing',
          ]"
        />

        <ModuleCard
          title="Smart Storage & WinSxS"
          description="Optimiza el bus de datos NVMe y ejecuta una purga profunda de nivel Kernel recuperando gigabytes."
          scriptName="07_almacenamiento.ps1"
          v-model="store.modules.smartStorage"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.smartStorage || 'idle'"
          :details="[
            'Purga profunda de WinSxS',
            'Activa LargeSystemCache',
            'Borra instaladores de Windows Update',
            'Gestión SSD inteligente',
          ]"
        />

        <ModuleCard
          title="Seguridad Virtual (VBS)"
          description="Apaga las capas de virtualización de Windows 11 que merman el rendimiento bruto del procesador."
          scriptName="08_telemetria.ps1"
          v-model="store.modules.deepTelemetry"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.deepTelemetry || 'idle'"
          :details="[
            'Deshabilita VBS',
            'Apaga HVCI (Memory Integrity)',
            'Inyecta sumideros DNS (Hosts)',
            'Mata DiagTrack de raíz',
          ]"
        />

        <ModuleCard
          title="Game-Specific Hooks"
          description="Inyecta reglas dinámicas a los motores de tus juegos instalados para máximo rendimiento."
          scriptName="11_game_hooks.ps1"
          v-model="store.modules.gameHooks"
          @update:modelValue="store.activeProfile = 'Personalizado'"
          :status="cardStatus.gameHooks || 'idle'"
          :details="[
            'Fuerza CpuPriorityClass=3',
            'Sobrescribe Task Manager',
            'Optimización por proceso',
          ]"
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

      <footer
        class="mb-24 flex flex-col items-center gap-6 border-t border-white/5 pt-10"
      >
        <div
          class="flex flex-col md:flex-row justify-center gap-4 w-full md:w-auto"
        >
          <button
            @click="crearRespaldo"
            :disabled="isBackingUp"
            class="group bg-blue-500/10 backdrop-blur-md border border-blue-500/30 text-blue-400 hover:bg-blue-500/20 hover:text-blue-300 font-bold py-4 px-8 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(59,130,246,0.1)] flex items-center justify-center gap-3 w-full md:w-auto disabled:opacity-50"
          >
            <svg
              v-if="isBackingUp"
              class="animate-spin h-5 w-5"
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
              v-else
              class="h-5 w-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
              ></path>
            </svg>
            <span>{{
              isBackingUp ? "Protegiendo Sistema..." : "Crear Punto de Respaldo"
            }}</span>
          </button>

          <button
            @click="revertirStock"
            :disabled="isReverting"
            class="bg-red-500/10 backdrop-blur-md border border-red-500/30 text-red-400 hover:bg-red-500/20 hover:text-red-300 font-bold py-4 px-8 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(239,68,68,0.1)] flex items-center justify-center gap-3 w-full md:w-auto disabled:opacity-50"
          >
            <svg
              v-if="isReverting"
              class="animate-spin h-5 w-5"
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
              v-else
              class="h-5 w-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0019 16V8a1 1 0 00-1.6-.8l-5.333 4zM4.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0011 16V8a1 1 0 00-1.6-.8l-5.334 4z"
              ></path>
            </svg>
            <span>{{
              isReverting ? "Restaurando Windows..." : "Revertir Cambios"
            }}</span>
          </button>
        </div>

        <div
          class="flex items-center gap-2 text-gray-500 bg-white/5 px-4 py-2 rounded-lg"
        >
          <svg
            class="w-4 h-4 text-yellow-500/70"
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
          <p class="text-sm font-medium">
            Las modificaciones de Kernel son irreversibles sin un punto de
            restauración. Proceda con precaución.
          </p>
        </div>
      </footer>
    </div>
  </div>

  <div
    class="fixed bottom-0 left-0 w-full bg-[#050505]/90 backdrop-blur-xl border-t border-white/10 p-5 z-40 flex justify-center items-center shadow-[0_-10px_40px_rgba(0,0,0,0.5)]"
  >
    <div
      class="max-w-7xl w-full flex flex-col md:flex-row justify-between items-center gap-5 px-4"
    >
      <div class="flex items-center gap-4">
        <div
          class="w-12 h-12 rounded-full bg-yellow-500/20 flex items-center justify-center border border-yellow-500/50 shadow-[0_0_15px_rgba(250,204,21,0.2)]"
        >
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
              d="M13 10V3L4 14h7v7l9-11h-7z"
            ></path>
          </svg>
        </div>
        <div>
          <h3 class="text-white font-bold text-xl leading-tight">Optimizar</h3>
          <p class="text-gray-400 text-sm mt-1">
            Perfil:
            <span class="text-yellow-400 font-bold uppercase">{{
              store.activeProfile
            }}</span>
            <span class="mx-2 text-gray-600">|</span>
            Módulos:
            <span class="text-white font-bold">{{
              Object.values(store.modules).filter((v) => v).length
            }}</span>
            / 10
          </p>
        </div>
      </div>

      <button
        @click="ejecutarTodo"
        :disabled="
          isExecutingAll ||
          Object.values(store.modules).filter((v) => v).length === 0
        "
        class="bg-yellow-500 hover:bg-yellow-400 text-black font-black uppercase tracking-widest py-3 md:py-4 px-10 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(250,204,21,0.3)] hover:shadow-[0_0_35px_rgba(250,204,21,0.6)] disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-3 w-full md:w-auto justify-center text-sm md:text-base"
      >
        <span v-if="isExecutingAll" class="flex items-center gap-2">
          <svg
            class="animate-spin h-5 w-5 text-black"
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
          Optimizando...
        </span>
        <span v-else>EJECUTAR OVERLORD</span>
      </button>
    </div>
  </div>

  <div
    class="fixed bottom-28 right-6 z-50 bg-[#0a0a0a]/90 backdrop-blur-xl border border-white/10 px-5 py-4 rounded-2xl shadow-2xl flex items-center gap-6 hover:border-yellow-500/30 transition-colors group cursor-default"
  >
    <div class="flex flex-col">
      <span
        class="text-xs text-gray-500 font-bold tracking-widest uppercase mb-1 flex items-center gap-2"
      >
        <div
          class="w-2 h-2 rounded-full animate-pulse"
          :class="
            store.liveTelemetry.cpuUsage > 80 ? 'bg-red-500' : 'bg-yellow-400'
          "
        ></div>
        CPU
      </span>
      <span
        class="text-2xl font-mono font-bold"
        :class="
          store.liveTelemetry.cpuUsage > 80 ? 'text-red-400' : 'text-white'
        "
      >
        {{ store.liveTelemetry.cpuUsage.toFixed(1)
        }}<span class="text-sm text-gray-500 ml-1">%</span>
      </span>
    </div>

    <div
      class="w-px h-10 bg-white/10 group-hover:bg-yellow-500/20 transition-colors"
    ></div>

    <div class="flex flex-col items-start w-28">
      <span
        class="text-xs text-gray-500 font-bold tracking-widest uppercase mb-1"
        >RAM</span
      >
      <span
        class="text-2xl font-mono font-bold text-white leading-none flex items-baseline"
      >
        {{ store.liveTelemetry.ramUsed.toFixed(1)
        }}<span class="text-xs text-yellow-500 ml-1">GB</span>
      </span>
      <div class="w-full h-1.5 bg-white/10 rounded-full mt-2 overflow-hidden">
        <div
          class="h-full bg-yellow-500 transition-all duration-500"
          :style="{ width: store.liveTelemetry.ramPercent + '%' }"
        ></div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import QolPanel from "./components/QolPanel.vue";
import Swal from "sweetalert2";
import QuickActions from "./components/QuickActions.vue";
import { invoke } from "@tauri-apps/api/core";
import { resolveResource } from "@tauri-apps/api/path";
import ModuleCard from "./components/ModuleCard.vue";
import { useOverlordStore } from "./stores/overlordStore";

const store = useOverlordStore();

const cardStatus = ref<
  Record<string, "idle" | "loading" | "success" | "error">
>({});
const isBackingUp = ref(false);
const isReverting = ref(false);
const isExecutingAll = ref(false);

const scriptMap: Record<string, string> = {
  peripheralLatency: "01_perifericos.ps1",
  debloat: "02_debloat.ps1",
  networkOptimized: "03_red.ps1",
  generalPerformance: "04_rendimiento.ps1",
  gpuDisplay: "05_gpu_display.ps1",
  irqAffinity: "06_irq_affinity.ps1",
  smartStorage: "07_almacenamiento.ps1",
  deepTelemetry: "08_telemetria.ps1",
  powerProfiles: "09_energia.ps1",
  gameHooks: "11_game_hooks.ps1",
};

async function ejecutarTodo() {
  if (isExecutingAll.value) return;
  isExecutingAll.value = true;

  const isLaptopStr = store.hardwareInfo.isLaptop ? "$true" : "$false";
  const ramGbStr = store.hardwareInfo.ram.toString();

  const modulosActivos = Object.entries(store.modules)
    .filter(([_, isEnabled]) => isEnabled)
    .map(([key, _]) => key);

  for (const modKey of modulosActivos) {
    const scriptName = scriptMap[modKey];
    if (!scriptName) continue;

    console.log(`[MASTER] Ejecutando: ${scriptName}...`);
    cardStatus.value[modKey] = "loading";

    try {
      let rawPath = await resolveResource(`scripts/${scriptName}`);
      const scriptPath = rawPath.replace(/^\\\\\\?\\\\/, "");

      let args = `-IsLaptop ${isLaptopStr} -RamGB ${ramGbStr}`;

      if (modKey === "gameHooks") {
        const selectedGames = store.gameList
          .filter((g) => g.optimize)
          .map((g) => g.exe)
          .join(",");
        args += ` -GameList "${selectedGames}"`;
      }

      await invoke("run_powershell_async", {
        scriptPath: scriptPath,
        argsString: args,
      });

      console.log(`[MASTER] ✅ Éxito en ${scriptName}`);
      cardStatus.value[modKey] = "success";
    } catch (errorOutput) {
      console.error(
        `[MASTER] ❌ Error real capturado en ${scriptName}:`,
        errorOutput,
      );
      cardStatus.value[modKey] = "error";
    }
  }

  isExecutingAll.value = false;
  console.log("[MASTER] Secuencia finalizada.");

  isExecutingAll.value = false;
  console.log("[MASTER] Secuencia finalizada.");

  if (modulosActivos.length > 0) {
    setTimeout(() => {
      Swal.fire({
        title: "SISTEMA OPTIMIZADO",
        html: "Para que los cambios en el Kernel y Registro se apliquen al 100%, es <b>OBLIGATORIO</b> reiniciar el equipo.<br><br>¿Deseas reiniciar tu PC ahora mismo?",
        icon: "success",
        iconColor: "#eab308",
        background: "#0a0a0a",
        color: "#e5e7eb",
        showCancelButton: true,
        confirmButtonColor: "#eab308",
        cancelButtonColor: "#262626",
        confirmButtonText: "SÍ, REINICIAR",
        cancelButtonText: "MÁS TARDE",
        reverseButtons: true,
        customClass: {
          popup:
            "border border-yellow-500/20 rounded-2xl shadow-[0_0_40px_rgba(250,204,21,0.15)]",
          title: "font-black tracking-wide text-yellow-400",
          htmlContainer: "text-sm text-gray-400",
          confirmButton:
            "text-black font-black uppercase tracking-widest px-8 py-3 rounded-xl shadow-[0_0_15px_rgba(250,204,21,0.3)] hover:shadow-[0_0_25px_rgba(250,204,21,0.5)] transition-all",
          cancelButton:
            "text-gray-400 font-bold uppercase tracking-widest px-6 py-3 rounded-xl border border-white/10 hover:bg-white/5 transition-colors",
        },
      }).then(async (result) => {
        if (result.isConfirmed) {
          try {
            await invoke("run_powershell_async", {
              scriptPath: "shutdown",
              argsString: "/r /t 0",
            });
          } catch (error) {
            console.error("Fallo al forzar el reinicio:", error);

            Swal.fire({
              title: "ERROR DE REINICIO",
              text: "No se pudo forzar el reinicio automático. Por favor, reinicia manualmente desde el menú de Windows.",
              icon: "error",
              iconColor: "#ef4444",
              background: "#0a0a0a",
              color: "#e5e7eb",
              confirmButtonColor: "#ef4444",
              confirmButtonText: "ENTENDIDO",
              customClass: {
                popup:
                  "border border-red-500/20 rounded-2xl shadow-[0_0_30px_rgba(239,68,68,0.1)]",
                title: "font-black tracking-wide text-red-400",
                htmlContainer: "text-sm text-gray-400",
                confirmButton:
                  "text-white font-black uppercase tracking-widest px-8 py-3 rounded-xl shadow-[0_0_15px_rgba(239,68,68,0.3)] hover:shadow-[0_0_25px_rgba(239,68,68,0.5)] transition-all",
              },
            });
          }
        }
      });
    }, 500);
  }
}

onMounted(async () => {
  if (store.detectHardware) {
    await store.detectHardware();
    await store.scanGames();
    store.startTelemetryPolling();
  }
});

async function crearRespaldo() {
  isBackingUp.value = true;
  try {
    let rawPath = await resolveResource("scripts/crear_respaldo.ps1");
    const scriptPath = rawPath.replace(/^\\\\\\?\\\\/, "");

    await invoke("run_powershell_async", {
      scriptPath: scriptPath,
      argsString: "",
    });

    Swal.fire({
      title: "¡Punto Creado!",
      text: "Se ha creado el punto de restauración: Overlord - Punto Stock Pre-Optimizacion.",
      icon: "success",
      iconColor: "#3b82f6",
      background: "#0a0a0a",
      color: "#e5e7eb",
      confirmButtonColor: "#3b82f6",
      confirmButtonText: "ENTENDIDO",
      customClass: {
        popup:
          "border border-blue-500/20 rounded-2xl shadow-[0_0_30px_rgba(59,130,246,0.15)]",
        title: "font-black tracking-wide text-blue-400",
        htmlContainer: "text-sm text-gray-400",
        confirmButton:
          "text-white font-black uppercase tracking-widest px-8 py-3 rounded-xl shadow-[0_0_15px_rgba(59,130,246,0.3)] hover:shadow-[0_0_25px_rgba(59,130,246,0.5)] transition-all",
      },
    });
  } catch (error) {
    console.error("Error de conexión:", error);

    Swal.fire({
      title: "ERROR DE RESPALDO",
      text: "No se pudo crear el respaldo de seguridad. Detalles: " + error,
      icon: "error",
      iconColor: "#ef4444",
      background: "#0a0a0a",
      color: "#e5e7eb",
      confirmButtonColor: "#ef4444",
      confirmButtonText: "ENTENDIDO",
      customClass: {
        popup:
          "border border-red-500/20 rounded-2xl shadow-[0_0_30px_rgba(239,68,68,0.15)]",
        title: "font-black tracking-wide text-red-400",
        htmlContainer: "text-sm text-gray-400",
        confirmButton:
          "text-white font-black uppercase tracking-widest px-8 py-3 rounded-xl shadow-[0_0_15px_rgba(239,68,68,0.3)] hover:shadow-[0_0_25px_rgba(239,68,68,0.5)] transition-all",
      },
    });
  } finally {
    isBackingUp.value = false;
  }
}

async function revertirStock() {
  const result = await Swal.fire({
    title: "⚠️ ATENCIÓN",
    text: "Estás a punto de revertir las optimizaciones y volver a los valores por defecto de Windows. ¿Proceder?",
    icon: "warning",
    iconColor: "#ef4444",
    background: "#0a0a0a",
    color: "#e5e7eb",
    showCancelButton: true,
    confirmButtonColor: "#ef4444",
    cancelButtonColor: "#262626",
    confirmButtonText: "SÍ, REVERTIR A WINDOWS NORMAL",
    cancelButtonText: "CANCELAR",
    reverseButtons: true,
    customClass: {
      popup:
        "border border-red-500/20 rounded-2xl shadow-[0_0_30px_rgba(239,68,68,0.15)]",
      title: "font-black tracking-wide text-red-400",
      htmlContainer: "text-sm text-gray-400",
      confirmButton:
        "text-white font-black uppercase tracking-widest px-6 py-3 rounded-xl shadow-[0_0_15px_rgba(239,68,68,0.3)] hover:shadow-[0_0_25px_rgba(239,68,68,0.5)] transition-all",
      cancelButton:
        "text-gray-400 font-bold uppercase tracking-widest px-6 py-3 rounded-xl border border-white/10 hover:bg-white/5 transition-colors",
    },
  });

  if (!result.isConfirmed) return;

  isReverting.value = true;
  try {
    let rawPath = await resolveResource("scripts/10_revertir.ps1");
    const scriptPath = rawPath.replace(/^\\\\\\?\\\\/, "");

    await invoke("run_powershell_async", {
      scriptPath: scriptPath,
      argsString: "",
    });

    Swal.fire({
      title: "SISTEMA REVERTIDO",
      text: "Las optimizaciones han sido eliminadas. Reinicia tu PC para aplicar los cambios.",
      icon: "success",
      iconColor: "#10b981",
      background: "#0a0a0a",
      color: "#e5e7eb",
      confirmButtonColor: "#10b981",
      confirmButtonText: "ENTENDIDO",
      customClass: {
        popup:
          "border border-green-500/20 rounded-2xl shadow-[0_0_30px_rgba(16,185,129,0.15)]",
        title: "font-black tracking-wide text-green-400",
        htmlContainer: "text-sm text-gray-400",
        confirmButton:
          "text-white font-black uppercase tracking-widest px-8 py-3 rounded-xl shadow-[0_0_15px_rgba(16,185,129,0.3)] hover:shadow-[0_0_25px_rgba(16,185,129,0.5)] transition-all",
      },
    });
  } catch (error) {
    console.error("Error de comunicación:", error);

    Swal.fire({
      title: "ERROR DE REVERSIÓN",
      text: "La reversión falló. Detalles: " + error,
      icon: "error",
      iconColor: "#ef4444",
      background: "#0a0a0a",
      color: "#e5e7eb",
      confirmButtonColor: "#ef4444",
      confirmButtonText: "ENTENDIDO",
      customClass: {
        popup:
          "border border-red-500/20 rounded-2xl shadow-[0_0_30px_rgba(239,68,68,0.15)]",
        title: "font-black tracking-wide text-red-400",
        htmlContainer: "text-sm text-gray-400",
        confirmButton:
          "text-white font-black uppercase tracking-widest px-8 py-3 rounded-xl shadow-[0_0_15px_rgba(239,68,68,0.3)] hover:shadow-[0_0_25px_rgba(239,68,68,0.5)] transition-all",
      },
    });
  } finally {
    isReverting.value = false;
  }
}
</script>

<style>
body {
  margin: 0;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

::-webkit-scrollbar {
  width: 8px;
}

::-webkit-scrollbar-track {
  background: #050505;
}

::-webkit-scrollbar-thumb {
  background: #222;
  border-radius: 10px;
}

::-webkit-scrollbar-thumb:hover {
  background: #fab005;
}
</style>
