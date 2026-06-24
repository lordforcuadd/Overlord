use serde::Serialize;
use std::path::Path;
use winreg::enums::*;
use winreg::RegKey;
use std::os::windows::process::CommandExt;
use sysinfo::System;
use tokio::sync::OnceCell;

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct HardwareResponse {
    pub cpu: String,
    pub gpu: String,
    pub motherboard: String,
    pub ram_gb: u32,
    pub ram_speed_mhz: Option<u32>,
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

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct SYSTEM_POWER_STATUS {
    ac_line_status: u8,
    battery_flag: u8,
    battery_life_percent: u8,
    system_status_flag: u8,
    battery_life_time: u32,
    battery_full_life_time: u32,
}

extern "system" {
    fn GetLogicalProcessorInformationEx(relationship_type: u32, buffer: *mut u8, returned_length: *mut u32) -> i32;
    fn CreateFileW(lpFileName: *const u16, dwDesiredAccess: u32, dwShareMode: u32, lpSecurityAttributes: *mut std::ffi::c_void, dwCreationDisposition: u32, dwFlagsAndAttributes: u32, hTemplateFile: *mut std::ffi::c_void) -> *mut std::ffi::c_void;
    fn DeviceIoControl(hDevice: *mut std::ffi::c_void, dwIoControlCode: u32, lpInBuffer: *mut std::ffi::c_void, nInBufferSize: u32, lpOutBuffer: *mut std::ffi::c_void, nOutBufferSize: u32, lpBytesReturned: *mut u32, lpOverlapped: *mut std::ffi::c_void) -> i32;
    fn CloseHandle(hObject: *mut std::ffi::c_void) -> i32;
    fn GetSystemPowerStatus(lpSystemPowerStatus: *mut SYSTEM_POWER_STATUS) -> i32;
}

static HARDWARE_CACHE: OnceCell<HardwareResponse> = OnceCell::const_new();

pub async fn get_system_hardware() -> HardwareResponse {
    HARDWARE_CACHE.get_or_init(|| async {
        tokio::task::spawn_blocking(move || {
            let mut sys = System::new_all();
            sys.refresh_memory();
            sys.refresh_cpu();

            let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);

            let cpu_name = hklm
                .open_subkey("HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0")
                .and_then(|key| key.get_value::<String, _>("ProcessorNameString"))
                .unwrap_or_else(|_| {
                    sys.cpus()
                        .first()
                        .map(|cpu| cpu.brand().trim().to_string())
                        .unwrap_or_else(|| "CPU no detectada".to_string())
                });

            let motherboard_name = hklm
                .open_subkey("HARDWARE\\DESCRIPTION\\System\\BIOS")
                .and_then(|key| {
                    let base_prod: String = key.get_value("BaseBoardProduct")?;
                    let base_man: String = key.get_value("BaseBoardManufacturer")?;
                    Ok(format!("{} {}", base_man, base_prod))
                })
                .unwrap_or_else(|_| "Placa Base Generica".to_string());

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

            let gpu_name = if gpus.is_empty() { "GPU no detectada".to_string() } else { gpus.join(" + ") };

            let total_ram_bytes = sys.total_memory();
            let ram_calc = (total_ram_bytes as f64 / 1024.0 / 1024.0 / 1024.0).round() as u32;

            let is_laptop_chassis = hklm
                .open_subkey("SYSTEM\\CurrentControlSet\\Control\\SystemInformation")
                .and_then(|key| {
                    let chassis_type: u32 = key.get_value("SystemChassisType")?;
                    Ok(matches!(chassis_type, 8 | 9 | 10 | 11 | 12 | 14))
                })
                .unwrap_or(false);

            let has_battery = unsafe {
                let mut status = SYSTEM_POWER_STATUS {
                    ac_line_status: 255,
                    battery_flag: 255,
                    battery_life_percent: 255,
                    system_status_flag: 0,
                    battery_life_time: 0xFFFFFFFF,
                    battery_full_life_time: 0xFFFFFFFF,
                };
                if GetSystemPowerStatus(&mut status) != 0 {
                    status.battery_flag != 128 && status.battery_flag != 255
                } else {
                    false
                }
            };

            let is_laptop = is_laptop_chassis || has_battery;

            // Consultar velocidad de RAM de forma asíncrona mediante PowerShell/CIM (método moderno compatible con 24H2)
            let mut ram_speed_val = None;
            let system_root = std::env::var("SystemRoot").unwrap_or_else(|_| "C:\\Windows".to_string());
            let powershell_path = format!("{}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", system_root);
            let output = std::process::Command::new(&powershell_path)
                .creation_flags(0x08000000)
                .args(&[
                    "-NoProfile",
                    "-Command",
                    "(Get-CimInstance Win32_PhysicalMemory | Select-Object -ExpandProperty ConfiguredClockSpeed -First 1)",
                ])
                .output();
            if let Ok(out) = output {
                if out.status.success() {
                    let text = String::from_utf8_lossy(&out.stdout).trim().to_string();
                    if let Ok(speed) = text.parse::<u32>() {
                        if speed > 0 {
                            ram_speed_val = Some(speed);
                        }
                    }
                }
            }

            // Fallback a wmic.exe si PowerShell falla o no retorna velocidad en sistemas legacy
            if ram_speed_val.is_none() {
                let output = std::process::Command::new("wmic.exe")
                    .creation_flags(0x08000000)
                    .args(&["path", "Win32_PhysicalMemory", "get", "ConfiguredClockSpeed"])
                    .output();
                if let Ok(out) = output {
                    if out.status.success() {
                        let text = String::from_utf8_lossy(&out.stdout);
                        let lines: Vec<&str> = text.lines()
                            .map(|l| l.trim())
                            .filter(|l| !l.is_empty() && !l.starts_with("ConfiguredClockSpeed"))
                            .collect();
                        if let Some(first_line) = lines.first() {
                            if let Ok(speed) = first_line.parse::<u32>() {
                                if speed > 0 {
                                    ram_speed_val = Some(speed);
                                }
                            }
                        }
                    }
                }
            }

            let mut drive_is_ssd = false;
            let system_drive = std::env::var("SystemDrive").unwrap_or_else(|_| "C:".to_string());
            let path_drive_str = format!("\\\\.\\{}", system_drive);
            let path_drive: Vec<u16> = path_drive_str.encode_utf16().chain(std::iter::once(0)).collect();
            unsafe {
                let handle = CreateFileW(path_drive.as_ptr(), 0x80000000, 0x00000001 | 0x00000002, std::ptr::null_mut(), 3, 0x00000080, std::ptr::null_mut());
                if handle != (-1isize as *mut std::ffi::c_void) && !handle.is_null() {
                    #[repr(C)]
                    struct STORAGE_PROPERTY_QUERY { property_id: u32, query_type: u32, additional_parameters: [u8; 1] }
                    #[repr(C)]
                    struct DEVICE_SEEK_PENALTY_DESCRIPTOR { version: u32, size: u32, is_seek_penalty: u8 }
                    
                    let mut query = STORAGE_PROPERTY_QUERY { property_id: 7, query_type: 0, additional_parameters: [0] };
                    let mut descriptor = DEVICE_SEEK_PENALTY_DESCRIPTOR { version: 0, size: 0, is_seek_penalty: 1 };
                    let mut bytes_returned = 0;
                    
                    let res = DeviceIoControl(handle, 0x002D1400, &mut query as *mut _ as *mut std::ffi::c_void, std::mem::size_of::<STORAGE_PROPERTY_QUERY>() as u32, &mut descriptor as *mut _ as *mut std::ffi::c_void, std::mem::size_of::<DEVICE_SEEK_PENALTY_DESCRIPTOR>() as u32, &mut bytes_returned, std::ptr::null_mut());
                    if res != 0 {
                        if descriptor.is_seek_penalty == 0 {
                            drive_is_ssd = true;
                        }
                    } else {
                        let err = std::io::Error::last_os_error();
                        eprintln!("[OVERLORD WARNING] DeviceIoControl failed: {}", err);
                    }
                    CloseHandle(handle);
                } else {
                    let err = std::io::Error::last_os_error();
                    eprintln!("[OVERLORD WARNING] CreateFileW on C: failed: {}", err);
                }
            }

            let mut is_hybrid = false;
            let mut length = 0;
            unsafe { GetLogicalProcessorInformationEx(0, std::ptr::null_mut(), &mut length); }
            if length > 0 {
                let mut buffer = vec![0u8; length as usize];
                unsafe {
                    if GetLogicalProcessorInformationEx(0, buffer.as_mut_ptr(), &mut length) != 0 {
                        let mut offset = 0;
                        let mut efficiency_classes = Vec::new();
                        while offset + 8 <= buffer.len() {
                            let relationship = u32::from_le_bytes([buffer[offset], buffer[offset+1], buffer[offset+2], buffer[offset+3]]);
                            let size = u32::from_le_bytes([buffer[offset+4], buffer[offset+5], buffer[offset+6], buffer[offset+7]]) as usize;
                            if size == 0 || offset + size > buffer.len() { break; }
                            if relationship == 0 && size > 9 {
                                let eff_class = buffer[offset + 9];
                                if !efficiency_classes.contains(&eff_class) {
                                    efficiency_classes.push(eff_class);
                                }
                            }
                            offset += size;
                        }
                        if efficiency_classes.len() > 1 { is_hybrid = true; }
                    }
                }
            }

            let is_x3d = cpu_name.to_lowercase().contains("x3d");

            HardwareResponse {
                cpu: cpu_name,
                gpu: gpu_name,
                motherboard: motherboard_name,
                ram_gb: ram_calc,
                ram_speed_mhz: ram_speed_val,
                is_laptop,
                is_hybrid,
                is_x3d,
                is_ssd: drive_is_ssd,
            }
        }).await.unwrap_or_else(|e| {
            eprintln!("[OVERLORD ERROR] spawn_blocking failed for hardware info: {:?}", e);
            HardwareResponse {
                cpu: "Error al detectar CPU".to_string(),
                gpu: "Error al detectar GPU".to_string(),
                motherboard: "Error al detectar Placa".to_string(),
                ram_gb: 0,
                ram_speed_mhz: None,
                is_laptop: false,
                is_hybrid: false,
                is_x3d: false,
                is_ssd: false,
            }
        })
    }).await.clone()
}

fn get_steam_library_paths() -> Vec<String> {
    let program_files = std::env::var("ProgramFiles").unwrap_or_else(|_| "C:\\Program Files".to_string());
    let program_files_x86 = std::env::var("ProgramFiles(x86)").unwrap_or_else(|_| "C:\\Program Files (x86)".to_string());
    let mut paths = vec![
        format!("{}\\Steam\\steamapps\\common", program_files),
        format!("{}\\Steam\\steamapps\\common", program_files_x86),
    ];
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    if let Ok(steam_key) = hkcu.open_subkey("Software\\Valve\\Steam") {
        if let Ok(steam_path) = steam_key.get_value::<String, _>("SteamPath") {
            let path = Path::new(&steam_path).join("steamapps").join("libraryfolders.vdf");
            if let Ok(content) = std::fs::read_to_string(path) {
                for line in content.lines() {
                    if line.contains("\"path\"") {
                        let parts: Vec<&str> = line.split('"').collect();
                        if parts.len() >= 4 {
                            let p = parts[3].replace("\\\\", "\\");
                            let common_path = Path::new(&p).join("steamapps").join("common");
                            if common_path.exists() {
                                if let Some(p_str) = common_path.to_str() {
                                    let p_string = p_str.to_string();
                                    if !paths.contains(&p_string) {
                                        paths.push(p_string);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    paths
}

fn get_epic_installed_games() -> Vec<(String, String)> {
    let mut games = Vec::new();
    let program_data = std::env::var("ProgramData").unwrap_or_else(|_| "C:\\ProgramData".to_string());
    let manifests_path = Path::new(&program_data).join("Epic\\EpicGamesLauncher\\Data\\Manifests");
    if manifests_path.exists() {
        if let Ok(entries) = std::fs::read_dir(manifests_path) {
            for entry in entries.flatten() {
                if entry.path().extension().map_or(false, |ext| ext == "item") {
                    if let Ok(content) = std::fs::read_to_string(entry.path()) {
                        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
                            if let (Some(name), Some(location)) = (
                                json.get("MandatoryAppFolderName").and_then(|v| v.as_str()),
                                json.get("InstallLocation").and_then(|v| v.as_str())
                            ) {
                                games.push((name.to_string(), location.to_string()));
                            }
                        }
                    }
                }
            }
        }
    }
    games
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

    // 1. Scan Uninstall registry keys (64-bit and 32-bit)
    let registry_paths = [
        "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        "SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    ];

    for path in &registry_paths {
        if let Ok(uninstall_key) = hklm.open_subkey(path) {
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

    let steam_paths = get_steam_library_paths();
    for path in &steam_paths {
        for game in catalog.iter_mut() {
            if Path::new(path).join(&game.name).exists() {
                game.detected = true;
            }
        }
    }

    let epic_games = get_epic_installed_games();
    for (folder_name, install_loc) in &epic_games {
        let lower_folder = folder_name.to_lowercase();
        let lower_loc = install_loc.to_lowercase();
        for game in catalog.iter_mut() {
            let lower_game_name = game.name.to_lowercase();
            if lower_folder.contains(&lower_game_name) || lower_loc.contains(&lower_game_name) {
                game.detected = true;
            }
        }
    }

    let gog_paths = ["SOFTWARE\\GOG.com\\Games", "SOFTWARE\\Wow6432Node\\GOG.com\\Games"];
    for path in &gog_paths {
        if let Ok(gog_key) = hklm.open_subkey(path) {
            for subkey_name in gog_key.enum_keys().map(|x| x.unwrap_or_default()) {
                if let Ok(subkey) = gog_key.open_subkey(&subkey_name) {
                    if let Ok(title) = subkey.get_value::<String, _>("title") {
                        let lower_title = title.to_lowercase();
                        for game in catalog.iter_mut() {
                            if lower_title.contains(&game.name.to_lowercase()) { game.detected = true; }
                        }
                    }
                }
            }
        }
    }

    let program_files = std::env::var("ProgramFiles").unwrap_or_else(|_| "C:\\Program Files".to_string());
    let common_epic_paths = [format!("{}\\Epic Games", program_files), "D:\\Epic Games".to_string()];
    for path in &common_epic_paths {
        for game in catalog.iter_mut() {
            if Path::new(path).join(&game.name).exists() { game.detected = true; }
        }
    }

    let system_drive = std::env::var("SystemDrive").unwrap_or_else(|_| "C:".to_string());
    let xbox_default_paths = [
        format!("{}\\XboxGames", system_drive),
        "D:\\XboxGames".to_string(),
    ];
    for path in &xbox_default_paths {
        if Path::new(path).exists() {
            for game in catalog.iter_mut() {
                if Path::new(path).join(&game.name).exists() { game.detected = true; }
            }
        }
    }

    let static_checks = [
        ("VALORANT", format!("{}\\Riot Games\\VALORANT", system_drive)),
        ("VALORANT", "D:\\Riot Games\\VALORANT".to_string()),
        ("League of Legends", format!("{}\\Riot Games\\League of Legends", system_drive)),
        ("League of Legends", "D:\\Riot Games\\League of Legends".to_string()),
    ];
    for (name, path) in &static_checks {
        if Path::new(path).exists() {
            for game in catalog.iter_mut() {
                if game.name == *name { game.detected = true; }
            }
        }
    }

    catalog
}