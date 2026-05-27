use serde::Serialize;
use sysinfo::{System, CpuRefreshKind, RefreshKind};

#[derive(Serialize, Clone)]
pub struct LiveTelemetryResponse {
    pub cpu_usage: f64,
    pub ram_used_gb: f64,
    pub ram_total_gb: f64,
    pub ram_percent: f64,
}

pub fn fetch_live_metrics() -> LiveTelemetryResponse {
    let mut sys = System::new_with_specifics(
        RefreshKind::new().with_cpu(CpuRefreshKind::everything())
    );
    sys.refresh_memory();
    sys.refresh_cpu();

    std::thread::sleep(std::time::Duration::from_millis(100));
    sys.refresh_cpu();

    let global_cpu = sys.global_cpu_info().cpu_usage() as f64;
    
    let total_b = sys.total_memory() as f64;
    let used_b = sys.used_memory() as f64;

    let total_gb = total_b / 1024.0 / 1024.0 / 1024.0;
    let used_gb = used_b / 1024.0 / 1024.0 / 1024.0;
    
    let percent = if total_b > 0.0 { (used_b / total_b) * 100.0 } else { 0.0 };

    LiveTelemetryResponse {
        cpu_usage: global_cpu,
        ram_used_gb: used_gb,
        ram_total_gb: total_gb,
        ram_percent: percent,
    }
}