use serde::{Deserialize, Serialize};
use std::os::windows::process::CommandExt;
use std::process::Command;
use std::sync::Mutex;
use sysinfo::System;
use tauri::Manager;

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[derive(Serialize, Deserialize)]
struct HardwareData {
    cpu: String,
    gpu: String,
    ram_gb: u32,
    ram_speed: u32,
    motherboard: String,
    is_laptop: bool,
}

#[tauri::command]
fn get_hardware_info() -> Result<HardwareData, String> {
    use winreg::enums::*;
    use winreg::RegKey;
    const CREATE_NO_WINDOW: u32 = 0x08000000;

    // 1. CPU y Placa Madre (Directo del Registro de Windows - Cero Latencia)
    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);

    let cpu = hklm.open_subkey("HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0")
        .and_then(|k| k.get_value::<String, _>("ProcessorNameString"))
        .unwrap_or_else(|_| "CPU Desconocido".to_string())
        .trim().to_string();

    let manufacturer = hklm.open_subkey("HARDWARE\\DESCRIPTION\\System\\BIOS")
        .and_then(|k| k.get_value::<String, _>("BaseBoardManufacturer"))
        .unwrap_or_else(|_| "".to_string());
        
    let product = hklm.open_subkey("HARDWARE\\DESCRIPTION\\System\\BIOS")
        .and_then(|k| k.get_value::<String, _>("BaseBoardProduct"))
        .unwrap_or_else(|_| "Placa Desconocida".to_string());
        
    let motherboard = format!("{} {}", manufacturer, product).trim().to_string();

    // 2. RAM (Sysinfo es perfecto para esto)
    let mut sys = System::new_all();
    sys.refresh_memory();
    let ram_gb = (sys.total_memory() as f64 / 1_073_741_824.0).round() as u32;

    // 3. GPU y Chasis (Script PowerShell Combinado - Reemplazando wmic)
    let ps_script = r#"
        $ErrorActionPreference = 'SilentlyContinue'
        $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
        $chassis = (Get-CimInstance Win32_SystemEnclosure | Select-Object -First 1).ChassisTypes[0]
        Write-Output "$gpu|$chassis"
    "#;
    
    let output = Command::new("powershell")
        .creation_flags(CREATE_NO_WINDOW)
        .args(&["-NoProfile", "-Command", ps_script])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "GPU Desconocida|3".to_string());

    // Separar los datos
    let parts: Vec<&str> = output.split('|').collect();
    let gpu = parts.first().unwrap_or(&"GPU Desconocida").trim().to_string();
    let chassis_str = parts.get(1).unwrap_or(&"3").trim();
    let chassis_int: u32 = chassis_str.parse().unwrap_or(3);
    
    // Identificadores universales de Laptops
    let is_laptop = matches!(chassis_int, 8 | 9 | 10 | 11 | 14 | 30 | 31);

    Ok(HardwareData {
        cpu,
        gpu,
        ram_gb,
        ram_speed: 0,
        motherboard,
        is_laptop
    })
}

#[derive(Serialize, Deserialize)]
struct GameDetected {
    name: String,
    exe: String,
    detected: bool,
}

#[tauri::command]
fn scan_games() -> Result<Vec<GameDetected>, String> {
    use winreg::enums::*;
    use winreg::RegKey;

    let target_games = vec![
        ("League of Legends", "League of Legends.exe"),
        ("Valorant", "VALORANT-Win64-Shipping.exe"),
        ("Counter-Strike 2", "cs2.exe"),
        ("Fortnite", "FortniteClient-Win64-Shipping.exe"),
        ("Apex Legends", "r5apex.exe"),
        ("Overwatch", "Overwatch.exe"),
    ];

    let mut installed_display_names = Vec::new();

    let paths = [
        (RegKey::predef(HKEY_LOCAL_MACHINE), "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"),
        (RegKey::predef(HKEY_LOCAL_MACHINE), "SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"),
        (RegKey::predef(HKEY_CURRENT_USER), "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"),
    ];

    for (base_key, path) in &paths {
        if let Ok(uninstall_key) = base_key.open_subkey(path) {
            for key_name in uninstall_key.enum_keys().filter_map(|k| k.ok()) {
                if let Ok(app_key) = uninstall_key.open_subkey(&key_name) {
                    if let Ok(display_name) = app_key.get_value::<String, _>("DisplayName") {
                        installed_display_names.push(display_name);
                    }
                }
            }
        }
    }

    let mut results = Vec::new();
    for (name, exe) in target_games {
        let detected = installed_display_names.iter().any(|d| d.contains(name));
        results.push(GameDetected {
            name: name.to_string(),
            exe: exe.to_string(),
            detected,
        });
    }

    Ok(results)
}

#[derive(Serialize, Deserialize)]
struct TelemetryData {
    cpu_usage: f32,
    ram_used_gb: f32,
    ram_total_gb: f32,
    ram_percent: f32,
}

pub struct AppState {
    pub sys: Mutex<System>,
}

#[tauri::command]
fn get_live_telemetry(state: tauri::State<AppState>) -> TelemetryData {
    let mut sys = state.sys.lock().unwrap();

    sys.refresh_cpu_usage();
    sys.refresh_memory();

    let cpu_usage = sys.global_cpu_info().cpu_usage();
    let used_bytes = sys.used_memory() as f32;
    let total_bytes = sys.total_memory() as f32;

    let ram_used_gb = used_bytes / 1024.0 / 1024.0 / 1024.0;
    let ram_total_gb = total_bytes / 1024.0 / 1024.0 / 1024.0;
    let ram_percent = if total_bytes > 0.0 {
        (used_bytes / total_bytes) * 100.0
    } else {
        0.0
    };

    TelemetryData {
        cpu_usage,
        ram_used_gb,
        ram_total_gb,
        ram_percent,
    }
}

#[tauri::command]
async fn run_powershell_async(
    script_name: String,
    is_laptop: bool,
    ram_gb: u32,
    game_list: Option<String>,
    app_handle: tauri::AppHandle
) -> Result<String, String> {
    const CREATE_NO_WINDOW: u32 = 0x08000000;

    if script_name == "shutdown" {
        let output = Command::new("shutdown")
            .creation_flags(CREATE_NO_WINDOW)
            .args(&["/r", "/t", "0"])
            .output()
            .map_err(|e| e.to_string())?;
        return Ok(String::from_utf8_lossy(&output.stdout).to_string());
    }

    if script_name.contains("/") || script_name.contains("\\") || script_name.contains("..") {
        return Err("Intento de ejecución no autorizado bloqueado.".into());
    }

    let resource_path = app_handle.path().resolve(
        format!("scripts/{}", script_name),
        tauri::path::BaseDirectory::Resource
    ).map_err(|e| e.to_string())?;

    let absolute_script_path = resource_path.to_string_lossy().to_string();

    let mut args = vec![
        "-NoLogo".to_string(),
        "-NoProfile".to_string(),
        "-ExecutionPolicy".to_string(),
        "Bypass".to_string(),
        "-File".to_string(),
        absolute_script_path,
        "-IsLaptop".to_string(),
        format!("${}", is_laptop),
        "-RamGB".to_string(),
        ram_gb.to_string(),
    ];

    if let Some(games) = game_list {
        if !games.is_empty() {
            args.push("-GameList".to_string());
            args.push(games);
        }
    }

    let output = Command::new("powershell")
        .creation_flags(CREATE_NO_WINDOW)
        .args(&args)
        .output()
        .map_err(|e| e.to_string())?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[tauri::command]
async fn run_powershell_generic(
    script_name: String,
    args_list: Vec<String>,
    app_handle: tauri::AppHandle
) -> Result<String, String> {
    const CREATE_NO_WINDOW: u32 = 0x08000000;
    
    if script_name.contains("/") || script_name.contains("\\") || script_name.contains("..") {
        return Err("Intento de ejecución no autorizado bloqueado.".into());
    }

    let resource_path = app_handle.path().resolve(
        format!("scripts/{}", script_name),
        tauri::path::BaseDirectory::Resource
    ).map_err(|e| e.to_string())?;

    let absolute_script_path = resource_path.to_string_lossy().to_string();

    let mut ps_args = vec![
        "-NoLogo".to_string(),
        "-NoProfile".to_string(),
        "-ExecutionPolicy".to_string(),
        "Bypass".to_string(),
        "-File".to_string(),
        absolute_script_path,
    ];
    
    ps_args.extend(args_list);

    let output = Command::new("powershell")
        .creation_flags(CREATE_NO_WINDOW)
        .args(&ps_args)
        .output()
        .map_err(|e| e.to_string())?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            let _ = app.get_webview_window("main").expect("no main window").set_focus();
        }))
        .manage(AppState { sys: Mutex::new(System::new_all()) }) 
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_log::Builder::new().build())
        .invoke_handler(tauri::generate_handler![
            greet, 
            get_hardware_info, 
            scan_games, 
            get_live_telemetry,
            run_powershell_async,
            run_powershell_generic
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
