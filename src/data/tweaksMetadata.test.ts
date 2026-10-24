import { describe, it, expect } from "vitest";
import { tweaksMetadata } from "./tweaksMetadata";

describe("Integridad Estructural de tweaksMetadata", () => {
  const allowedScripts = [
    "01_perifericos.ps1",
    "02_debloat.ps1",
    "03_red.ps1",
    "04_rendimiento.ps1",
    "05_gpu_display.ps1",
    "06_irq_affinity.ps1",
    "07_almacenamiento.ps1",
    "08_telemetria.ps1",
    "09_energia.ps1",
    "11_game_hooks.ps1",
    "12_defender_exclusions.ps1",
    "disable_mitigations.ps1",
    "disable_vbs.ps1"
  ];

  it("cada módulo debe tener llaves canónicas completas y válidas", () => {
    const keys = Object.keys(tweaksMetadata);
    expect(keys.length).toBeGreaterThan(10);

    for (const key of keys) {
      const meta = tweaksMetadata[key];
      expect(meta.id).toBe(key);
      expect(meta.title.length).toBeGreaterThan(3);
      expect(meta.description.length).toBeGreaterThan(10);
      expect(meta.scriptName).toBeDefined();
      expect(allowedScripts).toContain(meta.scriptName);
      expect(["Seguro", "Balanceado", "Experimental"]).toContain(meta.riesgo);
      expect(["Comprobado", "Situacional", "Cosmético"]).toContain(meta.evidenciaImpacto);
      expect(meta.details.length).toBeGreaterThan(0);
    }
  });

  it("ningún detalle debe contener la clave obsoleta NtfsMemoryUsage", () => {
    for (const meta of Object.values(tweaksMetadata)) {
      for (const detail of meta.details) {
        expect(detail).not.toContain("NtfsMemoryUsage");
      }
    }
  });

  it("el módulo de juegos debe especificar el bypass DWM", () => {
    const gameMeta = tweaksMetadata.gameHooks;
    expect(gameMeta).toBeDefined();
    const hasDwmBypass = gameMeta.details.some((d) => d.includes("DISABLEDXMAXIMIZEDWINDOWEDMODE"));
    expect(hasDwmBypass).toBe(true);
  });
});
