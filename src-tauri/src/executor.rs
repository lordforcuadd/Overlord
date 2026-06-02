use std::process::{Command, Stdio};
use std::io::Write;
use std::os::windows::process::CommandExt;
use std::sync::Mutex;

static EXECUTION_LOCK: Mutex<()> = Mutex::new(());

pub fn execute_script_in_memory(script_raw: &str, is_laptop: bool, ram_gb: u32, game_list: &str) -> Result<String, String> {
    let _lock = EXECUTION_LOCK.lock().map_err(|_| "Error al adquirir el candado de ejecucion concurrente".to_string())?;

    let backup_module = include_str!("../scripts/backup_manager.psm1");

    let mut toggle_name = String::new();
    let mut is_enabled_str = String::new();

    if game_list.contains(':') {
        let parts: Vec<&str> = game_list.splitn(2, ':').collect();
        if parts.len() == 2 {
            toggle_name = parts[0].to_string();
            is_enabled_str = parts[1].to_string();
        }
    }

    let header = format!(
        "$IsLaptop = ${}\n\
         $RamGB = {}\n\
         $GameList = '{}'\n\
         $ActionId = '{}'\n\
         $ToggleName = '{}'\n\
         $IsEnabledStr = '{}'\n\
         $ErrorActionPreference = 'Stop'\n",
        if is_laptop { "true" } else { "false" },
        ram_gb,
        game_list.replace("'", "''"),
        game_list.replace("'", "''"),
        toggle_name.replace("'", "''"),
        is_enabled_str.replace("'", "''")
    );

    let mut script_clean = script_raw.to_string();
    
    
    let is_real_param_block = {
        let mut is_param = false;
        for line in script_clean.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            if trimmed.to_lowercase().starts_with("param") {
                is_param = true;
            }
            break; 
        }
        is_param
    };

    if is_real_param_block {
        let lower_script = script_clean.to_lowercase();
        if let Some(param_start) = lower_script.find("param") {
            if let Some(start_paren) = lower_script[param_start..].find('(') {
                let actual_start_paren = param_start + start_paren;
                let mut depth = 0;
                let mut end_bytes_idx = None;
                
                for (idx, ch) in script_clean.char_indices() {
                    if idx >= actual_start_paren {
                        if ch == '(' {
                            depth += 1;
                        } else if ch == ')' {
                            depth -= 1;
                            if depth == 0 {
                                end_bytes_idx = Some(idx + ch.len_utf8());
                                break;
                            }
                        }
                    }
                }
                if let Some(idx) = end_bytes_idx {
                    script_clean = script_clean[idx..].trim().to_string();
                }
            }
        }
    }

    let unified_script = format!(
        "{}\n{}\n{}",
        header,
        backup_module,
        script_clean
    );

    let utf16_units: Vec<u16> = unified_script.encode_utf16().collect();
    let mut utf16_bytes = Vec::with_capacity(utf16_units.len() * 2);
    for unit in utf16_units {
        utf16_bytes.extend_from_slice(&unit.to_le_bytes());
    }

    let b64_encoded = custom_base64_encode(&utf16_bytes);

    let bootstrap_cmd = "$b64 = [Console]::In.ReadToEnd(); $bytes = [System.Convert]::FromBase64String($b64); $script = [System.Text.Encoding]::Unicode.GetString($bytes); Invoke-Expression $script";

    let mut child = Command::new("powershell.exe")
        .creation_flags(0x08000000)
        .args(&[
            "-NoProfile",
            "-NonInteractive",
            "-WindowStyle",
            "Hidden",
            "-Command",
            bootstrap_cmd,
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Falla al inicializar el proceso PowerShell: {}", e))?;

    {
        let mut stdin = child.stdin.take().ok_or("No se pudo abrir el canal stdin de PowerShell".to_string())?;
        stdin.write_all(b64_encoded.as_bytes()).map_err(|e| format!("Error al escribir en stdin: {}", e))?;
    } 

    let output = child.wait_with_output().map_err(|e| format!("Error esperando la salida del proceso: {}", e))?;

    if !output.status.success() {
        let error_str = String::from_utf8_lossy(&output.stderr).trim().to_string();
        return Err(if error_str.is_empty() {
            String::from_utf8_lossy(&output.stdout).trim().to_string()
        } else {
            error_str
        });
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn custom_base64_encode(bytes: &[u8]) -> String {
    const CHARSET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut result = String::with_capacity((bytes.len() + 2) / 3 * 4);
    let mut i = 0;

    while i < bytes.len() {
        let rem = bytes.len() - i;
        if rem >= 3 {
            let chunk = (bytes[i] as u32) << 16 | (bytes[i + 1] as u32) << 8 | (bytes[i + 2] as u32);
            result.push(CHARSET[((chunk >> 18) & 63) as usize] as char);
            result.push(CHARSET[((chunk >> 12) & 63) as usize] as char);
            result.push(CHARSET[((chunk >> 6) & 63) as usize] as char);
            result.push(CHARSET[(chunk & 63) as usize] as char);
            i += 3;
        } else if rem == 2 {
            let chunk = (bytes[i] as u32) << 16 | (bytes[i + 1] as u32) << 8;
            result.push(CHARSET[((chunk >> 18) & 63) as usize] as char);
            result.push(CHARSET[((chunk >> 12) & 63) as usize] as char);
            result.push(CHARSET[((chunk >> 6) & 63) as usize] as char);
            result.push('=');
            i += 2;
        } else if rem == 1 {
            let chunk = (bytes[i] as u32) << 16;
            result.push(CHARSET[((chunk >> 18) & 63) as usize] as char);
            result.push(CHARSET[((chunk >> 12) & 63) as usize] as char);
            result.push('=');
            result.push('=');
            i += 1;
        }
    }
    result
}