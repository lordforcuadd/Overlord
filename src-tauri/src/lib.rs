#![allow(
    clippy::unreadable_literal,
    clippy::too_many_lines,
    clippy::redundant_closure_for_method_calls,
    clippy::explicit_iter_loop,
    clippy::unnecessary_map_or,
    clippy::borrow_as_ptr,
    clippy::ptr_as_ptr,
    clippy::cast_precision_loss,
    clippy::cast_possible_truncation,
    clippy::cast_lossless,
    clippy::wildcard_imports,
    clippy::struct_excessive_bools,
    clippy::map_unwrap_or,
    clippy::uninlined_format_args,
    clippy::cast_sign_loss,
    clippy::needless_borrows_for_generic_args,
    clippy::ref_as_ptr,
    clippy::single_char_pattern,
    clippy::manual_div_ceil
)]
mod executor;
mod hardware;
mod memory;

use executor::{execute_script_in_memory, execute_script_in_memory_readonly};
use hardware::{get_system_hardware, collect_installed_games, HardwareResponse, ScanGamesResponse};
use memory::{get_live_metrics, LiveMetricsResponse, SystemStateCache};
use tauri::{State, Manager};
use std::time::{Instant, Duration};
use sysinfo::System;
use std::sync::Mutex;
use tokio::sync::oneshot;

static MONITOR_CANCELLER: Mutex<Option<oneshot::Sender<()>>> = Mutex::new(None);

#[link(name = "ntdll")]
extern "system" {
    fn NtSetSystemInformation(system_information_class: u32, system_information: *mut std::ffi::c_void, system_information_length: u32) -> i32;
}

#[link(name = "advapi32")]
extern "system" {
    fn OpenProcessToken(process_handle: *mut std::ffi::c_void, desired_access: u32, token_handle: *mut *mut std::ffi::c_void) -> i32;
    fn LookupPrivilegeValueW(lp_system_name: *const u16, lp_name: *const u16, lp_luid: *mut Luid) -> i32;
    fn AdjustTokenPrivileges(token_handle: *mut std::ffi::c_void, disable_all_privileges: i32, new_state: *const TokenPrivileges, buffer_length: u32, previous_state: *mut TokenPrivileges, return_length: *mut u32) -> i32;
}

#[link(name = "kernel32")]
extern "system" {
    fn GetCurrentProcess() -> *mut std::ffi::c_void;
    fn CloseHandle(handle: *mut std::ffi::c_void) -> i32;
}

#[repr(C)]
struct Luid { low_part: u32, high_part: i32 }
#[repr(C)]
struct LuidAndAttributes { luid: Luid, attributes: u32 }
#[repr(C)]
struct TokenPrivileges { privilege_count: u32, privileges: [LuidAndAttributes; 1] }

#[tauri::command]
fn check_backup_exists() -> bool {
    let hklm = winreg::RegKey::predef(winreg::enums::HKEY_LOCAL_MACHINE);
    hklm.open_subkey("SOFTWARE\\Overlord\\Backup").is_ok()
}

#[tauri::command]
async fn fetch_hardware() -> HardwareResponse {
    get_system_hardware().await
}

#[tauri::command]
async fn fetch_games() -> Vec<ScanGamesResponse> {
    collect_installed_games()
}

#[tauri::command]
#[allow(clippy::needless_pass_by_value)]
fn get_live_telemetry(cache: State<'_, SystemStateCache>) -> LiveMetricsResponse {
    get_live_metrics(&cache)
}

#[tauri::command]
async fn run_optimization_script(script_name: String, is_laptop: bool, ram_gb: u32, game_list: String) -> Result<String, String> {
    let hw = get_system_hardware().await;
    let is_hybrid = hw.is_hybrid;
    let is_x3d = hw.is_x3d;
    let is_ssd = hw.is_ssd;

    let script_raw = match script_name.as_str() {
        "01_perifericos" => include_str!("../scripts/01_perifericos.ps1"),
        "02_debloat" => include_str!("../scripts/02_debloat.ps1"),
        "03_red" => include_str!("../scripts/03_red.ps1"),
        "04_rendimiento" => include_str!("../scripts/04_rendimiento.ps1"),
        "05_gpu_display" => include_str!("../scripts/05_gpu_display.ps1"),
        "06_irq_affinity" => include_str!("../scripts/06_irq_affinity.ps1"),
        "07_almacenamiento" => include_str!("../scripts/07_almacenamiento.ps1"),
        "08_telemetria" => include_str!("../scripts/08_telemetria.ps1"),
        "09_energia" => include_str!("../scripts/09_energia.ps1"),
        "10_revertir" => include_str!("../scripts/10_revertir.ps1"),
        "11_game_hooks" => include_str!("../scripts/11_game_hooks.ps1"),
        "crear_respaldo" => include_str!("../scripts/crear_respaldo.ps1"),
        "quick_actions" => include_str!("../scripts/quick_actions.ps1"),
        "set_qol" => include_str!("../scripts/set_qol.ps1"),
        "get_qol" => include_str!("../scripts/get_qol.ps1"),
        "shutdown" => include_str!("../scripts/shutdown.ps1"),
        "get_modules_status" => include_str!("../scripts/get_modules_status.ps1"),
        "disable_mitigations" => include_str!("../scripts/disable_mitigations.ps1"),
        "manage_priority_service" => include_str!("../scripts/manage_priority_service.ps1"),
        _ => return Err("Script no autorizado u omitido por seguridad".to_string()),
    };

    let is_readonly = match script_name.as_str() {
        "get_qol" | "get_modules_status" => true,
        "manage_priority_service" => game_list.starts_with("status:"),
        _ => false,
    };

    if is_readonly {
        execute_script_in_memory_readonly(&script_name, script_raw, is_laptop, ram_gb, &game_list, is_hybrid, is_x3d, is_ssd).await
    } else {
        execute_script_in_memory(&script_name, script_raw, is_laptop, ram_gb, &game_list, is_hybrid, is_x3d, is_ssd).await
    }
}

#[derive(serde::Serialize)]
pub struct BenchmarkResponse {
    #[serde(rename = "tcp_latency")]
    pub tcp_latency: f64,
    #[serde(rename = "dns_latency")]
    pub dns_latency: f64,
}

#[tauri::command]
async fn run_benchmark() -> Result<BenchmarkResponse, String> {
    // 1. Medir latencia TCP (Tráfico de red general) de forma asíncrona.
    // Se utiliza el puerto 80 del servidor DNS público de Cloudflare (1.1.1.1)
    // para medir la latencia de establecimiento de conexión TCP pura de red.
    let start_tcp = Instant::now();
    let addr = "1.1.1.1:80".parse::<std::net::SocketAddr>().unwrap();
    let tcp_res = tokio::time::timeout(
        Duration::from_millis(1500),
        tokio::net::TcpStream::connect(addr)
    ).await;
    
    let tcp_latency = match tcp_res {
        Ok(Ok(_)) => start_tcp.elapsed().as_secs_f64() * 1000.0,
        _ => 1500.0, // Timeout o fallo de red
    };

    // 2. Medir resolución DNS real vía UDP de forma asíncrona.
    // Se realiza una consulta DNS UDP al puerto 53 del mismo servidor (1.1.1.1)
    // para evaluar la latencia específica de resolución de nombres de dominio.
    let socket = tokio::net::UdpSocket::bind("0.0.0.0:0").await.map_err(|e| e.to_string())?;
    let dns_packet: [u8; 28] = [
        0xAA, 0xBB, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x06, b'g', b'o', b'o',
        b'g', b'l', b'e', 0x03, b'c', b'o', b'm', 0x00,
        0x00, 0x01, 0x00, 0x01
    ];

    let start_dns = Instant::now();
    let send_res = socket.send_to(&dns_packet, "1.1.1.1:53").await;
    
    let dns_latency = match send_res {
        Ok(_) => {
            let mut buf = [0u8; 512];
            let recv_res = tokio::time::timeout(
                Duration::from_millis(1500),
                socket.recv_from(&mut buf)
            ).await;
            
            match recv_res {
                Ok(Ok(_)) => start_dns.elapsed().as_secs_f64() * 1000.0,
                _ => 1500.0, // Timeout o error de lectura UDP
            }
        }
        Err(_) => 1500.0, // Error al enviar
    };
    
    Ok(BenchmarkResponse {
        tcp_latency: (tcp_latency * 100.0).round() / 100.0,
        dns_latency: (dns_latency * 100.0).round() / 100.0,
    })
}

#[tauri::command]
fn purge_ram_native() -> Result<String, String> {
    // Verificación dinámica de la versión de build de Windows.
    // La clase SystemMemoryListInformation (80) y la acción MemoryPurgeStandbyList (4)
    // fueron introducidas en Windows Vista / Server 2008. Validamos Build >= 7600 (Windows 7+)
    // para mitigar riesgos de comportamiento indefinido en colmenas legacy.
    let hklm = winreg::RegKey::predef(winreg::enums::HKEY_LOCAL_MACHINE);
    if let Ok(key) = hklm.open_subkey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion") {
        if let Ok(build_str) = key.get_value::<String, _>("CurrentBuild") {
            if let Ok(build_num) = build_str.parse::<u32>() {
                if build_num < 7600 {
                    return Err("La purga nativa de RAM requiere Windows 7 o superior (Build >= 7600)".to_string());
                }
            }
        }
    }

    unsafe {
        let mut token: *mut std::ffi::c_void = std::ptr::null_mut();
        // Habilitar acceso de consulta y ajuste de privilegios en el token del proceso actual
        if OpenProcessToken(GetCurrentProcess(), 0x0020 | 0x0008, &raw mut token) == 0 {
            let err = std::io::Error::last_os_error();
            eprintln!("[OVERLORD ERROR] OpenProcessToken failed: {}", err);
            return Err(format!("No se pudo abrir el token del proceso: {}", err));
        }
        
        // Se requiere el privilegio SeProfileSingleProcessPrivilege para poder invocar NtSetSystemInformation
        // con clases de información de memoria de sistema (como SystemMemoryListInformation).
        let priv_name: Vec<u16> = "SeProfileSingleProcessPrivilege\0".encode_utf16().collect();
        let mut luid = Luid { low_part: 0, high_part: 0 };
        if LookupPrivilegeValueW(std::ptr::null(), priv_name.as_ptr(), &raw mut luid) == 0 {
            let err = std::io::Error::last_os_error();
            eprintln!("[OVERLORD ERROR] LookupPrivilegeValueW failed: {}", err);
            CloseHandle(token);
            return Err(format!("No se pudo obtener LUID para el privilegio: {}", err));
        }
        
        let tp = TokenPrivileges {
            privilege_count: 1,
            privileges: [LuidAndAttributes { luid, attributes: 0x00000002 }], // 0x00000002 = SE_PRIVILEGE_ENABLED
        };
        if AdjustTokenPrivileges(token, 0, &raw const tp, 0, std::ptr::null_mut(), std::ptr::null_mut()) == 0 {
            let err = std::io::Error::last_os_error();
            eprintln!("[OVERLORD ERROR] AdjustTokenPrivileges failed: {}", err);
            CloseHandle(token);
            return Err(format!("No se pudieron ajustar privilegios del token: {}", err));
        }
        CloseHandle(token);
        
        // DOCUMENTACIÓN TÉCNICA DE REVERSING (Origen: ReactOS / Geoff Chappell NT API Research):
        // * Clase 80 = SystemMemoryListInformation (Clase indocumentada de Windows NT)
        // * command_class = 4 = MemoryPurgeStandbyList (Purga la lista de stand-by sin vaciar sets de trabajo)
        // Este valor se pasa al buffer de entrada de NtSetSystemInformation con un tamaño de 4 bytes.
        let mut command_class = 4u32;
        let current_status = NtSetSystemInformation(80, &raw mut command_class as *mut std::ffi::c_void, 4);

        if current_status >= 0 {
            Ok("Lista Standby del sistema purgada correctamente sin afectar el Working Set activo.".to_string())
        } else {
            let status_hex = format!("0x{:08X}", current_status as u32);
            eprintln!("[OVERLORD ERROR] NtSetSystemInformation failed (status {}): {}", status_hex, current_status);
            Err(format!("Error en llamada al sistema NT (NTSTATUS {}): {}", status_hex, current_status))
        }
    }
}

#[tauri::command]
async fn start_game_priority_monitor(game_list_raw: String) -> Result<(), String> {
    if game_list_raw.trim().is_empty() { return Ok(()); }

    // Evitar iniciar el monitor redundante si el daemon de Scheduled Task de PowerShell ya está instalado
    let hklm = winreg::RegKey::predef(winreg::enums::HKEY_LOCAL_MACHINE);
    if hklm.open_subkey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Schedule\\TaskCache\\Tree\\OverlordPriorityMonitor").is_ok() {
        println!("[RUST MONITOR]: Daemon de prioridad (Scheduled Task) activo. Se omite el monitor redundante de Rust.");
        return Ok(());
    }

    let games: Vec<String> = game_list_raw
        .split(',')
        .map(|s| {
            let clean = s.trim().to_lowercase();
            if clean.ends_with(".exe") {
                clean[..clean.len() - 4].to_string()
            } else {
                clean
            }
        })
        .filter(|s| !s.is_empty())
        .collect();

    // Cancel dynamic game monitor if it is already running
    {
        let mut guard = MONITOR_CANCELLER.lock().map_err(|e| e.to_string())?;
        if let Some(tx) = guard.take() {
            let _ = tx.send(()); // Tell the old loop to stop
        }
        
        let (tx, mut rx) = oneshot::channel::<()>();
        *guard = Some(tx);
        
        tokio::spawn(async move {
            let mut sys = System::new_all();
            let mut check_counter: u32 = 0;
            loop {
                tokio::select! {
                    _ = &mut rx => {
                        // Received cancel signal, exit loop
                        break;
                    }
                    () = tokio::time::sleep(Duration::from_secs(15)) => {
                        // Evitar continuar ejecutándose si el daemon de Scheduled Task de PowerShell se activó
                        if check_counter % 20 == 0 {
                            let hklm = winreg::RegKey::predef(winreg::enums::HKEY_LOCAL_MACHINE);
                            if hklm.open_subkey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Schedule\\TaskCache\\Tree\\OverlordPriorityMonitor").is_ok() {
                                println!("[RUST MONITOR]: Daemon de prioridad (Scheduled Task) activo detectado en ejecución. Se detiene el monitor dinámico de Rust.");
                                break;
                            }
                        }
                        check_counter = check_counter.wrapping_add(1);

                        sys.refresh_processes_specifics(
                            sysinfo::ProcessRefreshKind::new().with_exe(sysinfo::UpdateKind::OnlyIfNotSet)
                        );
                        for (pid, process) in sys.processes() {
                            let mut proc_name = process.name().to_lowercase();
                            if proc_name.ends_with(".exe") {
                                proc_name = proc_name[..proc_name.len() - 4].to_string();
                            }
                            if games.contains(&proc_name) {
                                unsafe {
                                    use windows_sys::Win32::System::Threading::{
                                        OpenProcess, SetPriorityClass, GetPriorityClass, HIGH_PRIORITY_CLASS, 
                                        PROCESS_SET_INFORMATION, PROCESS_QUERY_LIMITED_INFORMATION
                                    };
                                    let handle = OpenProcess(PROCESS_SET_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION, 0, pid.as_u32());
                                    if handle != 0 {
                                        if GetPriorityClass(handle) != HIGH_PRIORITY_CLASS && SetPriorityClass(handle, HIGH_PRIORITY_CLASS) == 0 {
                                            let err = std::io::Error::last_os_error();
                                            eprintln!("[OVERLORD WARNING] SetPriorityClass falló para PID {}: {}", pid.as_u32(), err);
                                        }
                                        windows_sys::Win32::Foundation::CloseHandle(handle);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        });
    }

    Ok(())
}

#[tauri::command]
fn stop_game_priority_monitor() -> Result<(), String> {
    let mut guard = MONITOR_CANCELLER.lock().map_err(|e| e.to_string())?;
    if let Some(tx) = guard.take() {
        let _ = tx.send(());
        println!("[RUST MONITOR]: Hilo dinámico de prioridad detenido.");
    }
    Ok(())
}

#[tauri::command]
fn log_from_js(msg: String) {
    println!("[JS LOG]: {}", msg);
    let program_data = std::env::var("ProgramData").unwrap_or_else(|_| "C:\\ProgramData".to_string());
    let log_path = std::path::Path::new(&program_data).join("OverlordSuite").join("logs").join("overlord_errors.log");
    if let Some(parent) = log_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(metadata) = std::fs::metadata(&log_path) {
        if metadata.len() > 100_000 {
            let _ = std::fs::remove_file(&log_path);
        }
    }
    if let Ok(mut file) = std::fs::OpenOptions::new().create(true).append(true).open(&log_path) {
        use std::io::Write;
        let _ = writeln!(file, "{}", msg);
    }
}

#[cfg_attr(mobile, tauri::command)]
#[allow(clippy::missing_panics_doc)]
pub fn run() {
    // Configurar custom panic hook para registrar pánicos nativos de Rust
    std::panic::set_hook(Box::new(|info| {
        let msg = format!("RUST PANIC: {:?}", info);
        eprintln!("{}", msg);
        let program_data = std::env::var("ProgramData").unwrap_or_else(|_| "C:\\ProgramData".to_string());
        let log_path = std::path::Path::new(&program_data).join("OverlordSuite").join("logs").join("overlord_errors.log");
        if let Some(parent) = log_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        if let Ok(metadata) = std::fs::metadata(&log_path) {
            if metadata.len() > 100_000 {
                let _ = std::fs::remove_file(&log_path);
            }
        }
        if let Ok(mut file) = std::fs::OpenOptions::new().create(true).append(true).open(&log_path) {
            use std::io::Write;
            let _ = writeln!(file, "{}", msg);
        }
    }));

    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            // Si el usuario abre otra instancia, la enfocamos
            let _ = app.get_webview_window("main").map(|w| {
                let _ = w.show();
                let _ = w.set_focus();
            });
        }))
        .manage(SystemStateCache::default())
        .invoke_handler(tauri::generate_handler![
            check_backup_exists,
            fetch_hardware,
            fetch_games,
            get_live_telemetry,
            run_optimization_script,
            run_benchmark,
            purge_ram_native,
            start_game_priority_monitor,
            stop_game_priority_monitor,
            log_from_js
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}