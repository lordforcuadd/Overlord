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
use tauri::State;
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
    get_system_hardware()
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
        execute_script_in_memory_readonly(script_raw, is_laptop, ram_gb, &game_list).await
    } else {
        execute_script_in_memory(script_raw, is_laptop, ram_gb, &game_list).await
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
    // 1. Medir latencia TCP (Tráfico de red general) de forma asíncrona
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

    // 2. Medir resolución DNS real vía UDP de forma asíncrona
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
    unsafe {
        let mut token: *mut std::ffi::c_void = std::ptr::null_mut();
        if OpenProcessToken(GetCurrentProcess(), 0x0020 | 0x0008, &raw mut token) != 0 {
            let priv_name: Vec<u16> = "SeProfileSingleProcessPrivilege\0".encode_utf16().collect();
            let mut luid = Luid { low_part: 0, high_part: 0 };
            if LookupPrivilegeValueW(std::ptr::null(), priv_name.as_ptr(), &raw mut luid) != 0 {
                let tp = TokenPrivileges {
                    privilege_count: 1,
                    privileges: [LuidAndAttributes { luid, attributes: 0x00000002 }],
                };
                AdjustTokenPrivileges(token, 0, &raw const tp, 0, std::ptr::null_mut(), std::ptr::null_mut());
            }
            CloseHandle(token);
        }
        let mut command_class = 4u32;
        let current_status = NtSetSystemInformation(80, &raw mut command_class as *mut std::ffi::c_void, 4);

        if current_status >= 0 {
            Ok("Lista Standby del sistema purgada correctamente sin afectar el Working Set activo.".to_string())
        } else {
            Err(format!("Error en llamada al sistema NT: {current_status}"))
        }
    }
}

#[tauri::command]
async fn start_game_priority_monitor(game_list_raw: String) -> Result<(), String> {
    if game_list_raw.trim().is_empty() { return Ok(()); }

    let games: Vec<String> = game_list_raw
        .split(',')
        .map(|s| s.trim().to_lowercase())
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
            loop {
                tokio::select! {
                    _ = &mut rx => {
                        // Received cancel signal, exit loop
                        break;
                    }
                    () = tokio::time::sleep(Duration::from_secs(15)) => {
                        sys.refresh_processes_specifics(
                            sysinfo::ProcessRefreshKind::new().with_exe(sysinfo::UpdateKind::OnlyIfNotSet)
                        );
                        for (pid, process) in sys.processes() {
                            let proc_name = process.name().to_lowercase();
                            if games.contains(&proc_name) {
                                unsafe {
                                    use windows_sys::Win32::System::Threading::{
                                        OpenProcess, SetPriorityClass, GetPriorityClass, HIGH_PRIORITY_CLASS, 
                                        PROCESS_SET_INFORMATION, PROCESS_QUERY_LIMITED_INFORMATION
                                    };
                                    let handle = OpenProcess(PROCESS_SET_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION, 0, pid.as_u32());
                                    if handle != 0 {
                                        if GetPriorityClass(handle) != HIGH_PRIORITY_CLASS {
                                            SetPriorityClass(handle, HIGH_PRIORITY_CLASS);
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
fn log_from_js(msg: String) {
    println!("[JS LOG]: {}", msg);
}

#[cfg_attr(mobile, tauri::command)]
#[allow(clippy::missing_panics_doc)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
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
            log_from_js
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}