<div align="center">
  <img src="overlord_icon.png" alt="Overlord Logo" width="120">
  
  # OVERLORD
  **Sistema Avanzado de Optimización y Reducción de Latencia para Windows 10 y 11.**
  
  Una suite de ingeniería orientada al rendimiento competitivo, la depuración del sistema operativo y la reducción drástica del retraso de entrada, impulsada por un núcleo asíncrono en Rust y una interfaz fluida basada en Vue 3 y Pinia.

[![Vue.js](https://img.shields.io/badge/Vue%203-35495E?style=for-the-badge&logo=vue.js&logoColor=4FC08D)](https://vuejs.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![Tauri](https://img.shields.io/badge/Tauri-FFC131?style=for-the-badge&logo=tauri&logoColor=white)](https://tauri.app/)
[![Rust](https://img.shields.io/badge/Rust-000000?style=for-the-badge&logo=rust&logoColor=white)](https://www.rust-lang.org/)

</div>

<hr>

<div align="center">
  <img src="/src/assets/overlordPanel.png" alt="Overlord UI" width="800"/>
</div>

## Filosofía de Ingeniería y Arquitectura (Versión 2.5)

A diferencia de los scripts tradicionales distribuidos en internet, Overlord ha sido desarrollado bajo estrictos estándares de ingeniería de software. No destruye ni elimina componentes esenciales del sistema central, lo que garantiza estabilidad a largo plazo y compatibilidad con Windows Update.

### Pilares Fundamentales del Sistema

- **Modificaciones Lógicas Reversibles:** Toda la optimización se basa en interruptores booleanos y políticas oficiales del registro de Windows. El software cuenta con un motor de retorno bidireccional que restablece los valores exactos de fábrica de Microsoft en cualquier momento.
- **Puente IPC Seguro y Parametrizado:** En la versión 2.5, el backend de Rust procesa la ejecución de comandos de PowerShell de forma totalmente aislada a través de un esquema nativo parametrizado. Esto previene vulnerabilidades de inyección de código al separar de forma estricta las variables lógicas de los argumentos externos.
- **Diagnóstico de Hardware Avanzado:** Interroga directamente al controlador de memoria física y al bus PCI para obtener telemetría real en tiempo real. Detecta frecuencias de memoria RAM en MHz (con soporte XMP y EXPO), arquitecturas con múltiples tarjetas gráficas simultáneas (Setups híbridos o dedicados) y adapta los perfiles según se trate de un equipo portátil o de escritorio.
- **Purga de Memoria Nativa:** Invoca la API nativa no documentada del Kernel de Windows (`NtSetSystemInformation`) directamente desde código seguro en Rust, liberando la lista de espera de la memoria RAM de forma inmediata sin consumir ciclos de procesamiento de la CPU.

---

## Módulos de Optimización y Clasificación de Impacto

Para garantizar un uso transparente, Overlord organiza sus funciones en categorías descriptivas y asigna una clasificación de riesgo visible en la interfaz de usuario:

### 1. Clasificación: Seguro

- **Respuesta de Teclado y Ratón:** Reduce las colas de datos de los periféricos a un búfer controlado y anula las curvas dinámicas de aceleración heredadas del registro, forzando un rastreo puro uno a uno de los sensores de hardware.
- **Limpieza del Sistema (Debloat):** Desinstala aplicaciones innecesarias preinstaladas de fábrica y deshabilita tareas programadas de telemetría básica. En esta versión, se mantiene el servicio de búsqueda nativo plenamente operativo para evitar el bloqueo o la congelación de los cuadros de texto en la configuración de Windows.
- **Optimización de Internet:** Configura la ventana de recepción TCP a un nivel avanzado y desactiva algoritmos de agrupación de paquetes que provocan variaciones de ping. Estabiliza las conexiones frente a micro-cortes de red.
- **Aceleración de Almacenamiento:** Duplica la pila asignada a la caché de metadatos del sistema de archivos NTFS y bloquea el registro redundante de marcas de tiempo en el disco duro, prolongando la vida útil de las unidades de estado sólido (SSD y NVMe).

### 2. Clasificación: Avanzado

- **Potencia Bruta y Procesador:** Aplica el plan de energía oculto de rendimiento máximo, anula el estacionamiento de núcleos del procesador en equipos de escritorio y deshabilita de forma lógica las mitigaciones de seguridad de la CPU para liberar potencia de procesamiento bruto en entornos multitarea y videojuegos.
- **Fluidez de Pantalla y Gráficos:** Mitiga los fallos de sincronización y parpadeos visuales desactivando la superposición de planos múltiples en el gestor de ventanas y ajusta las prioridades de ejecución de la tarjeta gráfica.

### 3. Clasificación: Kernel

- **Organización del Procesador:** Distribuye el tráfico de interrupciones de red de hardware fuera del Núcleo 0 de la CPU para evitar la congestión del procesador principal, asignando prioridades exclusivas al subsistema multimedia.
- **Seguridad Virtual y Filtros:** Desactiva el aislamiento de integridad de código basado en virtualización. Libera recursos considerables del procesador pero restringe temporalmente herramientas que dependen de hipervisores nativos.
- **Prioridad Absoluta para Juegos:** Inyecta reglas directas en las opciones de ejecución de imágenes del registro para ejecutables específicos de deportes electrónicos, asegurando el enfoque prioritario de los hilos de la CPU cuando el juego se encuentra en primer plano.

---

## Gestión de Arquetipos de Perfiles

El sistema procesa perfiles granulares integrados en su lógica reactiva para adaptar el entorno de forma automatizada:

- **Competitivo:** Activa la suite completa de bajo nivel para obtener la mínima latencia y la máxima tasa de fotogramas por segundo estables.
- **Programador & Competitivo:** Conserva activas las directivas de seguridad virtual indispensables para entornos de desarrollo basados en contenedores aislados y máquinas virtuales, aplicando las optimizaciones de hardware restantes de forma íntegra.
- **Programador:** Maximiza el rendimiento del sistema de archivos y el procesador, optimizando los tiempos de compilación de código.
- **Home Office / Laptops:** Enfocado en la estabilidad de red y el ahorro de ciclos de escritura en disco, preservando los esquemas de ahorro térmico y la duración de la batería de los equipos portátiles.

---

## Métodos de Seguridad y Respaldo

Antes de realizar modificaciones avanzadas, el software verifica el entorno mediante su motor de respaldo integrado. Activa obligatoriamente el servicio de instantáneas de volumen y genera un punto de restauración del sistema operativo de forma previa a la ejecución de cualquier script clasificado como avanzado. En caso de inestabilidad provocada por el estado acumulado del sistema del usuario, los cambios pueden revertirse en su totalidad dejando la PC en su estado exacto de fábrica.

---

## Instalación para Usuarios Finales

1. Diríjase a la sección de **Releases** en la barra lateral derecha de este repositorio.
2. Descargue el instalador ejecutable ejecutable correspondiente a la última versión estable.
3. Haga clic derecho sobre el archivo descargado y seleccione la opción **Ejecutar como Administrador**.
4. Siga los pasos del asistente de instalación en pantalla.

> **Nota sobre seguridad:** Debido a que el software interactúa con los parámetros del registro del sistema de bajo nivel, algunas soluciones de seguridad de software estricto pueden generar alertas de falsos positivos. Overlord es un proyecto totalmente transparente y de código abierto que puede ser auditado de forma independiente.

---

## Configuración del Entorno de Desarrollo

Si desea realizar tareas de compilación, depuración o extender las funciones del software de forma local, configure su espacio de trabajo siguiendo estos lineamientos:

### Prerrequisitos de Software

- **Node.js:** Versión 18 o superior instalada de forma global.
- **Entorno Rust:** Instalación de Cargo y la cadena de herramientas estable de Rust.
- **Herramientas de Compilación de C++:** Paquetes de compilación para Visual Studio configurados en el sistema operativo.

### Comandos de Ejecución

Instale los paquetes y dependencias de la interfaz de usuario:

```bash
npm install
npm run tauri dev
npm run tauri build
```
