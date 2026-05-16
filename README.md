<div align="center">
  <img src="overlord_icon.png" alt="Overlord Logo" width="120">
  
  # OVERLORD
  **El Optimizador Definitivo para Windows 10/11.**
  
  Construido para latencia cero, máxima estabilidad de FPS y control total del sistema, impulsado por un motor asíncrono en Rust y una interfaz premium en Vue 3.

[![Vue.js](https://img.shields.io/badge/Vue%203-35495E?style=for-the-badge&logo=vue.js&logoColor=4FC08D)](https://vuejs.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![Tauri](https://img.shields.io/badge/Tauri-FFC131?style=for-the-badge&logo=tauri&logoColor=white)](https://tauri.app/)
[![Rust](https://img.shields.io/badge/Rust-000000?style=for-the-badge&logo=rust&logoColor=white)](https://www.rust-lang.org/)

</div>

<hr>

<div align="center">
  <img src="/src/assets/overlordPanel.png" alt="Overlord UI" width="800"/>
</div>

## ¿Qué hace Overlord diferente?

A diferencia de los scripts genéricos, Overlord no rompe tu sistema. Utiliza un backend reactivo en **Rust** para inyectar configuraciones a nivel Kernel de forma segura, respetando la arquitectura de tu hardware (con inteligencia artificial básica para diferenciar Laptops de Desktops).

### Características Principales

- **Destrucción de Input Lag:** Ajusta el _Timer Resolution_, fuerza el _MSI Mode_ en periféricos y elimina curvas de aceleración para un tracking 1:1 real. Ideal para gaming competitivo (Valorant, CS2).
- **Estabilidad de Frametime (FPS):** Anula el _Multi-Plane Overlay (MPO)_ y fuerza el Modo Exclusivo de Pantalla Completa (FSO) para eliminar el micro-stuttering.
- **Panel QoL Dinámico:** Más de 15 "Quality of Life" toggles instantáneos. Erradica Copilot, Windows Recall, Telemetría profunda y Bloatware con un solo clic.
- **Motor Asíncrono:** La interfaz no se congela. Overlord ejecuta los scripts de PowerShell más pesados en hilos secundarios a través de su puente de Rust.

---

## Instalación (Usuarios Finales)

1. Ve a la sección de [Releases](https://github.com/lordforcuadd/Overlord/releases) en la barra lateral derecha.
2. Descarga el archivo `Overlord_1.0.0_setup.exe` (o `.msi`).
3. Ejecútalo como Administrador.
4. ¡Disfruta de un Windows sin cadenas!

> **Nota:** Algunos antivirus pueden lanzar un falso positivo debido a que la herramienta inyecta configuraciones directamente en el Registro de Windows (`regedit`). Overlord es 100% de código abierto.

---

## Entorno de Desarrollo

Si quieres clonar, compilar o modificar Overlord por tu cuenta:

**Prerrequisitos:**

- [Node.js](https://nodejs.org/) (v18+)
- [Rust & Cargo](https://www.rust-lang.org/tools/install)
- [C++ Build Tools para Visual Studio](https://visualstudio.microsoft.com/es/visual-cpp-build-tools/)

**Comandos:**

```bash
# Instalar dependencias
npm install

# Iniciar servidor de desarrollo con Hot-Reload (Vue + Rust)
npm run tauri dev

# Compilar el instalador final para Producción
npm run tauri build
```
