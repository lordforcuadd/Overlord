import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { useOverlordStore } from "../stores/overlordStore";

export function useBenchmark() {
  const store = useOverlordStore();
  const isRunning = ref(false);

  interface BenchmarkResponse {
    tcp_latency: number;
    dns_latency: number;
  }

  async function ejecutarNetworkBenchmark(fase: "before" | "after") {
    if (isRunning.value) return;
    isRunning.value = true;

    try {
      const result = await invoke<BenchmarkResponse>("run_benchmark");

      store.benchmarks[fase].networkLatency = result.tcp_latency;
      store.benchmarks[fase].dnsResolution = result.dns_latency;
      store.benchmarks[fase].measured = true;

      console.log(
        `[Overlord Benchmark] Fase ${fase} completada - TCP: ${result.tcp_latency}ms, DNS: ${result.dns_latency}ms`,
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
