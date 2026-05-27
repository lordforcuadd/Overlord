use std::os::windows::process::CommandExt;
use std::process::{Command, Stdio};
use std::io::Read;
use std::time::{Duration, Instant, SystemTime};

// Incrustación estática de toda la suite de scripts de PowerShell en el binario de Rust
const SCRIPT_01_PERIFERICOS: &str = include_str!("../scripts/01_perifericos.ps1");
const SCRIPT_02_DEBLOAT: &str = include_str!("../scripts/02_debloat.ps1");
const SCRIPT_03_RED: &str = include_str!("../scripts/03_red.ps1");
const SCRIPT_04_RENDIMIENTO: &str = include_str!("../scripts/04_rendimiento.ps1");
const SCRIPT_05_GPU_DISPLAY: &str = include_str!("../scripts/05_gpu_display.ps1");
const SCRIPT_06_IRQ_AFFINITY: &str = include_str!("../scripts/06_irq_affinity.ps1");
const SCRIPT_07_ALMACENAMIENTO: &str = include_str!("../scripts/07_almacenamiento.ps1");
const SCRIPT_08_TELEMETRIA: &str = include_str!("../scripts/08_telemetria.ps1");
const SCRIPT_09_ENERGIA: &str = include_str!("../scripts/09_energia.ps1");
const SCRIPT_10_REVERTIR: &str = include_str!("../scripts/10_revertir.ps1");
const SCRIPT_11_GAME_HOOKS: &str = include_str!("../scripts/11_game_hooks.ps1");

const SCRIPT_CREAR_RESPALDO: &str = include_str!("../scripts/crear_respaldo.ps1");
const SCRIPT_GET_MODULES_STATUS: &str = include_str!("../scripts/get_modules_status.ps1");
const SCRIPT_GET_QOL: &str = include_str!("../scripts/get_qol.ps1");
const SCRIPT_SET_QOL: &str = include_str!("../scripts/set_qol.ps1");
const SCRIPT_QUICK_ACTIONS: &str = include_str!("../scripts/quick_actions.ps1");
const SCRIPT_SHUTDOWN: &str = include_str!("../scripts/shutdown.ps1");
const SCRIPT_UTILS: &str = include_str!("../scripts/utils.ps1");

pub fn execute_script_safely(script_path: &str, args: Vec<&str>, timeout_secs: u64) -> Result<String, String> {
    let path_str = script_path.replace("\\", "/");
    
    let script_content = if path_str.contains("01_perifericos") { SCRIPT_01_PERIFERICOS }
    else if path_str.contains("02_debloat") { SCRIPT_02_DEBLOAT }
    else if path_str.contains("03_red") { SCRIPT_03_RED }
    else if path_str.contains("04_rendimiento") { SCRIPT_04_RENDIMIENTO }
    else if path_str.contains("05_gpu_display") { SCRIPT_05_GPU_DISPLAY }
    else if path_str.contains("06_irq_affinity") { SCRIPT_06_IRQ_AFFINITY }
    else if path_str.contains("07_almacenamiento") { SCRIPT_07_ALMACENAMIENTO }
    else if path_str.contains("08_telemetria") { SCRIPT_08_TELEMETRIA }
    else if path_str.contains("09_energia") { SCRIPT_09_ENERGIA }
    else if path_str.contains("10_revertir") { SCRIPT_10_REVERTIR }
    else if path_str.contains("11_game_hooks") { SCRIPT_11_GAME_HOOKS }
    else if path_str.contains("crear_respaldo") { SCRIPT_CREAR_RESPALDO }
    else if path_str.contains("get_modules_status") { SCRIPT_GET_MODULES_STATUS }
    else if path_str.contains("get_qol") { SCRIPT_GET_QOL }
    else if path_str.contains("set_qol") { SCRIPT_SET_QOL }
    else if path_str.contains("quick_actions") { SCRIPT_QUICK_ACTIONS }
    else if path_str.contains("shutdown") { SCRIPT_SHUTDOWN }
    else if path_str.contains("utils") { SCRIPT_UTILS }
    else {
        return Err(format!("Script no mapeado en la suite: {}", path_str));
    };

    // 1. Crear un directorio temporal puramente alfanumérico para evitar conflictos de tokens en PowerShell
    let timestamp = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    
    let unique_folder_name = format!("overlord_v254_{}", timestamp);
    let temp_run_dir = std::env::temp_dir().join(unique_folder_name);
    std::fs::create_dir_all(&temp_run_dir).map_err(|e| format!("Error de infraestructura temporal: {}", e))?;

    // 2. Escribir los scripts inyectándoles un BOM UTF-8 para forzar la codificación correcta en Windows
    let scripts = vec![
        ("01_perifericos.ps1", SCRIPT_01_PERIFERICOS),
        ("02_debloat.ps1", SCRIPT_02_DEBLOAT),
        ("03_red.ps1", SCRIPT_03_RED),
        ("04_rendimiento.ps1", SCRIPT_04_RENDIMIENTO),
        ("05_gpu_display.ps1", SCRIPT_05_GPU_DISPLAY),
        ("06_irq_affinity.ps1", SCRIPT_06_IRQ_AFFINITY),
        ("07_almacenamiento.ps1", SCRIPT_07_ALMACENAMIENTO),
        ("08_telemetria.ps1", SCRIPT_08_TELEMETRIA),
        ("09_energia.ps1", SCRIPT_09_ENERGIA),
        ("10_revertir.ps1", SCRIPT_10_REVERTIR),
        ("11_game_hooks.ps1", SCRIPT_11_GAME_HOOKS),
        ("crear_respaldo.ps1", SCRIPT_CREAR_RESPALDO),
        ("get_modules_status.ps1", SCRIPT_GET_MODULES_STATUS),
        ("get_qol.ps1", SCRIPT_GET_QOL),
        ("set_qol.ps1", SCRIPT_SET_QOL),
        ("quick_actions.ps1", SCRIPT_QUICK_ACTIONS),
        ("shutdown.ps1", SCRIPT_SHUTDOWN),
        ("utils.ps1", SCRIPT_UTILS),
    ];

    for (name, content) in scripts {
        let file_path = temp_run_dir.join(name);
        
        // Creamos un vector dinámico para anteponer el BOM UTF-8 (\xEF\xBB\xBF)
        let mut bom_content = Vec::with_capacity(3 + content.len());
        bom_content.extend_from_slice(b"\xEF\xBB\xBF");
        bom_content.extend_from_slice(content.as_bytes());
        let _ = std::fs::write(file_path, bom_content);
    }

    let target_name = if path_str.contains("01_perifericos") { "01_perifericos.ps1" }
    else if path_str.contains("02_debloat") { "02_debloat.ps1" }
    else if path_str.contains("03_red") { "03_red.ps1" }
    else if path_str.contains("04_rendimiento") { "04_rendimiento.ps1" }
    else if path_str.contains("05_gpu_display") { "05_gpu_display.ps1" }
    else if path_str.contains("06_irq_affinity") { "06_irq_affinity.ps1" }
    else if path_str.contains("07_almacenamiento") { "07_almacenamiento.ps1" }
    else if path_str.contains("08_telemetria") { "08_telemetria.ps1" }
    else if path_str.contains("09_energia") { "09_energia.ps1" }
    else if path_str.contains("10_revertir") { "10_revertir.ps1" }
    else if path_str.contains("11_game_hooks") { "11_game_hooks.ps1" }
    else if path_str.contains("crear_respaldo") { "crear_respaldo.ps1" }
    else if path_str.contains("get_modules_status") { "get_modules_status.ps1" }
    else if path_str.contains("get_qol") { "get_qol.ps1" }
    else if path_str.contains("set_qol") { "set_qol.ps1" }
    else if path_str.contains("quick_actions") { "quick_actions.ps1" }
    else if path_str.contains("shutdown") { "shutdown.ps1" }
    else { "utils.ps1" };

    let target_script_path = temp_run_dir.join(target_name);

    // 3. Ejecución directa e impecable usando la firma nativa original
    let mut cmd = Command::new("powershell.exe");
    cmd.creation_flags(0x08000000); // Ocultar consola
    
    cmd.arg("-NoProfile")
       .arg("-NonInteractive")
       .arg("-ExecutionPolicy")
       .arg("Bypass")
       .arg("-File")
       .arg(&target_script_path);

    for arg in args {
        if !arg.is_empty() {
            cmd.arg(arg);
        }
    }

    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());

    let mut child = cmd.spawn().map_err(|e| {
        let _ = std::fs::remove_dir_all(&temp_run_dir);
        format!("Fallo al inicializar subproceso: {}", e)
    })?;

    let start_time = Instant::now();
    let timeout = Duration::from_secs(timeout_secs);
    let mut final_result = Err("Proceso terminado inesperadamente".to_string());

    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                if status.success() {
                    let mut stdout_str = String::new();
                    if let Some(mut stdout) = child.stdout.take() {
                        let _ = stdout.read_to_string(&mut stdout_str);
                    }
                    final_result = Ok(stdout_str.trim().to_string());
                } else {
                    let mut stderr_str = String::new();
                    if let Some(mut stderr) = child.stderr.take() {
                        let _ = stderr.read_to_string(&mut stderr_str);
                    }
                    final_result = Err(format!("Error de script: {}. Código: {:?}", stderr_str.trim(), status.code()));
                }
                break;
            }
            Ok(None) => {
                if start_time.elapsed() >= timeout {
                    let _ = child.kill();
                    final_result = Err(format!("Excedido el límite de tiempo de seguridad de {} segundos", timeout_secs));
                    break;
                }
                std::thread::sleep(Duration::from_millis(50));
            }
            Err(e) => {
                final_result = Err(format!("Excepción durante el monitoreo del proceso: {}", e));
                break;
            }
        }
    }

    // 4. Purga física total de la carpeta transitoria al finalizar la ejecución del hilo
    let _ = std::fs::remove_dir_all(&temp_run_dir);

    final_result
}