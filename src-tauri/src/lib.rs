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
    let ps_script = r#"
        $ErrorActionPreference = 'SilentlyContinue'
        
        $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
        $gpus = Get-CimInstance Win32_VideoController
        $gpu_names = foreach ($g in $gpus) { $g.Name.Trim() }
        $gpu = $gpu_names -join " + "
        
        $ram_bytes = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
        $ram_gb = [math]::Round($ram_bytes / 1GB)
        $ram_speed = (Get-CimInstance Win32_PhysicalMemory | Select-Object -First 1).Speed
        
        $mobo = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
        $motherboard = "$($mobo.Manufacturer) $($mobo.Product)"
        
        $chassis = (Get-CimInstance Win32_SystemEnclosure | Select-Object -First 1).ChassisTypes[0]
        $is_laptop = $chassis -in 8,9,10,11,14,30,31

        $data = @{
            cpu = $cpu.Trim()
            gpu = $gpu
            ram_gb = $ram_gb
            ram_speed = $ram_speed
            motherboard = $motherboard.Trim()
            is_laptop = [bool]$is_laptop
        }
        $data | ConvertTo-Json -Compress
    "#;

    const CREATE_NO_WINDOW: u32 = 0x08000000;
    let output = Command::new("powershell")
        .creation_flags(CREATE_NO_WINDOW)
        .args(&["-NoProfile", "-Command", ps_script])
        .output()
        .map_err(|e| e.to_string())?;

    let json_str = String::from_utf8_lossy(&output.stdout);
    let data: HardwareData =
        serde_json::from_str(&json_str).map_err(|e| format!("Error parseando JSON: {}", e))?;

    Ok(data)
}

#[derive(Serialize, Deserialize)]
struct GameDetected {
    name: String,
    exe: String,
    detected: bool,
}

#[tauri::command]
fn scan_games() -> Result<Vec<GameDetected>, String> {
    let ps_script = r#"
        $ErrorActionPreference = 'SilentlyContinue'
        
        $targetGames = @{
            "League of Legends" = "League of Legends.exe"
            "Valorant" = "VALORANT-Win64-Shipping.exe"
            "Counter-Strike 2" = "cs2.exe"
            "Fortnite" = "FortniteClient-Win64-Shipping.exe"
            "Apex Legends" = "r5apex.exe"
            "Overwatch" = "Overwatch.exe"
        }
        
        $installedGames = @()
        $paths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        $displayNames = Get-ItemProperty $paths -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName -ErrorAction SilentlyContinue

        foreach ($game in $targetGames.GetEnumerator()) {
            $isInstalled = $false
            if ($displayNames -match $game.Key -or (Get-Process -Name $game.Value.Replace(".exe","") -ErrorAction SilentlyContinue)) { 
                $isInstalled = $true 
            }
            
            $installedGames += @{
                name = $game.Key
                exe = $game.Value
                detected = $isInstalled
            }
        }
        $installedGames | ConvertTo-Json -Compress
    "#;

    const CREATE_NO_WINDOW: u32 = 0x08000000;
    let output = Command::new("powershell")
        .creation_flags(CREATE_NO_WINDOW)
        .args(&["-NoProfile", "-Command", ps_script])
        .output()
        .map_err(|e| e.to_string())?;

    let json_str = String::from_utf8_lossy(&output.stdout);
    let data: Vec<GameDetected> = serde_json::from_str(&json_str).unwrap_or_else(|_| vec![]);

    Ok(data)
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
    script_path: String,
    is_laptop: bool,
    ram_gb: u32,
    game_list: Option<String>,
) -> Result<String, String> {
    const CREATE_NO_WINDOW: u32 = 0x08000000;

    
    if script_path == "shutdown" {
        let output = Command::new("shutdown")
            .creation_flags(CREATE_NO_WINDOW)
            .args(&["/r", "/t", "0"])
            .output()
            .map_err(|e| e.to_string())?;
        return Ok(String::from_utf8_lossy(&output.stdout).to_string());
    }

    
    let mut args = vec![
        "-NoLogo".to_string(),
        "-NoProfile".to_string(),
        "-ExecutionPolicy".to_string(),
        "Bypass".to_string(),
        "-File".to_string(),
        script_path,
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
async fn get_barebones_status() -> Result<bool, String> {
    let script = r#"
    $Fx = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -ErrorAction SilentlyContinue).VisualFXSetting
    $Trans = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -ErrorAction SilentlyContinue).EnableTransparency
    
    if ($Fx -eq 2 -and $Trans -eq 0) { Write-Output "true" } else { Write-Output "false" }
    "#;

    const CREATE_NO_WINDOW: u32 = 0x08000000;
    let output = Command::new("powershell")
        .creation_flags(CREATE_NO_WINDOW)
        .args(&["-NoProfile", "-Command", script])
        .output()
        .map_err(|e| e.to_string())?;

    let result = String::from_utf8_lossy(&output.stdout).trim().to_string();
    Ok(result == "true")
}

#[tauri::command]
async fn set_barebones_status(enable: bool) -> Result<String, String> {
    let script = if enable {
        r#"
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Type DWord -Value 2 -Force
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 0 -Force
        Stop-Process -Name explorer -Force
        "#
    } else {
        r#"
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Type DWord -Value 1 -Force
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1 -Force
        Stop-Process -Name explorer -Force
        "#
    };

    const CREATE_NO_WINDOW: u32 = 0x08000000;
    let _ = Command::new("powershell")
        .creation_flags(CREATE_NO_WINDOW)
        .args(&["-NoProfile", "-Command", script])
        .spawn()
        .map_err(|e| e.to_string())?;

    Ok(if enable {
        "Barebones Activado".into()
    } else {
        "Graficos Restaurados".into()
    })
}

#[tauri::command]
async fn run_powershell_generic(
    script_path: String,
    args_list: Vec<String>
) -> Result<String, String> {
    const CREATE_NO_WINDOW: u32 = 0x08000000;
    
    let mut ps_args = vec![
        "-NoLogo".to_string(),
        "-NoProfile".to_string(),
        "-ExecutionPolicy".to_string(),
        "Bypass".to_string(),
        "-File".to_string(),
        script_path,
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
        .plugin(tauri_plugin_single_instance::init(|app, args, cwd| {
            let _ = app.get_webview_window("main").expect("no main window").set_focus();
        })) // <--- AÑADIDO AQUI
        .manage(AppState { sys: Mutex::new(System::new_all()) }) 
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet, 
            get_hardware_info, 
            scan_games, 
            get_live_telemetry,
            run_powershell_async,
            get_barebones_status,
            set_barebones_status,
            run_powershell_generic
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
