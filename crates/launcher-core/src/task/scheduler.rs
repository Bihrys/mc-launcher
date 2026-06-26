use std::thread;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SchedulerKind {
    Default,
    Io,
    Cpu,
    CurrentThread,
}

pub struct Schedulers;

impl Schedulers {
    pub fn spawn(name: &str, f: impl FnOnce() + Send + 'static) -> thread::JoinHandle<()> {
        thread::Builder::new()
            .name(name.to_string())
            .spawn(f)
            .unwrap_or_else(|_| thread::spawn(|| {}))
    }
}
