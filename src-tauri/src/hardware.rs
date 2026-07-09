use serde::Serialize;
use std::path::Path;
use winreg::enums::*;
use winreg::RegKey;
use std::os::windows::process::CommandExt;
use sysinfo::System;
use tokio::sync::RwLock;

const CREATE_NO_WINDOW: u32 = 0x0800_0000;

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct HardwareResponse {
    pub cpu: String,
    pub cpu_brand: String,
    pub cpu_vendor: String,
    pub cpu_frequency: u64,
    pub gpu: String,
    pub motherboard: String,
    pub ram_gb: u32,
    pub ram_speed_mhz: Option<u32>,
    pub is_laptop: bool,
    pub is_hybrid: bool,
    pub is_x3d: bool,
    pub is_ssd: bool,
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

static HARDWARE_CACHE: RwLock<Option<HardwareResponse>> = RwLock::const_new(None);

pub async fn get_system_hardware(force_refresh: bool) -> HardwareResponse {
    if !force_refresh {
        let cache = HARDWARE_CACHE.read().await;
        if let Some(ref hw) = *cache {
            return hw.clone();
        }
    }

    let hw = detect_system_hardware().await;

    let mut cache = HARDWARE_CACHE.write().await;
    *cache = Some(hw.clone());
    hw
}

async fn detect_system_hardware() -> HardwareResponse {
        // 1. Consultar velocidad de RAM de forma asíncrona mediante PowerShell/CIM (método moderno compatible con 24H2)
        let system_root = std::env::var("SystemRoot").unwrap_or_else(|_| "C:\\Windows".to_string());
        let powershell_path = format!("{}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", system_root);
        
        let mut ram_speed_val = None;
        let mut cmd = tokio::process::Command::new(&powershell_path);
        cmd.creation_flags(CREATE_NO_WINDOW)
           .args(&[
               "-NoProfile",
               "-Command",
               "(Get-CimInstance Win32_PhysicalMemory | Select-Object -ExpandProperty ConfiguredClockSpeed -First 1)",
           ]);
        
        if let Ok(output) = cmd.output().await {
            if output.status.success() {
                let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
                if let Ok(speed) = text.parse::<u32>() {
                    if speed > 0 {
                        ram_speed_val = Some(speed);
                    }
                }
            }
        }

        // 2. Ejecutar el resto de las consultas síncronas en un hilo de bloqueo
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

            let cpus = sys.cpus();
            let cpu_brand = cpus.first().map(|cpu| cpu.brand().trim().to_string()).unwrap_or_else(|| cpu_name.clone());
            let cpu_vendor = cpus.first().map(|cpu| cpu.vendor_id().trim().to_string()).unwrap_or_else(|| "Unknown".to_string());
            let cpu_frequency = cpus.first().map(|cpu| cpu.frequency()).unwrap_or(0);

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
                    Ok(matches!(chassis_type, 8 | 9 | 10 | 11 | 12 | 14 | 30 | 31 | 32))
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

            let mut drive_is_ssd = false;
            let system_drive = std::env::var("SystemDrive").unwrap_or_else(|_| "C:".to_string());
            let path_drive_str = format!("\\\\.\\{}", system_drive);
            let path_drive: Vec<u16> = path_drive_str.encode_utf16().chain(std::iter::once(0)).collect();
            let mut handle_ok = false;
            unsafe {
                let handle = CreateFileW(path_drive.as_ptr(), 0x80000000, 0x00000001 | 0x00000002, std::ptr::null_mut(), 3, 0x00000080, std::ptr::null_mut());
                if handle != (-1isize as *mut std::ffi::c_void) && !handle.is_null() {
                    handle_ok = true;
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

            if !handle_ok {
                // Fallback no-privilegiado vía PowerShell / Get-PhysicalDisk
                let ps_path = format!("{}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", system_root);
                let output = std::process::Command::new(&ps_path)
                    .creation_flags(CREATE_NO_WINDOW)
                    .args(&[
                        "-NoProfile",
                        "-Command",
                        "(Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'SSD' })",
                    ])
                    .output();
                if let Ok(out) = output {
                    if out.status.success() {
                        let text = String::from_utf8_lossy(&out.stdout).trim().to_string();
                        if !text.is_empty() {
                            drive_is_ssd = true;
                        }
                    }
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
                cpu_brand,
                cpu_vendor,
                cpu_frequency,
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
                cpu_brand: "Error al detectar CPU".to_string(),
                cpu_vendor: "Desconocido".to_string(),
                cpu_frequency: 0,
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
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hardware_response() {
        let resp = HardwareResponse {
            cpu: "Test".to_string(),
            cpu_brand: "Test Brand".to_string(),
            cpu_vendor: "Test Vendor".to_string(),
            cpu_frequency: 3000,
            gpu: "Test GPU".to_string(),
            motherboard: "Test Mobo".to_string(),
            ram_gb: 16,
            ram_speed_mhz: Some(3200),
            is_laptop: false,
            is_hybrid: false,
            is_x3d: false,
            is_ssd: true,
        };
        assert_eq!(resp.cpu, "Test");
        assert_eq!(resp.ram_gb, 16);
    }
}
