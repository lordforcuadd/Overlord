use serde::Serialize;
use std::path::Path;
use winreg::enums::*;
use winreg::RegKey;
use sysinfo::{System, CpuRefreshKind, RefreshKind};
use std::os::windows::process::CommandExt;

#[derive(Serialize, Clone)]
pub struct HardwareResponse {
    pub cpu: String,
    pub gpu: String,
    pub motherboard: String,
    pub ram_gb: u32,
    pub ram_speed: u32,
    pub is_laptop: bool,
    pub is_hybrid: bool,
    pub is_x3d: bool,
    pub is_ssd: bool,
}

#[derive(Serialize, Clone)]
pub struct ScanGamesResponse {
    pub name: String,
    pub exe: String,
    pub detected: bool,
}

pub fn get_system_hardware() -> HardwareResponse {
    let mut sys = System::new_with_specifics(
        RefreshKind::new().with_cpu(CpuRefreshKind::everything())
    );
    sys.refresh_memory();
    sys.refresh_cpu();

    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);

    let cpu_name = hklm
        .open_subkey("HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0")
        .and_then(|key| key.get_value::<String, _>("ProcessorNameString"))
        .unwrap_or_else(|_| {
            let brand = sys.global_cpu_info().brand().trim().to_string();
            if brand.is_empty() { "CPU no detectada".to_string() } else { brand }
        });

    let motherboard_name = hklm
        .open_subkey("HARDWARE\\DESCRIPTION\\System\\BIOS")
        .and_then(|key| {
            let base_prod: String = key.get_value("BaseBoardProduct")?;
            let base_man: String = key.get_value("BaseBoardManufacturer")?;
            Ok(format!("{} {}", base_man, base_prod))
        })
        .unwrap_or_else(|_| "Placa Base Genérica".to_string());

    let mut gpus = Vec::new();
    if let Ok(class_key) = hklm.open_subkey("SYSTEM\\CurrentControlSet\\Control\\Class\\{4d36e968-e325-11ce-bfc1-08002be10318}") {
        for subkey_name in class_key.enum_keys().map(|x| x.unwrap_or_default()) {
            if subkey_name.len() == 4 && subkey_name.chars().all(|c| c.is_ascii_digit()) {
                if let Ok(subkey) = class_key.open_subkey(&subkey_name) {
                    if let Ok(driver_desc) = subkey.get_value::<String, _>("DriverDesc") {
                        if !driver_desc.contains("Basic Render") && !gpus.contains(&driver_desc) {
                            gpus.push(driver_desc);
                        }
                    }
                }
            }
        }
    }

    let gpu_name = if gpus.is_empty() {
        "GPU no detectada".to_string()
    } else {
        gpus.join(" + ")
    };

    let total_ram_bytes = sys.total_memory();
    let ram_calc = (total_ram_bytes as f64 / 1024.0 / 1024.0 / 1024.0).round() as u32;

    let mut ram_speed_mhz = 4800;
    if let Ok(output) = std::process::Command::new("powershell.exe")
        .creation_flags(0x08000000)
        .args(&["-NoProfile", "-Command", "(Get-CimInstance Win32_PhysicalMemory | Select-Object -First 1).Speed"])
        .output() 
    {
        let out_str = String::from_utf8_lossy(&output.stdout);
        if let Ok(parsed_speed) = out_str.trim().parse::<u32>() {
            if parsed_speed > 0 {
                ram_speed_mhz = parsed_speed;
            }
        }
    }

    let is_laptop_chassis = hklm
        .open_subkey("SYSTEM\\CurrentControlSet\\Control\\SystemInformation")
        .and_then(|key| {
            let chassis_type: u32 = key.get_value("SystemChassisType")?;
            Ok(matches!(chassis_type, 8 | 9 | 10 | 11 | 12 | 14))
        })
        .unwrap_or(false);

    let mut drive_is_ssd = true;
    if let Ok(output) = std::process::Command::new("powershell.exe")
        .creation_flags(0x08000000)
        .args(&["-NoProfile", "-Command", "(Get-PhysicalDisk | Where-Object Size -GT 0 | Select-Object -First 1).MediaType"])
        .output()
    {
        let media_str = String::from_utf8_lossy(&output.stdout).to_lowercase();
        if media_str.contains("hdd") {
            drive_is_ssd = false;
        }
    }

    let lower_cpu = cpu_name.to_lowercase();
    let mut is_hybrid = false;
    
    if lower_cpu.contains("intel") {
        let physical_cores = sys.physical_core_count().unwrap_or(0);
        let total_cpus = sys.cpus().len();
        if physical_cores > 0 && total_cpus > physical_cores && total_cpus < (physical_cores * 2) {
            is_hybrid = true;
        }
        if lower_cpu.contains("i7-12") || lower_cpu.contains("i7-13") || lower_cpu.contains("i7-14") ||
           lower_cpu.contains("i9-12") || lower_cpu.contains("i9-13") || lower_cpu.contains("i9-14") ||
           lower_cpu.contains("ultra 7") || lower_cpu.contains("ultra 9") {
            is_hybrid = true;
        }
    }

    let is_x3d = lower_cpu.contains("x3d");

    HardwareResponse {
        cpu: cpu_name,
        gpu: gpu_name,
        motherboard: motherboard_name,
        ram_gb: ram_calc,
        ram_speed: ram_speed_mhz,
        is_laptop: is_laptop_chassis,
        is_hybrid,
        is_x3d,
        is_ssd: drive_is_ssd,
    }
}

pub fn collect_installed_games() -> Vec<ScanGamesResponse> {
    let mut catalog = vec![
        ScanGamesResponse { name: "League of Legends".to_string(), exe: "League of Legends.exe".to_string(), detected: false },
        ScanGamesResponse { name: "VALORANT".to_string(), exe: "VALORANT-Win64-Shipping.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Counter-Strike 2".to_string(), exe: "cs2.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Fortnite".to_string(), exe: "FortniteClient-Win64-Shipping.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Apex Legends".to_string(), exe: "r5apex.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Overwatch 2".to_string(), exe: "Overwatch.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Cyberpunk 2077".to_string(), exe: "Cyberpunk2077.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Grand Theft Auto V".to_string(), exe: "GTA5.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Dota 2".to_string(), exe: "dota2.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Call of Duty".to_string(), exe: "cod.exe".to_string(), detected: false },
    ];

    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);

    if let Ok(uninstall_key) = hklm.open_subkey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall") {
        for subkey_name in uninstall_key.enum_keys().map(|x| x.unwrap_or_default()) {
            if let Ok(subkey) = uninstall_key.open_subkey(&subkey_name) {
                if let Ok(display_name) = subkey.get_value::<String, _>("DisplayName") {
                    let lower_name = display_name.to_lowercase();
                    for game in catalog.iter_mut() {
                        if lower_name.contains(&game.name.to_lowercase()) {
                            game.detected = true;
                        }
                    }
                }
            }
        }
    }

    if let Ok(uninstall_wow) = hklm.open_subkey("SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall") {
        for subkey_name in uninstall_wow.enum_keys().map(|x| x.unwrap_or_default()) {
            if let Ok(subkey) = uninstall_wow.open_subkey(&subkey_name) {
                if let Ok(display_name) = subkey.get_value::<String, _>("DisplayName") {
                    let lower_name = display_name.to_lowercase();
                    for game in catalog.iter_mut() {
                        if lower_name.contains(&game.name.to_lowercase()) {
                            game.detected = true;
                        }
                    }
                }
            }
        }
    }

    if let Ok(steam_key) = hkcu.open_subkey("Software\\Valve\\Steam\\Apps") {
        for app_id in steam_key.enum_keys().map(|x| x.unwrap_or_default()) {
            if let Ok(app_subkey) = steam_key.open_subkey(&app_id) {
                if let Ok(installed) = app_subkey.get_value::<u32, _>("Installed") {
                    if installed == 1 {
                        if let Ok(name) = app_subkey.get_value::<String, _>("Name") {
                            let lower_steam_name = name.to_lowercase();
                            for game in catalog.iter_mut() {
                                if lower_steam_name.contains(&game.name.to_lowercase()) {
                                    game.detected = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    let gog_paths = [
        "SOFTWARE\\GOG.com\\Games",
        "SOFTWARE\\Wow6432Node\\GOG.com\\Games"
    ];
    for path in &gog_paths {
        if let Ok(gog_key) = hklm.open_subkey(path) {
            for subkey_name in gog_key.enum_keys().map(|x| x.unwrap_or_default()) {
                if let Ok(subkey) = gog_key.open_subkey(&subkey_name) {
                    if let Ok(title) = subkey.get_value::<String, _>("title") {
                        let lower_title = title.to_lowercase();
                        for game in catalog.iter_mut() {
                            if lower_title.contains(&game.name.to_lowercase()) {
                                game.detected = true;
                            }
                        }
                    }
                }
            }
        }
    }

    if hklm.open_subkey("SOFTWARE\\Epic Games\\EpicGamesLauncher").is_ok() {
        if hklm.open_subkey("SOFTWARE\\EpicGames\\Unreal Engine").is_ok() {
            for game in catalog.iter_mut() {
                if game.name == "Fortnite" { game.detected = true; }
            }
        }
    }
    
    let common_epic_paths = ["C:\\Program Files\\Epic Games", "D:\\Epic Games"];
    for path in &common_epic_paths {
        for game in catalog.iter_mut() {
            if Path::new(path).join(&game.name).exists() {
                game.detected = true;
            }
        }
    }

    let xbox_default_paths = ["C:\\XboxGames", "D:\\XboxGames"];
    for path in &xbox_default_paths {
        if Path::new(path).exists() {
            for game in catalog.iter_mut() {
                if Path::new(path).join(&game.name).exists() {
                    game.detected = true;
                }
            }
        }
    }

    let riot_paths = ["C:\\Riot Games\\VALORANT", "D:\\Riot Games\\VALORANT"];
    for path in &riot_paths {
        if Path::new(path).exists() {
            for game in catalog.iter_mut() {
                if game.name == "VALORANT" { game.detected = true; }
            }
        }
    }

    let lol_paths = ["C:\\Riot Games\\League of Legends", "D:\\Riot Games\\League of Legends"];
    for path in &lol_paths {
        if Path::new(path).exists() {
            for game in catalog.iter_mut() {
                if game.name == "League of Legends" { game.detected = true; }
            }
        }
    }

    catalog
}