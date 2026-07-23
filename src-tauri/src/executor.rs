use tokio::process::Command;
use std::process::Stdio;
use tokio::sync::Mutex;
use tokio::io::AsyncWriteExt;
use std::sync::OnceLock;
use windows_sys::Win32::System::JobObjects::{
    CreateJobObjectW, SetInformationJobObject, JobObjectExtendedLimitInformation,
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
    AssignProcessToJobObject,
};
use windows_sys::Win32::System::Threading::{
    OpenProcess, PROCESS_SET_QUOTA, PROCESS_TERMINATE,
};
use windows_sys::Win32::Foundation::{HANDLE, CloseHandle};

const CREATE_NO_WINDOW: u32 = 0x0800_0000;

static EXECUTION_LOCK: Mutex<()> = Mutex::const_new(());

pub fn is_busy() -> bool {
    EXECUTION_LOCK.try_lock().is_err()
}

static JOB_HANDLE: OnceLock<HANDLE> = OnceLock::new();

fn get_job_handle() -> HANDLE {
    *JOB_HANDLE.get_or_init(|| unsafe {
        let handle = CreateJobObjectW(std::ptr::null(), std::ptr::null());
        if handle != 0 {
            let mut info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std::mem::zeroed();
            info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            SetInformationJobObject(
                handle,
                JobObjectExtendedLimitInformation,
                &info as *const _ as *const _,
                std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            );
        }
        handle
    })
}

fn assign_child_to_job(pid: u32) {
    let handle = get_job_handle();
    if handle != 0 {
        unsafe {
            let proc_handle = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE, 0, pid);
            if proc_handle != 0 {
                AssignProcessToJobObject(handle, proc_handle);
                CloseHandle(proc_handle);
            }
        }
    }
}

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

fn build_script_header(action_id: &str, is_laptop: bool, ram_gb: u32, game_list: &str, toggle_name: &str, is_enabled_str: &str, is_hybrid: bool, is_x3d: bool, is_ssd: bool) -> String {
    let game_list_b64 = encode_utf8_base64(game_list);
    let action_id_b64 = encode_utf8_base64(action_id);
    let toggle_name_b64 = encode_utf8_base64(toggle_name);
    let is_enabled_str_b64 = encode_utf8_base64(is_enabled_str);
    let version_b64 = encode_utf8_base64(env!("CARGO_PKG_VERSION"));

    format!(
        "$IsLaptop = ${}\n\
         $RamGB = {}\n\
         $GameList = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('{}'))\n\
         $ActionId = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('{}'))\n\
         $ToggleName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('{}'))\n\
         $IsEnabledStr = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('{}'))\n\
         $Version = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('{}'))\n\
         $IsHybrid = ${}\n\
         $IsX3d = ${}\n\
         $IsSsd = ${}\n\
         $ErrorActionPreference = 'Stop'\n",
        if is_laptop { "true" } else { "false" },
        ram_gb,
        game_list_b64,
        action_id_b64,
        toggle_name_b64,
        is_enabled_str_b64,
        version_b64,
        if is_hybrid { "true" } else { "false" },
        if is_x3d { "true" } else { "false" },
        if is_ssd { "true" } else { "false" }
    )
}

fn encode_utf8_base64(s: &str) -> String {
    custom_base64_encode(s.as_bytes())
}


fn encode_utf16_base64(script: &str) -> String {
    let utf16_units: Vec<u16> = script.encode_utf16().collect();
    let mut utf16_bytes = Vec::with_capacity(utf16_units.len() * 2);
    for unit in utf16_units {
        utf16_bytes.extend_from_slice(&unit.to_le_bytes());
    }
    custom_base64_encode(&utf16_bytes)
}

fn validate_input_string(s: &str) -> Result<(), String> {
    for c in s.chars() {
        if !c.is_alphanumeric() && c != '.' && c != '-' && c != '_' && c != ',' && c != ':' && c != '&' && c != '\'' && c != '+' && !c.is_whitespace() {
            return Err(format!("Caracter no permitido en el input: '{}'", c));
        }
    }
    Ok(())
}

async fn execute_script_in_memory_impl(action_id: &str, script_raw: &str, is_laptop: bool, ram_gb: u32, game_list: &str, is_hybrid: bool, is_x3d: bool, is_ssd: bool) -> Result<String, String> {
    validate_input_string(game_list)?;
    let (toggle_name, is_enabled_str) = parse_qol_params(game_list);
    let header = build_script_header(action_id, is_laptop, ram_gb, game_list, &toggle_name, &is_enabled_str, is_hybrid, is_x3d, is_ssd);
    let script_clean = strip_param_block(script_raw);

    let sid_resolver = include_str!("../scripts/sid_resolver.ps1");
    let unified_script = if action_id == "get_qol" || action_id == "get_modules_status" {
        format!(
            "{}\n{}\n{}",
            header,
            sid_resolver,
            script_clean
        )
    } else {
        let backup_module = include_str!("../scripts/backup_manager.psm1");
        let game_locator_module = include_str!("../scripts/game_locator.psm1");
        format!(
            "{}\n{}\n{}\n{}\n{}",
            header,
            sid_resolver,
            backup_module,
            game_locator_module,
            script_clean
        )
    };

    let b64_encoded = encode_utf16_base64(&unified_script);

    let bootstrap_cmd = "$r = [Console]::In.ReadToEnd(); if (![string]::IsNullOrEmpty($r)) { $b = $r.Trim(); $bytes = [System.Convert]::FromBase64String($b); $script = [System.Text.Encoding]::Unicode.GetString($bytes); & ([scriptblock]::Create($script)) }";
    let powershell_path = crate::get_powershell_path();
    
    let mut child = Command::new(&powershell_path)
        .creation_flags(CREATE_NO_WINDOW)
        .kill_on_drop(true)
        .args(&[
            "-NoProfile",
            "-NonInteractive",
            // NOTA: Bypass es intencional porque el script se pasa completo via stdin en memoria sin tocar disco
            "-ExecutionPolicy", "Bypass",
            "-WindowStyle", "Hidden",
            "-Command", bootstrap_cmd,
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Falla al inicializar el proceso PowerShell: {}", e))?;

    if let Some(pid) = child.id() {
        assign_child_to_job(pid);
    }

    {
        let mut stdin = child.stdin.take().ok_or("No se pudo abrir el canal stdin de PowerShell".to_string())?;
        stdin.write_all(b64_encoded.as_bytes()).await.map_err(|e| format!("Error al escribir en stdin: {}", e))?;
    } 

    const TIMEOUT_REPAIR_OS: u64 = 1200;
    const TIMEOUT_BASE: u64 = 300;
    const TIMEOUT_PER_GAME: u64 = 30;
    const TIMEOUT_HDD_PENALTY: u64 = 120;
    const TIMEOUT_MIN_HOOKS: u64 = 600;

    let mut timeout_secs = if game_list == "RepairOS" {
        TIMEOUT_REPAIR_OS
    } else {
        let num_games = if game_list.is_empty() { 0 } else { game_list.split(',').filter(|s| !s.trim().is_empty()).count() };
        let is_hdd = if is_ssd { 0 } else { 1 };
        TIMEOUT_BASE + (num_games as u64 * TIMEOUT_PER_GAME) + (is_hdd * TIMEOUT_HDD_PENALTY)
    };

    if (action_id == "11_game_hooks" || action_id == "12_defender_exclusions") && timeout_secs < TIMEOUT_MIN_HOOKS {
        timeout_secs = TIMEOUT_MIN_HOOKS;
    }

    let mut stdout = child.stdout.take().ok_or("No se pudo obtener stdout de PowerShell".to_string())?;
    let mut stderr = child.stderr.take().ok_or("No se pudo obtener stderr de PowerShell".to_string())?;

    let stdout_handle = tokio::spawn(async move {
        let mut buf = Vec::new();
        tokio::io::copy(&mut stdout, &mut buf).await.map(|_| buf)
    });
    let stderr_handle = tokio::spawn(async move {
        let mut buf = Vec::new();
        tokio::io::copy(&mut stderr, &mut buf).await.map(|_| buf)
    });

    let timeout_res = tokio::time::timeout(
        std::time::Duration::from_secs(timeout_secs),
        child.wait()
    ).await;

    let status = match timeout_res {
        Ok(Ok(st)) => st,
        Ok(Err(e)) => return Err(format!("Error esperando la salida del proceso: {}", e)),
        Err(_) => {
            let _ = child.kill().await;
            return Err("Timeout".into());
        }
    };

    let stdout_bytes = stdout_handle.await.map_err(|e| e.to_string())?.map_err(|e| e.to_string())?;
    let stderr_bytes = stderr_handle.await.map_err(|e| e.to_string())?.map_err(|e| e.to_string())?;

    if !status.success() {
        let error_str = String::from_utf8_lossy(&stderr_bytes).trim().to_string();
        return Err(if error_str.is_empty() {
            String::from_utf8_lossy(&stdout_bytes).trim().to_string()
        } else {
            error_str
        });
    }

    Ok(String::from_utf8_lossy(&stdout_bytes).trim().to_string())
}

pub async fn execute_script_in_memory(action_id: &str, script_raw: &str, is_laptop: bool, ram_gb: u32, game_list: &str, is_hybrid: bool, is_x3d: bool, is_ssd: bool) -> Result<String, String> {
    let _lock = EXECUTION_LOCK.lock().await;
    execute_script_in_memory_impl(action_id, script_raw, is_laptop, ram_gb, game_list, is_hybrid, is_x3d, is_ssd).await
}

pub async fn execute_script_in_memory_readonly(action_id: &str, script_raw: &str, is_laptop: bool, ram_gb: u32, game_list: &str, is_hybrid: bool, is_x3d: bool, is_ssd: bool) -> Result<String, String> {
    execute_script_in_memory_impl(action_id, script_raw, is_laptop, ram_gb, game_list, is_hybrid, is_x3d, is_ssd).await
}

fn strip_param_block(script: &str) -> String {
    let mut trimmed = script.trim_start();
    loop {
        if trimmed.starts_with('#') {
            if let Some(newline_idx) = trimmed.find('\n') {
                trimmed = trimmed[newline_idx + 1..].trim_start();
                continue;
            }
        }
        if trimmed.starts_with("<#") {
            if let Some(end_block) = trimmed.find("#>") {
                trimmed = trimmed[end_block + 2..].trim_start();
                continue;
            }
        }
        break;
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_strip_param_block_basic() {
        let script = "param(\n    [bool]$IsLaptop = $false\n)\nWrite-Host 'Hello'";
        assert_eq!(strip_param_block(script), "Write-Host 'Hello'");
    }

    #[test]
    fn test_strip_param_block_no_param() {
        let script = "Write-Host 'Hello'";
        assert_eq!(strip_param_block(script), "Write-Host 'Hello'");
    }

    #[test]
    fn test_strip_param_block_case_insensitive() {
        let script = "PARAM(\n    $Var\n)\nGet-Process";
        assert_eq!(strip_param_block(script), "Get-Process");
    }

    #[test]
    fn test_strip_param_block_nested_parens() {
        let script = "param(\n    $List = @('a', 'b'),\n    $Num = 3\n)\nStart-Process";
        assert_eq!(strip_param_block(script), "Start-Process");
    }

    #[test]
    fn test_strip_param_block_quotes_and_escapes() {
        let script = "param(\n    $Str = \"hello (world) `\" quote\"\n)\nGet-Service";
        assert_eq!(strip_param_block(script), "Get-Service");
    }

    #[test]
    fn test_strip_param_block_with_comments() {
        let script = "# Copyright Overlord\n<# Some description #>\nparam(\n    [string]$ActionId\n)\nGet-Process";
        assert_eq!(strip_param_block(script), "Get-Process");
    }

    #[test]
    fn test_custom_base64_encode() {
        assert_eq!(custom_base64_encode(b"any carnal w"), "YW55IGNhcm5hbCB3");
        assert_eq!(custom_base64_encode(b"any carnal we"), "YW55IGNhcm5hbCB3ZQ==");
        assert_eq!(custom_base64_encode(b"any carnal wen"), "YW55IGNhcm5hbCB3ZW4=");
        assert_eq!(custom_base64_encode(b""), "");
    }

    #[test]
    fn test_is_busy_initial_state() {
        assert_eq!(is_busy(), false);
    }

    #[tokio::test]
    async fn test_execute_script_in_memory_readonly_simple() {
        let script = "Write-Output 'Overlord Test Output'";
        let res = execute_script_in_memory_readonly("test_action", script, false, 16, "", false, false, true).await;
        assert!(res.is_ok(), "Expected script execution to succeed, got: {:?}", res);
        assert_eq!(res.unwrap(), "Overlord Test Output");
    }
}