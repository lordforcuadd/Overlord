import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";

export function useOptimizer() {
  const isOptimizing = ref(false);
  const optimizationLogs = ref<string[]>([]);

  const executeUnifiedOptimization = async (
    modules: Record<string, boolean>,
    isLaptop: boolean,
    ramGb: number,
  ) => {
    isOptimizing.value = true;
    optimizationLogs.value.push(
      "Iniciando suite de optimización centralizada...",
    );
    try {
      const response = await invoke<string>("run_optimization", {
        modules,
        isLaptop,
        ramGb,
      });
      optimizationLogs.value.push(response);
      return { success: true, message: response };
    } catch (error) {
      const errMsg = String(error);
      optimizationLogs.value.push(`[ERROR]: ${errMsg}`);
      return { success: false, error: errMsg };
    } finally {
      isOptimizing.value = false;
    }
  };

  return {
    isOptimizing,
    optimizationLogs,
    executeUnifiedOptimization,
  };
}
