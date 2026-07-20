use serde::Serialize;
use std::path::Path;
use winreg::enums::*;
use winreg::RegKey;

#[derive(Serialize, Clone)]
pub struct ScanGamesResponse {
    pub name: String,
    pub exe: String,
    pub detected: bool,
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
        ScanGamesResponse { name: "Minecraft".to_string(), exe: "javaw.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Roblox".to_string(), exe: "RobloxPlayerBeta.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Rust".to_string(), exe: "RustClient.exe".to_string(), detected: false },
        ScanGamesResponse { name: "PUBG: BATTLEGROUNDS".to_string(), exe: "TslGame.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Hogwarts Legacy".to_string(), exe: "HogwartsLegacy.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Wuthering Waves".to_string(), exe: "Client-Win64-Shipping.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Black Myth: Wukong".to_string(), exe: "b1-Win64-Shipping.exe".to_string(), detected: false },
        ScanGamesResponse { name: "The Witcher 3: Wild Hunt".to_string(), exe: "witcher3.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Elden Ring".to_string(), exe: "eldenring.exe".to_string(), detected: false },
        ScanGamesResponse { name: "Destiny 2".to_string(), exe: "destiny2.exe".to_string(), detected: false },
    ];

    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);

    // 1. Scan Uninstall registry keys (64-bit and 32-bit) in HKLM and HKCU
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
                            let game_lower = game.name.to_lowercase();
                            let matches = if game_lower == "rust" {
                                lower_name == "rust"
                            } else {
                                lower_name.contains(&game_lower)
                            };
                            if matches {
                                game.detected = true;
                            }
                        }
                    }
                }
            }
        }
        if let Ok(uninstall_key) = hkcu.open_subkey(path) {
            for subkey_name in uninstall_key.enum_keys().map(|x| x.unwrap_or_default()) {
                if let Ok(subkey) = uninstall_key.open_subkey(&subkey_name) {
                    if let Ok(display_name) = subkey.get_value::<String, _>("DisplayName") {
                        let lower_name = display_name.to_lowercase();
                        for game in catalog.iter_mut() {
                            let game_lower = game.name.to_lowercase();
                            let matches = if game_lower == "rust" {
                                lower_name == "rust"
                            } else {
                                lower_name.contains(&game_lower)
                            };
                            if matches {
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
                                let game_lower = game.name.to_lowercase();
                                let matches = if game_lower == "rust" {
                                    lower_steam_name == "rust"
                                } else {
                                    lower_steam_name.contains(&game_lower)
                                };
                                if matches {
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
        let steamapps_dir = Path::new(path).parent();
        if let Some(steamapps) = steamapps_dir {
            if let Ok(entries) = std::fs::read_dir(steamapps) {
                for entry in entries.flatten() {
                    if entry.path().extension().map_or(false, |ext| ext == "acf") {
                        if let Ok(content) = std::fs::read_to_string(entry.path()) {
                            let mut inst_dir = None;
                            for line in content.lines() {
                                if line.contains("\"installdir\"") {
                                    let parts: Vec<&str> = line.split('"').collect();
                                    if parts.len() >= 4 {
                                        inst_dir = Some(parts[3].to_string());
                                        break;
                                    }
                                }
                            }
                            if let Some(dir_name) = inst_dir {
                                let full_game_path = Path::new(path).join(&dir_name);
                                if full_game_path.exists() {
                                    for game in catalog.iter_mut() {
                                        let game_lower = game.name.to_lowercase();
                                        let dir_lower = dir_name.to_lowercase();
                                        let matches = if game_lower == "rust" {
                                            dir_lower == "rust"
                                        } else {
                                            dir_lower.contains(&game_lower) || game_lower.contains(&dir_lower)
                                        };
                                        if matches {
                                            game.detected = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
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
            let matches = if lower_game_name == "rust" {
                lower_folder == "rust" || lower_loc.ends_with("\\rust") || lower_loc.ends_with("/rust")
            } else {
                lower_folder.contains(&lower_game_name) || lower_loc.contains(&lower_game_name)
            };
            if matches {
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
                            let game_lower = game.name.to_lowercase();
                            let matches = if game_lower == "rust" {
                                lower_title == "rust"
                            } else {
                                lower_title.contains(&game_lower)
                            };
                            if matches { game.detected = true; }
                        }
                    }
                }
            }
        }
    }

    let program_files = std::env::var("ProgramFiles").unwrap_or_else(|_| "C:\\Program Files".to_string());
    let system_drive = std::env::var("SystemDrive").unwrap_or_else(|_| "C:".to_string());
    let system_drive_letter = system_drive.chars().next().unwrap_or('C').to_ascii_uppercase();

    let mut active_drives = vec![format!("{}:\\", system_drive_letter)];
    for drive_char in b'D'..=b'Z' {
        let drive_letter = drive_char as char;
        if drive_letter != system_drive_letter {
            let drive_path = format!("{}:\\", drive_letter);
            if Path::new(&drive_path).exists() {
                active_drives.push(drive_path);
            }
        }
    }

    let mut common_epic_paths = vec![format!("{}\\Epic Games", program_files)];
    for drive in &active_drives {
        let path = Path::new(drive).join("Epic Games");
        if let Some(path_str) = path.to_str() {
            common_epic_paths.push(path_str.to_string());
        }
    }
    for path in &common_epic_paths {
        for game in catalog.iter_mut() {
            if Path::new(path).join(&game.name).exists() { game.detected = true; }
        }
    }

    let mut xbox_default_paths = Vec::new();
    for drive in &active_drives {
        let path = Path::new(drive).join("XboxGames");
        if let Some(path_str) = path.to_str() {
            xbox_default_paths.push(path_str.to_string());
        }
    }
    for path in &xbox_default_paths {
        if Path::new(path).exists() {
            for game in catalog.iter_mut() {
                if Path::new(path).join(&game.name).exists() { game.detected = true; }
            }
        }
    }

    for drive in &active_drives {
        let riot_path = Path::new(drive).join("Riot Games");
        if riot_path.exists() {
            if riot_path.join("VALORANT").exists() {
                for game in catalog.iter_mut() {
                    if game.name == "VALORANT" { game.detected = true; }
                }
            }
            if riot_path.join("League of Legends").exists() {
                for game in catalog.iter_mut() {
                    if game.name == "League of Legends" { game.detected = true; }
                }
            }
        }
    }

    // Detección dinámica de Minecraft (Launcher oficial, CurseForge, Prism, Modrinth, TLauncher)
    for game in catalog.iter_mut() {
        if game.name == "Minecraft" {
            let appdata = std::env::var("APPDATA").unwrap_or_default();
            let localappdata = std::env::var("LOCALAPPDATA").unwrap_or_default();
            let userprofile = std::env::var("USERPROFILE").unwrap_or_default();
            
            let mc_paths = [
                Path::new(&userprofile).join("curseforge").join("minecraft"),
                Path::new(&appdata).join(".minecraft"),
                Path::new(&appdata).join("PrismLauncher"),
                Path::new(&localappdata).join("CurseForge"),
                Path::new(&localappdata).join("ModrinthApp"),
                Path::new(&userprofile).join(".modrinth"),
                Path::new(&localappdata).join("Packages").join("Microsoft.4297127D64ECE_8wekyb3d8bbwe"),
            ];
            
            for path in &mc_paths {
                if !path.as_os_str().is_empty() && path.exists() {
                    game.detected = true;
                    break;
                }
            }
        }
    }

    catalog
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scan_games_response() {
        let resp = ScanGamesResponse {
            name: "Test Game".to_string(),
            exe: "test.exe".to_string(),
            detected: false,
        };
        assert_eq!(resp.name, "Test Game");
        assert_eq!(resp.exe, "test.exe");
        assert!(!resp.detected);
    }
}
