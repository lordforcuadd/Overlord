mod executor;
mod hardware;
mod memory;

use executor::execute_script_in_memory;
use hardware::{get_system_hardware, collect_installed_games, HardwareResponse, ScanGamesResponse};
use memory::{get_live_metrics, LiveMetricsResponse, SystemStateCache};
use tauri::State;
use std::net::UdpSocket;
use std::time::{Instant, Duration};
use sysinfo::System;

#[link(name = "ntdll")]
extern "system" {
    fn NtSetSystemInformation(system_information_class: u32, system_information: *mut std::ffi::c_void, system_information_length: u32) -> i32;
}

#[link(name = "advapi32")]
extern "system" {
    fn OpenProcessToken(process_handle: *mut std::ffi::c_void, desired_access: u32, token_handle: *mut *mut std::ffi::c_void) -> i32;
    fn LookupPrivilegeValueW(lp_system_name: *const u16, lp_name: *const u16, lp_luid: *mut LUID) -> i32;
    fn AdjustTokenPrivileges(token_handle: *mut std::ffi::c_void, disable_all_privileges: i32, new_state: *const TOKEN_PRIVILEGES, buffer_length: u32, previous_state: *mut TOKEN_PRIVILEGES, return_length: *mut u32) -> i32;
}

#[link(name = "kernel32")]
extern "system" {
    fn GetCurrentProcess() -> *mut std::ffi::c_void;
    fn CloseHandle(handle: *mut std::ffi::c_void) -> i32;
}

#[repr(C)]
struct LUID { low_part: u32, high_part: i32 }
#[repr(C)]
struct LUID_AND_ATTRIBUTES { luid: LUID, attributes: u32 }
#[repr(C)]
struct TOKEN_PRIVILEGES { privilege_count: u32, privileges: [LUID_AND_ATTRIBUTES; 1] }

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
fn get_live_telemetry(cache: State<'_, SystemStateCache>) -> LiveMetricsResponse {
    get_live_metrics(&cache)
}

#[tauri::command]
fn run_optimization_script(script_name: String, is_laptop: bool, ram_gb: u32, game_list: String) -> Result<String, String> {
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
        _ => return Err("Script no autorizado u omitido por seguridad".to_string()),
    };

    execute_script_in_memory(script_raw, is_laptop, ram_gb, &game_list)
}

#[tauri::command]
fn run_benchmark() -> Result<f64, String> {
    let socket = UdpSocket::bind("0.0.0.0:0").map_err(|e| e.to_string())?;
    socket.set_read_timeout(Some(Duration::from_millis(1500))).map_err(|e| e.to_string())?;
    
    let dns_packet: [u8; 28] = [
        0xAA, 0xBB, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x06, b'g', b'o', b'o',
        b'g', b'l', b'e', 0x03, b'c', b'o', b'm', 0x00,
        0x00, 0x01, 0x00, 0x01
    ];

    let start = Instant::now();
    socket.send_to(&dns_packet, "1.1.1.1:53").map_err(|e| e.to_string())?;
    
    let mut buf = [0u8; 512];
    let _ = socket.recv_from(&mut buf).map_err(|_| "Tiempo de espera de red UDP agotado".to_string())?;
    
    let duration = start.elapsed().as_secs_f64() * 1000.0;
    Ok((duration * 100.0).round() / 100.0)
}

#[tauri::command]
fn purge_ram_native() -> Result<String, String> {
    unsafe {
        let mut token: *mut std::ffi::c_void = std::ptr::null_mut();
        if OpenProcessToken(GetCurrentProcess(), 0x0020 | 0x0008, &mut token) != 0 {
            let priv_name: Vec<u16> = "SeProfileSingleProcessPrivilege\0".encode_utf16().collect();
            let mut luid = LUID { low_part: 0, high_part: 0 };
            if LookupPrivilegeValueW(std::ptr::null(), priv_name.as_ptr(), &mut luid) != 0 {
                let tp = TOKEN_PRIVILEGES {
                    privilege_count: 1,
                    privileges: [LUID_AND_ATTRIBUTES { luid, attributes: 0x00000002 }],
                };
                AdjustTokenPrivileges(token, 0, &tp, 0, std::ptr::null_mut(), std::ptr::null_mut());
            }
            CloseHandle(token);
        }

        let mut status = -1;
        for &cmd in &[4u32, 5u32] {
            let mut command_class = cmd;
            let current_status = NtSetSystemInformation(80, &mut command_class as *mut u32 as *mut std::ffi::c_void, 4);
            if current_status >= 0 {
                status = current_status;
                break;
            } else {
                status = current_status;
            }
        }

        if status >= 0 {
            Ok("Lista Standby purgada con exito".to_string())
        } else {
            Err(format!("Error en llamada al sistema NT: {}", status))
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

    tokio::spawn(async move {
        let mut sys = System::new_all();
        loop {
            sys.refresh_processes();
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
            tokio::time::sleep(Duration::from_secs(15)).await;
        }
    });

    Ok(())
}

#[cfg_attr(mobile, tauri::command)]
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
            start_game_priority_monitor 
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}