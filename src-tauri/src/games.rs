use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::OnceLock;
use winreg::enums::*;
use winreg::RegKey;

#[derive(Deserialize, Debug, Clone)]
#[allow(dead_code)]
pub struct RegistryKeyEntry {
    pub hive: String,
    pub path: String,
    pub value: String,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
pub struct SteamConfig {
    pub registry_keys: Vec<RegistryKeyEntry>,
    pub apps_registry_path: String,
    pub library_folders_rel_path: String,
    pub common_rel_path: String,
    pub program_files_sub_path: String,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
pub struct EpicConfig {
    pub registry_keys: Vec<RegistryKeyEntry>,
    pub manifests_rel_path: String,
    pub default_folder: String,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
pub struct GogConfig {
    pub registry_keys: Vec<String>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
pub struct RiotConfig {
    pub default_folder: String,
    pub games: Vec<String>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
pub struct MinecraftConfig {
    pub user_profile_paths: Vec<String>,
    pub app_data_paths: Vec<String>,
    pub local_app_data_paths: Vec<String>,
    pub java_registry_keys: Vec<String>,
    pub java_app_path: String,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
pub struct LaunchersConfig {
    pub steam: SteamConfig,
    pub epic: EpicConfig,
    pub gog: GogConfig,
    pub riot: RiotConfig,
    pub fixed_drive_roots: Vec<String>,
    pub default_program_files_roots: Vec<String>,
    pub minecraft: MinecraftConfig,
}

pub fn get_launchers_config() -> &'static LaunchersConfig {
    static CONFIG: OnceLock<LaunchersConfig> = OnceLock::new();
    CONFIG.get_or_init(|| {
        let json_str = include_str!("../launchers_config.json");
        serde_json::from_str(json_str).expect("launchers_config.json must be valid JSON")
    })
}

#[derive(Serialize, Clone)]
pub struct ScanGamesResponse {
    pub name: String,
    pub exe: String,
    pub detected: bool,
}

fn get_steam_library_paths() -> Vec<String> {
    let config = get_launchers_config();
    let program_files = std::env::var("ProgramFiles").unwrap_or_else(|_| "C:\\Program Files".to_string());
    let program_files_x86 = std::env::var("ProgramFiles(x86)").unwrap_or_else(|_| "C:\\Program Files (x86)".to_string());
    let mut paths = vec![
        format!("{}\\{}", program_files, config.steam.program_files_sub_path),
        format!("{}\\{}", program_files_x86, config.steam.program_files_sub_path),
    ];

    for reg_entry in &config.steam.registry_keys {
        let root = if reg_entry.hive == "HKLM" {
            RegKey::predef(HKEY_LOCAL_MACHINE)
        } else {
            RegKey::predef(HKEY_CURRENT_USER)
        };

        if let Ok(steam_key) = root.open_subkey(&reg_entry.path) {
            if let Ok(steam_path) = steam_key.get_value::<String, _>(&reg_entry.value) {
                let vdf_path = Path::new(&steam_path).join(&config.steam.library_folders_rel_path);
                if let Ok(content) = std::fs::read_to_string(vdf_path) {
                    for line in content.lines() {
                        if line.contains("\"path\"") {
                            let parts: Vec<&str> = line.split('"').collect();
                            if parts.len() >= 4 {
                                let p = parts[3].replace("\\\\", "\\");
                                let common_path = Path::new(&p).join(&config.steam.common_rel_path);
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
    }
    paths
}

fn get_epic_installed_games() -> Vec<(String, String)> {
    let config = get_launchers_config();
    let mut games = Vec::new();
    let program_data = std::env::var("ProgramData").unwrap_or_else(|_| "C:\\ProgramData".to_string());
    let manifests_path = Path::new(&program_data).join(&config.epic.manifests_rel_path);
    if manifests_path.exists() {
        if let Ok(entries) = std::fs::read_dir(manifests_path) {
            for entry in entries.flatten() {
                if entry.path().extension().is_some_and(|ext| ext == "item") {
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

    let config = get_launchers_config();
    if let Ok(steam_key) = hkcu.open_subkey(&config.steam.apps_registry_path) {
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
                    if entry.path().extension().is_some_and(|ext| ext == "acf") {
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

    for path in &config.gog.registry_keys {
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

    let mut common_epic_paths = vec![format!("{}\\{}", program_files, config.epic.default_folder)];
    for drive in &active_drives {
        let path = Path::new(drive).join(&config.epic.default_folder);
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
        let riot_path = Path::new(drive).join(&config.riot.default_folder);
        if riot_path.exists() {
            for riot_game in &config.riot.games {
                if riot_path.join(riot_game).exists() {
                    for game in catalog.iter_mut() {
                        if game.name == *riot_game { game.detected = true; }
                    }
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

            let mut mc_paths = Vec::new();
            for sub in &config.minecraft.user_profile_paths {
                if !userprofile.is_empty() { mc_paths.push(Path::new(&userprofile).join(sub)); }
            }
            for sub in &config.minecraft.app_data_paths {
                if !appdata.is_empty() { mc_paths.push(Path::new(&appdata).join(sub)); }
            }
            for sub in &config.minecraft.local_app_data_paths {
                if !localappdata.is_empty() { mc_paths.push(Path::new(&localappdata).join(sub)); }
            }

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
    fn test_launchers_config_is_valid() {
        let config = get_launchers_config();
        assert!(!config.steam.registry_keys.is_empty());
        assert!(!config.epic.manifests_rel_path.is_empty());
        assert!(!config.riot.games.is_empty());
        assert!(!config.minecraft.app_data_paths.is_empty());
    }

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

    #[test]
    fn test_collect_installed_games_returns_catalog() {
        let games = collect_installed_games();
        assert!(!games.is_empty(), "Catalog should contain default games");
        assert!(games.iter().any(|g| g.name == "VALORANT"));
        assert!(games.iter().any(|g| g.name == "Minecraft"));
    }

    #[test]
    fn test_get_epic_installed_games_does_not_panic() {
        let epic = get_epic_installed_games();
        // Validar que cualquier juego devuelto posea un nombre y ejecutable no vacíos
        assert!(epic.iter().all(|(name, exe)| !name.is_empty() && !exe.is_empty()));
    }
}

