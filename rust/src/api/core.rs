use std::collections::HashMap;
use std::path::{Path, PathBuf};
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
    pub output_path: Option<String>,
}

#[derive(Debug, Clone)]
pub struct CookieDomainStatus {
    pub domain: String,
    pub has_cookies: bool,
    pub cookie_count: u32,
    pub has_auth_cookie: bool,
    pub updated_at_ms: Option<i64>,
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

fn related_cookie_domains(clean_domain: &str) -> Vec<&'static str> {
    match clean_domain {
        "youtube.com" => vec!["youtube.com", "google.com"],
        "instagram.com" => vec!["instagram.com", "cdninstagram.com"],
        "tiktok.com" => vec!["tiktok.com", "tiktokv.com"],
        _ => vec![],
    }
}

fn host_matches_domain(host: &str, domain: &str) -> bool {
    host == domain || host.ends_with(&format!(".{domain}"))
}

fn host_belongs_to_domain_group(host: &str, clean_domain: &str) -> bool {
    if host_matches_domain(host, clean_domain) {
        return true;
    }
    related_cookie_domains(clean_domain)
        .into_iter()
        .any(|related| host_matches_domain(host, related))
}

fn is_auth_cookie_for_domain(clean_domain: &str, cookie_name: &str) -> bool {
    match clean_domain {
        "instagram.com" => matches!(cookie_name, "sessionid" | "ds_user_id"),
        "tiktok.com" => matches!(cookie_name, "sessionid" | "sid_tt" | "sessionid_ss"),
        "youtube.com" => matches!(
            cookie_name,
            "SAPISID" | "SID" | "LOGIN_INFO" | "__Secure-3PSID" | "__Secure-1PSID"
        ),
        _ => false,
    }
}

fn parse_netscape_cookie_line(trimmed: &str) -> Option<(String, String)> {
    if trimmed.is_empty() || trimmed.starts_with("# Netscape") {
        return None;
    }
    let effective = trimmed.strip_prefix("#HttpOnly_").unwrap_or(trimmed);
    if effective.starts_with('#') {
        return None;
    }
    let parts: Vec<&str> = effective.split('\t').collect();
    if parts.len() < 7 {
        return None;
    }
    let host = parts[0].trim().trim_start_matches('.').to_ascii_lowercase();
    let name = parts[5].trim().to_string();
    if host.is_empty() || name.is_empty() {
        return None;
    }
    Some((host, name))
}

fn filter_out_domain_lines(existing: &str, clean_domain: &str) -> String {
    let mut kept = String::from("# Netscape HTTP Cookie File\n");
    for line in existing.lines() {
        let trimmed = line.trim();
        let Some((host, _name)) = parse_netscape_cookie_line(trimmed) else {
            continue;
        };
        if !host_belongs_to_domain_group(&host, clean_domain) {
            kept.push_str(trimmed);
            kept.push('\n');
        }
    }
    kept
}

fn save_netscape_cookies_in(
    base_dir: &Path,
    domain: &str,
    netscape_content: &str,
) -> anyhow::Result<String> {
    let clean_domain = sanitize_domain(domain)?;
    let cookies_dir = base_dir.join("cookies");
    std::fs::create_dir_all(&cookies_dir)?;

    let domain_dir = cookies_dir.join(&clean_domain);
    std::fs::create_dir_all(&domain_dir)?;
    let domain_file = domain_dir.join("default.txt");
    std::fs::write(&domain_file, netscape_content)?;

    // Also update shared cookies.txt so DefaultCookieProvider and yt-dlp share session state.
    let shared_file = cookies_dir.join("cookies.txt");
    let mut merged = match std::fs::read_to_string(&shared_file) {
        Ok(existing) => filter_out_domain_lines(&existing, &clean_domain),
        Err(_) => String::from("# Netscape HTTP Cookie File\n"),
    };
    for line in netscape_content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("# Netscape") {
            continue;
        }
        let effective = trimmed.strip_prefix("#HttpOnly_").unwrap_or(trimmed);
        if effective.starts_with('#') {
            continue;
        }
        merged.push_str(trimmed);
        merged.push('\n');
    }
    std::fs::write(&shared_file, merged)?;

    Ok(shared_file.to_string_lossy().to_string())
}

fn clear_domain_cookies_in(base_dir: &Path, domain: &str) -> anyhow::Result<()> {
    let clean_domain = sanitize_domain(domain)?;
    let cookies_dir = base_dir.join("cookies");

    let domain_dir = cookies_dir.join(&clean_domain);
    if domain_dir.exists() {
        std::fs::remove_dir_all(domain_dir)?;
    }

    let shared_file = cookies_dir.join("cookies.txt");
    if let Ok(existing) = std::fs::read_to_string(&shared_file) {
        let kept = filter_out_domain_lines(&existing, &clean_domain);
        std::fs::write(&shared_file, kept)?;
    }
    Ok(())
}

fn get_cookie_domain_status_in(
    base_dir: &Path,
    domain: &str,
) -> anyhow::Result<CookieDomainStatus> {
    let clean_domain = sanitize_domain(domain)?;
    let domain_file = base_dir
        .join("cookies")
        .join(&clean_domain)
        .join("default.txt");

    if !domain_file.is_file() {
        return Ok(CookieDomainStatus {
            domain: clean_domain,
            has_cookies: false,
            cookie_count: 0,
            has_auth_cookie: false,
            updated_at_ms: None,
        });
    }

    let content = std::fs::read_to_string(&domain_file)?;
    let mut cookie_count: u32 = 0;
    let mut has_auth_cookie = false;

    for line in content.lines() {
        let trimmed = line.trim();
        let Some((_host, name)) = parse_netscape_cookie_line(trimmed) else {
            continue;
        };
        cookie_count += 1;
        if is_auth_cookie_for_domain(&clean_domain, &name) {
            has_auth_cookie = true;
        }
    }

    let updated_at_ms = std::fs::metadata(&domain_file)
        .and_then(|meta| meta.modified())
        .ok()
        .and_then(|ts| ts.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_millis() as i64);

    Ok(CookieDomainStatus {
        domain: clean_domain,
        has_cookies: cookie_count > 0,
        cookie_count,
        has_auth_cookie,
        updated_at_ms,
    })
}

fn get_shared_cookies_path_in(base_dir: &Path) -> Option<String> {
    let shared_file = base_dir.join("cookies").join("cookies.txt");
    if !shared_file.is_file() {
        return None;
    }
    let content = std::fs::read_to_string(&shared_file).ok()?;
    let has_entries = content
        .lines()
        .any(|line| parse_netscape_cookie_line(line.trim()).is_some());
    has_entries.then(|| shared_file.to_string_lossy().to_string())
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
) -> anyhow::Result<()> {
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
    let forward_sink = sink.clone();
    let forward_handle = tokio::spawn(async move {
        while let Some(update) = rx.recv().await {
            let _ = forward_sink.add(NativeProgressEvent {
                percent: update.percent,
                downloaded_bytes: update.downloaded_bytes,
                total_bytes: update.total_bytes,
                speed_bps: update.speed_bps,
                eta_seconds: update.eta_seconds,
                phase: update.phase,
                output_path: None,
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
    let _ = sink.add(NativeProgressEvent {
        percent: 100.0,
        downloaded_bytes: Some(done.file_size_bytes),
        total_bytes: Some(done.file_size_bytes),
        speed_bps: None,
        eta_seconds: Some(0),
        phase: Some("completed".to_string()),
        output_path: Some(done.file_path.to_string_lossy().to_string()),
    });
    Ok(())
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
    let base = app_data_dir().ok_or_else(|| anyhow!("Core data directory unavailable"))?;
    save_netscape_cookies_in(&base, &domain, &netscape_content)
}

pub fn clear_domain_cookies(domain: String) -> anyhow::Result<()> {
    let base = app_data_dir().ok_or_else(|| anyhow!("Core data directory unavailable"))?;
    clear_domain_cookies_in(&base, &domain)
}

pub fn get_cookie_domain_status(domain: String) -> anyhow::Result<CookieDomainStatus> {
    let base = app_data_dir().ok_or_else(|| anyhow!("Core data directory unavailable"))?;
    get_cookie_domain_status_in(&base, &domain)
}

pub fn get_shared_cookies_path() -> anyhow::Result<Option<String>> {
    let base = app_data_dir().ok_or_else(|| anyhow!("Core data directory unavailable"))?;
    Ok(get_shared_cookies_path_in(&base))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_cookie_dir(label: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "klipfetch_core_test_{}_{}_{}",
            label,
            std::process::id(),
            chrono::Utc::now().timestamp_nanos_opt().unwrap_or_default()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

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

    #[test]
    fn cookie_store_tracks_httponly_status_and_clears_related_domains() {
        let base = temp_cookie_dir("cookies");

        let ig_cookies = "# Netscape HTTP Cookie File\n\
            #HttpOnly_.instagram.com\tTRUE\t/\tTRUE\t2147483647\tsessionid\tig_secret_val\n\
            .instagram.com\tTRUE\t/\tTRUE\t2147483647\tdates_unused\t1\n";
        let yt_cookies = "# Netscape HTTP Cookie File\n\
            .youtube.com\tTRUE\t/\tTRUE\t2147483647\tVISITOR_INFO1_LIVE\tabc\n\
            #HttpOnly_.google.com\tTRUE\t/\tTRUE\t2147483647\tSAPISID\tyt_secret_val\n";

        let shared_path = save_netscape_cookies_in(&base, "instagram.com", ig_cookies).unwrap();
        save_netscape_cookies_in(&base, "youtube.com", yt_cookies).unwrap();

        assert_eq!(get_shared_cookies_path_in(&base).as_deref(), Some(shared_path.as_str()));

        let ig_status = get_cookie_domain_status_in(&base, "instagram.com").unwrap();
        assert!(ig_status.has_cookies);
        assert_eq!(ig_status.cookie_count, 2);
        assert!(ig_status.has_auth_cookie);
        assert!(ig_status.updated_at_ms.is_some());

        let yt_status = get_cookie_domain_status_in(&base, "youtube.com").unwrap();
        assert!(yt_status.has_cookies);
        assert_eq!(yt_status.cookie_count, 2);
        assert!(yt_status.has_auth_cookie);

        // Clearing youtube.com removes both .youtube.com and .google.com entries while keeping instagram.com.
        clear_domain_cookies_in(&base, "youtube.com").unwrap();
        let yt_after = get_cookie_domain_status_in(&base, "youtube.com").unwrap();
        assert!(!yt_after.has_cookies);
        assert_eq!(yt_after.cookie_count, 0);
        assert!(!yt_after.has_auth_cookie);

        let shared_contents = std::fs::read_to_string(&shared_path).unwrap();
        assert!(!shared_contents.contains("youtube.com"));
        assert!(!shared_contents.contains("google.com"));
        assert!(shared_contents.contains("instagram.com"));

        clear_domain_cookies_in(&base, "instagram.com").unwrap();
        assert!(get_shared_cookies_path_in(&base).is_none());

        let _ = std::fs::remove_dir_all(&base);
    }
}
