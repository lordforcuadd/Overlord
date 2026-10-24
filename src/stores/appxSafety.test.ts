import { describe, it, expect } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";

describe("Reglas de Protección y Seguridad de AppX (Análisis Estático Real)", () => {
  const manageAppxPath = path.resolve(__dirname, "../../src-tauri/scripts/manage_appx.ps1");
  const debloatPath = path.resolve(__dirname, "../../src-tauri/scripts/02_debloat.ps1");

  it("los scripts reales de PowerShell deben existir en el repositorio", () => {
    expect(fs.existsSync(manageAppxPath)).toBe(true);
    expect(fs.existsSync(debloatPath)).toBe(true);
  });

  const manageAppxContent = fs.readFileSync(manageAppxPath, "utf-8");
  const debloatContent = fs.readFileSync(debloatPath, "utf-8");

  // Extraer $ProtectedIds de manage_appx.ps1
  const protectedMatch = manageAppxContent.match(/\$ProtectedIds\s*=\s*@\(([\s\S]*?)\)/);
  const protectedIds = protectedMatch
    ? [...protectedMatch[1].matchAll(/["']([^"']+)["']/g)].map((m) => m[1])
    : [];

  // Extraer catalogo completo de manage_appx.ps1
  const catalogEntries: { id: string; category: string }[] = [];
  const catalogBlocks = manageAppxContent.match(/@\{[^}]+\}/g) || [];
  for (const block of catalogBlocks) {
    const idMatch = block.match(/Id\s*=\s*["']([^"']+)["']/i);
    const catMatch = block.match(/Category\s*=\s*["']([^"']+)["']/i);
    if (idMatch && catMatch) {
      catalogEntries.push({ id: idMatch[1], category: catMatch[1].toLowerCase() });
    }
  }

  // Extraer $Apps a purgar automaticamente de 02_debloat.ps1
  const appsMatch = debloatContent.match(/\$Apps\s*=\s*@\(([\s\S]*?)\)/);
  const debloatApps = appsMatch
    ? [...appsMatch[1].matchAll(/["']([^"']+)["']/g)].map((m) => m[1])
    : [];

  it("el arreglo $ProtectedIds en manage_appx.ps1 debe blindar las aplicaciones nucleares del sistema", () => {
    expect(protectedIds.length).toBeGreaterThanOrEqual(7);

    const essentialSystemApps = [
      "Microsoft.WindowsStore",
      "Microsoft.DesktopAppInstaller",
      "Microsoft.WindowsTerminal",
      "Microsoft.WindowsCalculator",
      "Microsoft.WindowsCamera",
      "Microsoft.Paint",
      "Microsoft.WindowsNotepad",
      "Microsoft.SecHealthUI"
    ];

    for (const essentialApp of essentialSystemApps) {
      expect(protectedIds).toContain(essentialApp);
    }
  });

  it("ninguna aplicacion en $ProtectedIds debe pertenecer a categorias de bloatware o telemetria", () => {
    for (const id of protectedIds) {
      expect(id).not.toMatch(/Bing|Zune|Solitaire|Skype|Cortana|Feedback/i);
    }
  });

  it("el debloat automatico (02_debloat.ps1) NO debe tocar ninguna aplicacion protegida ni de precaucion", () => {
    expect(debloatApps.length).toBeGreaterThan(0);

    const cautionOrSystemIds = new Set(
      catalogEntries
        .filter((entry) => entry.category === "caution" || entry.category === "system")
        .map((entry) => entry.id)
    );

    for (const app of debloatApps) {
      // Ninguna app a debloatear debe ser protegida
      expect(protectedIds).not.toContain(app);
      // Ninguna app a debloatear debe estar catalogada como caution o system
      expect(cautionOrSystemIds.has(app)).toBe(false);
    }
  });

  it("todas las aplicaciones en 02_debloat.ps1 deben estar catalogadas como seguras ('safe')", () => {
    const safeCatalogIds = new Set(
      catalogEntries
        .filter((entry) => entry.category === "safe")
        .map((entry) => entry.id)
    );

    for (const app of debloatApps) {
      expect(safeCatalogIds.has(app)).toBe(true);
    }
  });
});
