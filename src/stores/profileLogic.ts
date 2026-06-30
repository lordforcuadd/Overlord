import { PROFILE_CONFIGS } from "../data/tweaksMetadata";

export function buildExpectedProfileState(
  profileMods: string[],
  hardware: { isLaptop: boolean; tier: string }
): Record<string, boolean> {
  const expected: Record<string, boolean> = {
    peripheralLatency: false,
    debloat: false,
    networkOptimized: false,
    generalPerformance: false,
    gpuDisplay: false,
    irqAffinity: false,
    smartStorage: false,
    deepTelemetry: false,
    powerProfiles: false,
    gameHooks: false,
    disableMitigations: false
  };

  profileMods.forEach((mod) => {
    if (mod === "irqAffinity" && hardware.isLaptop) return;
    if (mod === "powerProfiles" && hardware.isLaptop) return;
    if (mod === "irqAffinity" && hardware.tier === "Gama Estándar") return;
    if (mod === "disableMitigations" && hardware.tier !== "Gama Estándar") return;
    expected[mod] = true;
  });

  return expected;
}
