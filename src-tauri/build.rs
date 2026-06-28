fn main() {
    let is_test = std::env::var("TAURI_NO_ADMIN").is_ok()
        || std::env::var("CARGO_FEATURE_NO_ADMIN").is_ok()
        || std::env::var("CI").is_ok();

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
