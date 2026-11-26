use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};

use anyhow::anyhow;
use flutter_rust_bridge::frb;
use libreget_core::core::paths::{app_data_dir, set_mobile_data_dir};
use libreget_core::models::media::{DownloadOptions, MediaType};
use libreget_core::models::progress::ProgressUpdate;
use libreget_core::platforms::{InstagramDownloader, Platform, PlatformDownloader, TikTokDownloader};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

use crate::api::queue::ensure_queue_schema;
use crate::frb_generated::StreamSink;

static ACTIVE_CANCELLATIONS: OnceLock<Mutex<HashMap<String, CancellationToken>>> = OnceLock::new();

fn cancellation_map() -> &'static Mutex<HashMap<String, CancellationToken>> {
    ACTIVE_CANCELLATIONS.get_or_init(|| Mutex::new(HashMap::new()))
}

struct ActiveTaskGuard {
    task_id: String,
}

impl Drop for ActiveTaskGuard {
    fn drop(&mut self) {
        if let Ok(mut guard) = cancellation_map().lock() {
            guard.remove(&self.task_id);
        }
    }
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SupportedPlatform {
    TikTok,
    Instagram,
    YouTube,
    Unsupported,
}

#[derive(Debug, Clone)]
pub struct NativeQualityOption {
    pub label: String,
    pub width: u32,
    pub height: u32,
    pub url: String,
    pub format: String,
}

#[derive(Debug, Clone)]
pub struct NativeMediaInfo {
    pub title: String,
    pub author: String,
    pub platform: String,
    pub duration_seconds: Option<f64>,
    pub thumbnail_url: Option<String>,
    pub media_type: String,
    pub qualities: Vec<NativeQualityOption>,
}

#[derive(Debug, Clone)]
pub struct NativeProgressEvent {
    pub percent: f64,
    pub downloaded_bytes: Option<u64>,
    pub total_bytes: Option<u64>,
    pub speed_bps: Option<f64>,
    pub eta_seconds: Option<u64>,
    pub phase: Option<String>,
}

#[derive(Debug, Clone)]
pub struct NativeDownloadResult {
    pub file_path: String,
    pub file_size_bytes: u64,
    pub duration_seconds: f64,
}

fn sanitize_domain(domain: &str) -> anyhow::Result<String> {
    let cleaned = domain.trim().trim_start_matches('.').to_ascii_lowercase();
    if cleaned.is_empty()
        || !cleaned
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-')
    {
        return Err(anyhow!("Invalid domain for cookie storage"));
    }
    Ok(cleaned)
}

fn format_media_type(mt: &MediaType) -> String {
    match mt {
        MediaType::Video => "video",
        MediaType::Audio => "audio",
        MediaType::Photo => "photo",
        MediaType::Gif => "gif",
        MediaType::Carousel => "carousel",
        MediaType::Playlist => "playlist",
        MediaType::Course => "course",
        MediaType::File => "file",
    }
    .to_string()
}

pub fn init_core(data_dir: String) -> anyhow::Result<()> {
    let base = PathBuf::from(data_dir);
    std::fs::create_dir_all(base.join("cookies"))?;
    set_mobile_data_dir(base);
    ensure_queue_schema()?;
    Ok(())
}

#[frb(sync)]
pub fn detect_platform(url: String) -> SupportedPlatform {
    match Platform::detect(&url) {
        Some(Platform::TikTok) => SupportedPlatform::TikTok,
        Some(Platform::Instagram) => SupportedPlatform::Instagram,
        Some(Platform::YouTube) => SupportedPlatform::YouTube,
        None => SupportedPlatform::Unsupported,
    }
}

pub async fn probe_native_media(url: String) -> anyhow::Result<NativeMediaInfo> {
    let platform = Platform::detect(&url)
        .ok_or_else(|| anyhow!("UNSUPPORTED_PLATFORM: URL must belong to TikTok, Instagram, or YouTube"))?;

    let info = match platform {
        Platform::Instagram => InstagramDownloader::new().get_media_info(&url).await?,
        Platform::TikTok => TikTokDownloader::new().get_media_info(&url).await?,
        Platform::YouTube => {
            return Err(anyhow!(
                "ROUTE_YTDLP: YouTube URLs are routed to Android youtubedl-android"
            ));
        }
    };

    Ok(NativeMediaInfo {
        title: info.title,
        author: info.author,
        platform: info.platform,
        duration_seconds: info.duration_seconds,
        thumbnail_url: info.thumbnail_url,
        media_type: format_media_type(&info.media_type),
        qualities: info
            .available_qualities
            .into_iter()
            .map(|q| NativeQualityOption {
                label: q.label,
                width: q.width,
                height: q.height,
                url: q.url,
                format: q.format,
            })
            .collect(),
    })
}

pub async fn download_native_media(
    task_id: String,
    url: String,
    output_dir: String,
    quality: Option<String>,
    audio_only: bool,
    sink: StreamSink<NativeProgressEvent>,
) -> anyhow::Result<NativeDownloadResult> {
    let platform = Platform::detect(&url)
        .ok_or_else(|| anyhow!("UNSUPPORTED_PLATFORM: URL must belong to TikTok, Instagram, or YouTube"))?;

    if platform == Platform::YouTube {
        return Err(anyhow!(
            "ROUTE_YTDLP: YouTube downloads must execute through Android youtubedl-android"
        ));
    }

    let out_path = PathBuf::from(&output_dir);
    tokio::fs::create_dir_all(&out_path).await?;

    let cancel_token = CancellationToken::new();
    if let Ok(mut guard) = cancellation_map().lock() {
        guard.insert(task_id.clone(), cancel_token.clone());
    }
    let _guard = ActiveTaskGuard {
        task_id: task_id.clone(),
    };

    let opts = DownloadOptions {
        quality,
        output_dir: out_path,
        filename_template: None,
        download_subtitles: false,
        include_auto_subtitles: false,
        download_mode: audio_only.then(|| "audio".to_string()),
        audio_format: audio_only.then(|| "m4a".to_string()),
        format_id: None,
        referer: None,
        extra_headers: None,
        page_url: Some(url.clone()),
        user_agent: None,
        cancel_token,
        concurrent_fragments: 4,
        ytdlp_path: None,
        torrent_listen_port: None,
        torrent_id_slot: None,
        custom_ytdlp_args: None,
        torrent_files: None,
        torrent_auto_trackers: false,
        torrent_upnp: false,
    };

    let (tx, mut rx) = mpsc::channel::<ProgressUpdate>(32);
    let forward_handle = tokio::spawn(async move {
        while let Some(update) = rx.recv().await {
            let _ = sink.add(NativeProgressEvent {
                percent: update.percent,
                downloaded_bytes: update.downloaded_bytes,
                total_bytes: update.total_bytes,
                speed_bps: update.speed_bps,
                eta_seconds: update.eta_seconds,
                phase: update.phase,
            });
        }
    });

    let result = match platform {
        Platform::Instagram => {
            let downloader = InstagramDownloader::new();
            let info = downloader.get_media_info(&url).await?;
            downloader.download(&info, &opts, tx).await
        }
        Platform::TikTok => {
            let downloader = TikTokDownloader::new();
            let info = downloader.get_media_info(&url).await?;
            downloader.download(&info, &opts, tx).await
        }
        Platform::YouTube => unreachable!(),
    };

    let _ = forward_handle.await;

    let done = result?;
    Ok(NativeDownloadResult {
        file_path: done.file_path.to_string_lossy().to_string(),
        file_size_bytes: done.file_size_bytes,
        duration_seconds: done.duration_seconds,
    })
}

#[frb(sync)]
pub fn cancel_native_download(task_id: String) -> bool {
    if let Ok(guard) = cancellation_map().lock() {
        if let Some(token) = guard.get(&task_id) {
            token.cancel();
            return true;
        }
    }
    false
}

pub fn save_netscape_cookies(domain: String, netscape_content: String) -> anyhow::Result<String> {
    let clean_domain = sanitize_domain(&domain)?;
    let cookies_dir = app_data_dir()
        .ok_or_else(|| anyhow!("Core data directory unavailable"))?
        .join("cookies");
    std::fs::create_dir_all(&cookies_dir)?;

    let domain_dir = cookies_dir.join(&clean_domain);
    std::fs::create_dir_all(&domain_dir)?;
    let domain_file = domain_dir.join("default.txt");
    std::fs::write(&domain_file, &netscape_content)?;

    // Also update shared cookies.txt so DefaultCookieProvider and yt-dlp share session state.
    let shared_file = cookies_dir.join("cookies.txt");
    let mut merged = String::from("# Netscape HTTP Cookie File\n");
    if let Ok(existing) = std::fs::read_to_string(&shared_file) {
        for line in existing.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("# Netscape") {
                continue;
            }
            let effective = trimmed.strip_prefix("#HttpOnly_").unwrap_or(trimmed);
            if effective.starts_with('#') {
                continue;
            }
            let host = effective
                .split('\t')
                .next()
                .unwrap_or("")
                .trim_start_matches('.')
                .to_ascii_lowercase();
            if host != clean_domain && !host.ends_with(&format!(".{clean_domain}")) {
                merged.push_str(trimmed);
                merged.push('\n');
            }
        }
    }
    for line in netscape_content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("# Netscape") {
            continue;
        }
        merged.push_str(trimmed);
        merged.push('\n');
    }
    std::fs::write(&shared_file, merged)?;

    Ok(shared_file.to_string_lossy().to_string())
}

pub fn clear_domain_cookies(domain: String) -> anyhow::Result<()> {
    let clean_domain = sanitize_domain(&domain)?;
    let cookies_dir = app_data_dir()
        .ok_or_else(|| anyhow!("Core data directory unavailable"))?
        .join("cookies");

    let domain_dir = cookies_dir.join(&clean_domain);
    if domain_dir.exists() {
        std::fs::remove_dir_all(domain_dir)?;
    }

    let shared_file = cookies_dir.join("cookies.txt");
    if let Ok(existing) = std::fs::read_to_string(&shared_file) {
        let mut kept = String::from("# Netscape HTTP Cookie File\n");
        for line in existing.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("# Netscape") {
                continue;
            }
            let effective = trimmed.strip_prefix("#HttpOnly_").unwrap_or(trimmed);
            let host = effective
                .split('\t')
                .next()
                .unwrap_or("")
                .trim_start_matches('.')
                .to_ascii_lowercase();
            if host != clean_domain && !host.ends_with(&format!(".{clean_domain}")) {
                kept.push_str(trimmed);
                kept.push('\n');
            }
        }
        std::fs::write(&shared_file, kept)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detect_platform_enforces_three_platform_scope() {
        assert_eq!(
            detect_platform("https://www.tiktok.com/@creator/video/123456".to_string()),
            SupportedPlatform::TikTok
        );
        assert_eq!(
            detect_platform("https://www.instagram.com/reel/Cxyz123/".to_string()),
            SupportedPlatform::Instagram
        );
        assert_eq!(
            detect_platform("https://youtu.be/dQw4w9WgXcQ".to_string()),
            SupportedPlatform::YouTube
        );
        assert_eq!(
            detect_platform("https://x.com/rustlang/status/123".to_string()),
            SupportedPlatform::Unsupported
        );
    }
}
