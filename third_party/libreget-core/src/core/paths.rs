use std::path::PathBuf;
use std::sync::OnceLock;

static MOBILE_DATA_DIR: OnceLock<PathBuf> = OnceLock::new();

/// Sets the mobile application support/data directory provided by Flutter (`path_provider`).
pub fn set_mobile_data_dir(path: PathBuf) {
    let _ = std::fs::create_dir_all(&path);
    let _ = MOBILE_DATA_DIR.set(path);
}

pub fn app_data_dir() -> Option<PathBuf> {
    if let Some(dir) = MOBILE_DATA_DIR.get() {
        return Some(dir.clone());
    }

    if let Ok(dir) = std::env::var("LIBREGET_DATA_DIR") {
        let path = PathBuf::from(dir);
        let _ = std::fs::create_dir_all(&path);
        return Some(path);
    }

    let base = dirs::data_dir()?;
    let new_path = base.join("io.github.fyou00.klipfetch");
    let _ = std::fs::create_dir_all(&new_path);
    Some(new_path)
}

pub fn mobile_cookie_file() -> Option<PathBuf> {
    let path = app_data_dir()?.join("cookies").join("cookies.txt");
    path.exists().then_some(path)
}
