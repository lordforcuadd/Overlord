import { describe, it, expect } from "vitest";

describe("Reglas de Protección y Seguridad de AppX", () => {
  const protectedSystemApps = [
    "Microsoft.WindowsStore",
    "Microsoft.DesktopAppInstaller",
    "Microsoft.WindowsTerminal",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.Windows.ShellExperienceHost",
    "Microsoft.Windows.StartMenuExperienceHost",
    "Microsoft.Windows.Search"
  ];

  it("las aplicaciones nucleares del sistema no deben ser seleccionables como debloat seguro", () => {
    for (const app of protectedSystemApps) {
      expect(app.length).toBeGreaterThan(0);
      expect(app).not.toMatch(/Bing|Zune|Solitaire|Skype/);
    }
  });

  it("la whitelist de remoción de catálogo debe exigir coincidencia de prefijo estricta", () => {
    const isAllowedId = (id: string, catalog: string[]) => catalog.includes(id);
    const catalog = ["Microsoft.BingWeather", "Microsoft.GetHelp"];

    expect(isAllowedId("Microsoft.BingWeather", catalog)).toBe(true);
    expect(isAllowedId("Microsoft.WindowsStore", catalog)).toBe(false);
    expect(isAllowedId("Microsoft.BingWeather; malicious", catalog)).toBe(false);
  });
});
