import { describe, it, expect } from "vitest";
import { buildExpectedProfileState } from "./profileLogic";

describe("buildExpectedProfileState", () => {
  it("debe activar los módulos configurados en un perfil de escritorio", () => {
    const mods = ["peripheralLatency", "debloat", "networkOptimized", "generalPerformance", "irqAffinity"];
    const hardware = { isLaptop: false, tier: "enthusiast", isArm64: false };

    const state = buildExpectedProfileState(mods, hardware);

    expect(state.peripheralLatency).toBe(true);
    expect(state.debloat).toBe(true);
    expect(state.networkOptimized).toBe(true);
    expect(state.generalPerformance).toBe(true);
    expect(state.irqAffinity).toBe(true);
    expect(state.disableMitigations).toBe(false);
    expect(state.disableVbs).toBe(false);
  });

  it("debe excluir irqAffinity automáticamente si el hardware es laptop", () => {
    const mods = ["peripheralLatency", "networkOptimized", "irqAffinity"];
    const hardware = { isLaptop: true, tier: "mid", isArm64: false };

    const state = buildExpectedProfileState(mods, hardware);

    expect(state.peripheralLatency).toBe(true);
    expect(state.networkOptimized).toBe(true);
    expect(state.irqAffinity).toBe(false); // Exclusión obligatoria por protección térmica
  });

  it("debe excluir disableMitigations si la arquitectura es ARM64", () => {
    const mods = ["generalPerformance", "disableMitigations"];
    const hardware = { isLaptop: false, isArm64: true };

    const state = buildExpectedProfileState(mods, hardware);

    expect(state.generalPerformance).toBe(true);
    expect(state.disableMitigations).toBe(false); // Inexistente en ARM64
  });

  it("debe ignorar llaves de módulos desconocidas o corruptas", () => {
    const mods = ["moduloFantasma", "peripheralLatency"];
    const hardware = { isLaptop: false, isArm64: false };

    const state = buildExpectedProfileState(mods, hardware);

    expect(state.peripheralLatency).toBe(true);
    expect((state as Record<string, boolean>).moduloFantasma).toBeUndefined();
  });
});
