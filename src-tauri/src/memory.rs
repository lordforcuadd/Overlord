use sysinfo::{System};
use serde::Serialize;

#[derive(Serialize)]
pub struct LiveTelemetryResponse {
    pub cpu_usage: f32,
    pub ram_used_gb: f32,
    pub ram_total_gb: f32,
    pub ram_percent: f32,
}

pub fn fetch_live_metrics() -> LiveTelemetryResponse {
    let mut sys = System::new_all();
    sys.refresh_cpu();
    
    std::thread::sleep(std::time::Duration::from_millis(100));
    sys.refresh_cpu();

    let total_cpus = sys.cpus().len() as f32;
    let cpu_sum: f32 = sys.cpus().iter().map(|cpu| cpu.cpu_usage()).sum();
    let global_cpu = if total_cpus > 0.0 { cpu_sum / total_cpus } else { 0.0 };

    let total_ram_bytes = sys.total_memory();
    let used_ram_bytes = sys.used_memory();

    let ram_total_gb = total_ram_bytes as f32 / 1024.0 / 1024.0 / 1024.0;
    let ram_used_gb = used_ram_bytes as f32 / 1024.0 / 1024.0 / 1024.0;
    
    let ram_percent = if total_ram_bytes > 0 {
        (used_ram_bytes as f32 / total_ram_bytes as f32) * 100.0
    } else {
        0.0
    };

    LiveTelemetryResponse {
        cpu_usage: (global_cpu * 100.0).round() / 100.0,
        ram_used_gb: (ram_used_gb * 100.0).round() / 100.0,
        ram_total_gb: (ram_total_gb * 100.0).round() / 100.0,
        ram_percent: (ram_percent * 100.0).round() / 100.0,
    }
}