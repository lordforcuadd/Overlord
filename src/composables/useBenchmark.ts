import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { useOverlordStore } from "../stores/overlordStore";

interface BenchmarkBackendResponse {
  network_latency_ms: number;
  dns_resolution_ms: number;
}

export function useBenchmark() {
  const store = useOverlordStore();
  const isTesting = ref(false);

  const executeBenchmark = async (type: "before" | "after") => {
    isTesting.value = true;
    try {
      const response = await invoke<BenchmarkBackendResponse>("run_benchmark");
      store.benchmarks[type].networkLatency = response.network_latency_ms;
      store.benchmarks[type].dnsResolution = response.dns_resolution_ms;
      store.benchmarks[type].measured = true;
      return { success: true };
    } catch (error) {
      console.error("[BENCHMARK FAILURE]:", error);
      return { success: false, error: String(error) };
    } finally {
      isTesting.value = false;
    }
  };

  return {
    isTesting,
    executeBenchmark,
  };
}
