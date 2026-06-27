fn main() {
    let mut is_test = false;

    if let Ok(output) = std::process::Command::new("powershell")
        .args(&[
            "-NoProfile",
            "-Command",
            "$p = Get-CimInstance Win32_Process -Filter \"ProcessId = $PID\"; while ($p -and $p.Name -notmatch 'cargo') { $p = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + $p.ParentProcessId) }; if ($p -and $p.CommandLine -match '\\btest\\b') { Write-Output 'test' }",
        ])
        .output()
    {
        let stdout = String::from_utf8_lossy(&output.stdout);
        if stdout.trim() == "test" {
            is_test = true;
        }
    }

    let level = if is_test { "asInvoker" } else { "requireAdministrator" };

    let windows = tauri_build::WindowsAttributes::new()
        .app_manifest(format!(r#"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" processorArchitecture="*" name="Overlord" type="win32"/>
  
  <dependency>
    <dependentAssembly>
      <assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*" />
    </dependentAssembly>
  </dependency>

  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="{}" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
"#, level));

    tauri_build::try_build(tauri_build::Attributes::new().windows_attributes(windows))
        .expect("Error al compilar Tauri");
}
