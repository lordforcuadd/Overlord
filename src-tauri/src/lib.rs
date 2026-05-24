use serde::{Deserialize, Serialize};
use std::os::windows::process::CommandExt;
use std::process::Command;
use std::sync::Mutex;
use sysinfo::System;
use tauri::Manager;

#[link(name = "ntdll")]
extern "system" {
    fn RtlAdjustPrivilege(Privilege: u32, Enable: u8, CurrentThread: u8, Enabled: *mut u8) -> i32;
    fn NtSetSystemInformation(SystemInformationClass: u32, SystemInformation: *mut u32, SystemInformationLength: u32) -> i32;
}

#[tauri::command]
fn purge_ram_native() -> Result<String, String> {
    unsafe {
        let mut enabled: u8 = 0;
        let status1 = RtlAdjustPrivilege(13, 1, 0, &mut enabled);
        let _ = RtlAdjustPrivilege(5, 1, 0, &mut enabled);

        if status1 < 0 {
            return Err(format!("Bloqueo de Privilegios. NTSTATUS: {:X}", status1 as u32));
        }
        
        let mut command: u32 = 4; 
        let status2 = NtSetSystemInformation(
            80,
            &mut command,
            std::mem::size_of::<u32>() as u32,
        );
        
        if status2 >= 0 {
            Ok("RAM purgada con éxito a nivel Kernel".to_string())
        } else {
            Err(format!("Kernel rechazó la purga. NTSTATUS: {:X}", status2 as u32))
        }
    }
}

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

    let mut sys = System::new_all();
    sys.refresh_memory();
    let ram_gb = (sys.total_memory() as f64 / 1_073_741_824.0).round() as u32;

    
    let ps_script = r#"
        $ErrorActionPreference = 'SilentlyContinue'
        $gpus = (Get-CimInstance Win32_VideoController).Name -join ', '
        $chassis = (Get-CimInstance Win32_SystemEnclosure | Select-Object -First 1).ChassisTypes[0]
        $mhz = (Get-CimInstance Win32_PhysicalMemory | Select-Object -First 1).Speed
        Write-Output "$gpus|$chassis|$mhz"
    "#;
    
    let output = Command::new("powershell")
        .creation_flags(CREATE_NO_WINDOW)
        .args(&["-NoProfile", "-Command", ps_script])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "GPU Desconocida|3|0".to_string());

    let parts: Vec<&str> = output.split('|').collect();
    let gpu = parts.first().unwrap_or(&"GPU Desconocida").trim().to_string();
    let chassis_str = parts.get(1).unwrap_or(&"3").trim();
    let chassis_int: u32 = chassis_str.parse().unwrap_or(3);
    
    
    let ram_speed_str = parts.get(2).unwrap_or(&"0").trim();
    let ram_speed: u32 = ram_speed_str.parse().unwrap_or(0);
    
    let is_laptop = matches!(chassis_int, 8 | 9 | 10 | 11 | 14 | 30 | 31);

    Ok(HardwareData {
        cpu,
        gpu,
        ram_gb,
        ram_speed, 
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
        let detected = installed_display_names.iter().any(|d| d.to_lowercase().contains(&name.to_lowercase()));
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
    let mut sys = state.sys.lock().unwrap_or_else(|poisoned| poisoned.into_inner());

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
    let is_laptop_val = if is_laptop { "$true" } else { "$false" };
    let ram_val = ram_gb.to_string();
    

    let mut inline_command = format!(
        "& '{}' -IsLaptop {} -RamGB {}",
        absolute_script_path.replace("'", "''"),
        is_laptop_val,
        ram_val
    );

    
    let has_games = match &game_list {
        Some(games) if !games.is_empty() => {
            inline_command.push_str(" -GameList $args[0]");
            true
        }
        _ => false,
    };

    let mut cmd = Command::new("powershell");
    cmd.creation_flags(CREATE_NO_WINDOW);
    
    
    cmd.arg("-NoLogo")
       .arg("-NoProfile")
       .arg("-ExecutionPolicy")
       .arg("Bypass")
       .arg("-Command")
       .arg(&inline_command);

    
    if has_games {
        if let Some(games) = game_list {
            cmd.arg(games);
        }
    }

    let output = cmd.output().map_err(|e| e.to_string())?;

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

    let mut cmd = Command::new("powershell");
    cmd.creation_flags(CREATE_NO_WINDOW);
    
    cmd.arg("-NoLogo")
       .arg("-NoProfile")
       .arg("-ExecutionPolicy")
       .arg("Bypass")
       .arg("-File")
       .arg(absolute_script_path);
    
    for arg in args_list {
        cmd.arg(arg);
    }

    let output = cmd.output().map_err(|e| e.to_string())?;

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
            run_powershell_generic,
            purge_ram_native
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
