use std::os::windows::process::CommandExt;
use std::process::{Command, Stdio};
use std::io::Read;
use std::time::{Duration, Instant};

pub fn execute_script_safely(script_path: &str, args: Vec<&str>, timeout_secs: u64) -> Result<String, String> {
    let mut cmd = Command::new("powershell.exe");
    cmd.creation_flags(0x08000000);
    
    cmd.arg("-NoProfile")
       .arg("-NonInteractive")
       .arg("-ExecutionPolicy")
       .arg("Bypass")
       .arg("-File")
       .arg(script_path);

    for arg in args {
        if !arg.is_empty() {
            cmd.arg(arg);
        }
    }

    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());

    let mut child = cmd.spawn().map_err(|e| format!("Fallo al inicializar subproceso: {}", e))?;
    let start_time = Instant::now();
    let timeout = Duration::from_secs(timeout_secs);

    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                if status.success() {
                    let mut stdout_str = String::new();
                    if let Some(mut stdout) = child.stdout.take() {
                        let _ = stdout.read_to_string(&mut stdout_str);
                    }
                    return Ok(stdout_str.trim().to_string());
                } else {
                    let mut stderr_str = String::new();
                    if let Some(mut stderr) = child.stderr.take() {
                        let _ = stderr.read_to_string(&mut stderr_str);
                    }
                    return Err(format!("Error de script: {}. Código: {:?}", stderr_str.trim(), status.code()));
                }
            }
            Ok(None) => {
                if start_time.elapsed() >= timeout {
                    child.kill().map_err(|e| format!("No se pudo detener el proceso colgado: {}", e))?;
                    return Err(format!("Excedido el límite de tiempo de seguridad de {} segundos", timeout_secs));
                }
                std::thread::sleep(Duration::from_millis(50));
            }
            Err(e) => return Err(format!("Excepción durante el monitoreo del proceso: {}", e)),
        }
    }
}