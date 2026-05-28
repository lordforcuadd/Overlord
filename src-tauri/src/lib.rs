use std::collections::HashMap;
use hardware::{HardwareResponse, ScanGamesResponse};
use memory::LiveTelemetryResponse;
use std::time::Instant;
use std::net::{TcpStream, ToSocketAddrs};

mod hardware;
mod memory;
mod executor;

extern "system" {
    fn OpenProcess(dwDesiredAccess: u32, bInheritHandle: i32, dwProcessId: u32) -> *mut std::ffi::c_void;
    fn SetProcessWorkingSetSize(hProcess: *mut std::ffi::c_void, dwMinimumWorkingSetSize: usize, dwMaximumWorkingSetSize: usize) -> i32;
    fn CloseHandle(hObject: *mut std::ffi::c_void) -> i32;
}

#[tauri::command]
async fn get_hardware_info() -> Result<HardwareResponse, String> {
    Ok(hardware::get_system_hardware())
}

#[tauri::command]
async fn get_live_telemetry() -> Result<LiveTelemetryResponse, String> {
    Ok(memory::fetch_live_metrics())
}

#[tauri::command]
async fn scan_games() -> Result<Vec<ScanGamesResponse>, String> {
    Ok(hardware::collect_installed_games())
}

#[tauri::command]
async fn check_backup_exists() -> bool {
    let hklm = winreg::RegKey::predef(winreg::enums::HKEY_LOCAL_MACHINE);
    hklm.open_subkey("SOFTWARE\\Overlord\\Backup").is_ok()
}

#[tauri::command]
async fn purge_ram_native() -> Result<String, String> {
    
    let mut sys = sysinfo::System::new_all();
    sys.refresh_all();
    
    let mut procesos_purgados = 0;

    unsafe {
        for process in sys.processes().values() {
            let pid = process.pid().as_u32();
            
            let handle = OpenProcess(0x0100 | 0x0400, 0, pid);
            if !handle.is_null() {
                
                if SetProcessWorkingSetSize(handle, usize::MAX, usize::MAX) != 0 {
                    procesos_purgados += 1;
                }
                CloseHandle(handle);
            }
        }
    }

    Ok(format!("RAM Purgada de forma nativa. Conjuntos de trabajo optimizados en {} procesos.", procesos_purgados))
}

#[tauri::command]
async fn run_powershell_async(
    script_name: String,
    is_laptop: bool,
    ram_gb: u32,
    game_list: Option<String>,
) -> Result<String, String> {
    let path = format!("scripts\\{}", script_name);
    let laptop_str = if is_laptop { "true" } else { "false" };
    let ram_str = ram_gb.to_string();
    let games = game_list.unwrap_or_default();

    let args = vec![laptop_str, &ram_str, &games];
    executor::execute_script_safely(&path, args, 120)
}

#[tauri::command]
async fn run_powershell_generic(script_name: String, args_list: Vec<String>) -> Result<String, String> {
    let path = format!("scripts\\{}", script_name);
    let args_ref: Vec<&str> = args_list.iter().map(|s| s.as_str()).collect();
    
    let timeout = if script_name.contains("crear_respaldo") { 600 } else { 180 };
    executor::execute_script_safely(&path, args_ref, timeout)
}

#[tauri::command]
async fn run_optimization(modules: HashMap<String, bool>, is_laptop: bool, ram_gb: u32) -> Result<String, String> {
    let mut modulos_aplicados = Vec::new();
    
    for (module_name, should_execute) in modules {
        if should_execute {
            let path = format!("scripts\\{}", module_name);
           let laptop_str = is_laptop.to_string();
           let ram_str = ram_gb.to_string();
           let args = vec![laptop_str.as_ref(), ram_str.as_ref(), ""];
            
            match executor::execute_script_safely(&path, args, 120) {
                Ok(_) => modulos_aplicados.push(module_name),
                Err(e) => return Err(format!("Fallo crítico en módulo {}: {}", module_name, e)),
            }
        }
    }
    
    Ok(format!("Optimización completada con éxito: {}", modulos_aplicados.join(", ")))
}

#[tauri::command]
async fn revert_optimization(is_laptop: bool, ram_gb: u32) -> Result<String, String> {
    let laptop_str = if is_laptop { "true" } else { "false" };
    let ram_str = ram_gb.to_string();
    let args = vec![laptop_str, &ram_str, ""];
    executor::execute_script_safely("scripts\\10_revertir.ps1", args, 300)
}

#[derive(serde::Serialize)]
pub struct BenchmarkResult {
    pub network_latency_ms: u32,
    pub dns_resolution_ms: u32,
}

#[tauri::command]
async fn run_benchmark() -> Result<BenchmarkResult, String> {
    let dns_start = Instant::now();
    let socket_addr = match "one.one.one.one:53".to_socket_addrs() {
        Ok(mut addrs) => addrs.next(),
        Err(_) => return Err("Error al resolver el nombre de dominio del servidor de prueba".to_string()),
    };
    let dns_resolution_ms = dns_start.elapsed().as_millis() as u32;

    let addr = match socket_addr {
        Some(a) => a,
        None => return Err("No se encontraron direcciones validas para el servidor de prueba".to_string()),
    };

    let net_start = Instant::now();
    
    match TcpStream::connect_timeout(&addr, std::time::Duration::from_secs(3)) {
        Ok(_) => {
            let network_latency_ms = net_start.elapsed().as_millis() as u32;
            Ok(BenchmarkResult {
                network_latency_ms,
                dns_resolution_ms,
            })
        }
        Err(_) => {
            Err("El servidor de prueba no respondio dentro del tiempo limite establecido".to_string())
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_log::Builder::new().build())
        .invoke_handler(tauri::generate_handler![
            get_hardware_info,
            get_live_telemetry,
            scan_games,
            purge_ram_native,
            run_powershell_async,
            run_powershell_generic,
            run_optimization,
            revert_optimization,
            run_benchmark,
            check_backup_exists
        ])
        .run(tauri::generate_context!())
        .expect("Error al compilar la ejecucion nativa de Overlord");
}