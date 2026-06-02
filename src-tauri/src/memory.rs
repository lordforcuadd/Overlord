use serde::Serialize;
use sysinfo::System;
use std::sync::Mutex;

#[derive(Serialize, Clone)]
pub struct LiveMetricsResponse {
    pub cpu_usage: f32,
    pub ram_used: f64,
    pub ram_total: f64,
    pub ram_percentage: f32,
}

pub struct SystemStateCache {
    pub sys: Mutex<System>,
}

impl SystemStateCache {
    pub fn default() -> Self {
        let mut sys = System::new_all();
        sys.refresh_cpu();
        sys.refresh_memory();
        Self {
            sys: Mutex::new(sys),
        }
    }
}

pub fn get_live_metrics(cache: &SystemStateCache) -> LiveMetricsResponse {
    let mut sys = cache.sys.lock().unwrap();
    sys.refresh_cpu();
    sys.refresh_memory();

    let cpu_usage = sys.global_cpu_info().cpu_usage();
    let total_b = sys.total_memory() as f64;
    let used_b = sys.used_memory() as f64;

    let ram_total = (total_b / 1024.0 / 1024.0 / 1024.0 * 100.0).round() / 100.0;
    let ram_used = (used_b / 1024.0 / 1024.0 / 1024.0 * 100.0).round() / 100.0;
    let ram_percentage = ((used_b / total_b) * 100.0) as f32;

    LiveMetricsResponse {
        cpu_usage,
        ram_used,
        ram_total,
        ram_percentage,
    }
}