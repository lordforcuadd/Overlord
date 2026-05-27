use std::os::windows::process::CommandExt;
use std::collections::HashMap;
use hardware::{HardwareResponse, ScanGamesResponse};
use memory::LiveTelemetryResponse;

mod hardware;
mod memory;
mod executor;

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
async fn purge_ram_native() -> Result<String, String> {
    let mut cmd = std::process::Command::new("powershell.exe");
    cmd.creation_flags(0x08000000);
    cmd.args(&[
        "-NoProfile",
        "-Command",
        "[System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers();"
    ]);
    let _ = cmd.status();
    Ok("RAM Purgada Nativamente".to_string())
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
async fn run_optimization(_modules: HashMap<String, bool>, _is_laptop: bool, _ram_gb: u32) -> Result<String, String> {
    Ok("Logica unificada".to_string())
}

#[tauri::command]
async fn revert_optimization(is_laptop: bool, ram_gb: u32) -> Result<String, String> {
    let laptop_str = if is_laptop { "true" } else { "false" };
    let ram_str = ram_gb.to_string();
    let args = vec![laptop_str, &ram_str, ""];
    executor::execute_script_safely("scripts\\10_revertir.ps1", args, 300)
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
            revert_optimization
        ])
        .run(tauri::generate_context!())
        .expect("Error al compilar la ejecucion nativa de Overlord");
}