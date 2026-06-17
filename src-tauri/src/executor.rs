use tokio::process::Command;
use std::process::Stdio;
use tokio::sync::Mutex;
use tokio::io::AsyncWriteExt;

static EXECUTION_LOCK: Mutex<()> = Mutex::const_new(());

fn parse_qol_params(game_list: &str) -> (String, String) {
    let mut toggle_name = String::new();
    let mut is_enabled_str = String::new();

    if game_list.contains(':') {
        let parts: Vec<&str> = game_list.splitn(2, ':').collect();
        if parts.len() == 2 {
            toggle_name = parts[0].to_string();
            is_enabled_str = parts[1].to_string();
        }
    }
    (toggle_name, is_enabled_str)
}

fn build_script_header(is_laptop: bool, ram_gb: u32, game_list: &str, toggle_name: &str, is_enabled_str: &str) -> String {
    format!(
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
    )
}

fn encode_utf16_base64(script: &str) -> String {
    let utf16_units: Vec<u16> = script.encode_utf16().collect();
    let mut utf16_bytes = Vec::with_capacity(utf16_units.len() * 2);
    for unit in utf16_units {
        utf16_bytes.extend_from_slice(&unit.to_le_bytes());
    }
    custom_base64_encode(&utf16_bytes)
}

async fn execute_script_in_memory_impl(script_raw: &str, is_laptop: bool, ram_gb: u32, game_list: &str) -> Result<String, String> {
    let backup_module = include_str!("../scripts/backup_manager.psm1");
    let (toggle_name, is_enabled_str) = parse_qol_params(game_list);
    let header = build_script_header(is_laptop, ram_gb, game_list, &toggle_name, &is_enabled_str);
    let script_clean = strip_param_block(script_raw);

    let unified_script = format!(
        "{}\n{}\n{}",
        header,
        backup_module,
        script_clean
    );

    let b64_encoded = encode_utf16_base64(&unified_script);

    let bootstrap_cmd = "$r = [Console]::In.ReadToEnd(); if (![string]::IsNullOrEmpty($r)) { $b = $r.Trim(); $bytes = [System.Convert]::FromBase64String($b); $script = [System.Text.Encoding]::Unicode.GetString($bytes); Invoke-Expression $script }";
    let mut child = Command::new("powershell.exe")
        .creation_flags(0x08000000)
        .args(&[
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-WindowStyle", "Hidden",
            "-Command", bootstrap_cmd,
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Falla al inicializar el proceso PowerShell: {}", e))?;

    {
        let mut stdin = child.stdin.take().ok_or("No se pudo abrir el canal stdin de PowerShell".to_string())?;
        stdin.write_all(b64_encoded.as_bytes()).await.map_err(|e| format!("Error al escribir en stdin: {}", e))?;
    } 

    let output = child.wait_with_output().await.map_err(|e| format!("Error esperando la salida del proceso: {}", e))?;

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

pub async fn execute_script_in_memory(script_raw: &str, is_laptop: bool, ram_gb: u32, game_list: &str) -> Result<String, String> {
    let _lock = EXECUTION_LOCK.lock().await;
    execute_script_in_memory_impl(script_raw, is_laptop, ram_gb, game_list).await
}

pub async fn execute_script_in_memory_readonly(script_raw: &str, is_laptop: bool, ram_gb: u32, game_list: &str) -> Result<String, String> {
    execute_script_in_memory_impl(script_raw, is_laptop, ram_gb, game_list).await
}

fn strip_param_block(script: &str) -> String {
    let trimmed = script.trim_start();
    if trimmed.to_lowercase().starts_with("param") {
        if let Some(open_paren) = trimmed.find('(') {
            let mut depth = 0;
            let mut in_quote = false;
            let mut quote_char = ' ';
            let mut escape = false;
 
            for (idx, ch) in trimmed[open_paren..].char_indices() {
                if escape {
                    escape = false;
                    continue;
                }
                if in_quote {
                    if ch == '`' { escape = true; }
                    else if ch == quote_char { in_quote = false; }
                    continue;
                }
                if ch == '"' || ch == '\'' {
                    in_quote = true;
                    quote_char = ch;
                    continue;
                }
                if ch == '(' {
                    depth += 1;
                } else if ch == ')' {
                    depth -= 1;
                    if depth == 0 {
                        return trimmed[open_paren + idx + 1..].trim().to_string();
                    }
                }
            }
        }
    }
    script.to_string()
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