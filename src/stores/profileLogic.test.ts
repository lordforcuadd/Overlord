import { describe, it, expect } from "vitest";
import { buildExpectedProfileState } from "./profileLogic";
import { PROFILE_CONFIGS } from "../data/tweaksMetadata";

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

  it("debe validar la composición de todos los perfiles oficiales de PROFILE_CONFIGS", () => {
    // 1. Programador
    const progState = buildExpectedProfileState(PROFILE_CONFIGS["Programador"], { isLaptop: false });
    expect(progState.debloat).toBe(true);
    expect(progState.smartStorage).toBe(true);
    expect(progState.generalPerformance).toBe(true);
    expect(progState.powerProfiles).toBe(true);
    expect(progState.gameHooks).toBe(false);
    expect(progState.defenderExclusions).toBe(false);

    // 2. Home Office / Laptops
    const laptopState = buildExpectedProfileState(PROFILE_CONFIGS["Home Office / Laptops"], { isLaptop: true });
    expect(laptopState.peripheralLatency).toBe(true);
    expect(laptopState.debloat).toBe(true);
    expect(laptopState.networkOptimized).toBe(true);
    expect(laptopState.smartStorage).toBe(true);
    expect(laptopState.defenderExclusions).toBe(false);
    expect(laptopState.irqAffinity).toBe(false);

    // 3. Usuario Casual
    const casualState = buildExpectedProfileState(PROFILE_CONFIGS["Usuario Casual"], { isLaptop: false });
    expect(casualState.peripheralLatency).toBe(true);
    expect(casualState.debloat).toBe(true);
    expect(casualState.smartStorage).toBe(true);
    expect(casualState.defenderExclusions).toBe(false);
    expect(casualState.powerProfiles).toBe(false);
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
