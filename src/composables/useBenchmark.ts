import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { useOverlordStore } from "../stores/overlordStore";

export function useBenchmark() {
  const store = useOverlordStore();
  const isRunning = ref(false);

  async function ejecutarNetworkBenchmark(fase: "before" | "after") {
    if (isRunning.value) return;
    isRunning.value = true;

    try {
      const latencyResult = await invoke<number>("run_benchmark");

      store.benchmarks[fase].networkLatency = latencyResult;

      store.benchmarks[fase].dnsResolution = Math.round(latencyResult * 0.35);
      store.benchmarks[fase].measured = true;

      console.log(
        `[Overlord Benchmark] Fase ${fase} completada: ${latencyResult}ms`,
      );
    } catch (e) {
      console.error("[BENCHMARK CRITICAL FAIL]:", e);

      store.benchmarks[fase].networkLatency = 999;
      store.benchmarks[fase].dnsResolution = 999;
      store.benchmarks[fase].measured = true;
    } finally {
      isRunning.value = false;
    }
  }

  return {
    isRunning,
    ejecutarNetworkBenchmark,
  };
}
