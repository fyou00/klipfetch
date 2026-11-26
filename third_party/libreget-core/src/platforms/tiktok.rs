use crate::models::progress::ProgressUpdate;
use std::sync::Arc;

use anyhow::anyhow;
use async_trait::async_trait;
use reqwest::header::{HeaderMap, HeaderValue, COOKIE, REFERER};
use tokio::sync::mpsc;

use crate::core::direct_downloader;
use crate::models::media::{DownloadOptions, DownloadResult, MediaInfo, MediaType, VideoQuality};
use crate::platforms::traits::PlatformDownloader;

const USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36";
const SHORT_LINK_UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)";

pub struct TikTokDownloader {
    client: reqwest::Client,
    captured_cookies: Arc<tokio::sync::Mutex<Option<String>>>,
}

impl Default for TikTokDownloader {
    fn default() -> Self {
        Self::new()
    }
}

impl TikTokDownloader {
    pub fn new() -> Self {
        let mut builder = crate::core::http_client::apply_global_proxy(reqwest::Client::builder())
            .user_agent(USER_AGENT)
            .timeout(std::time::Duration::from_secs(30));

        if let Some(jar) =
            crate::core::cookie_parser::load_extension_cookies_for_domain("tiktok.com")
        {
            builder = builder.cookie_provider(jar);
        } else {
            builder = builder.cookie_store(true);
        }

        let client = builder.build().unwrap_or_default();
        Self {
            client,
            captured_cookies: Arc::new(tokio::sync::Mutex::new(None)),
        }
    }

    fn tiktok_headers() -> HeaderMap {
        let mut headers = HeaderMap::new();
        headers.insert(REFERER, HeaderValue::from_static("https://www.tiktok.com/"));
        headers
    }

    fn download_headers(&self, cookies: &Option<String>) -> HeaderMap {
        let mut headers = Self::tiktok_headers();
        if let Some(ref cookie_str) = cookies {
            if let Ok(val) = HeaderValue::from_str(cookie_str) {
                headers.insert(COOKIE, val);
            }
        }
        headers
    }

    fn extract_post_id(url: &str) -> Option<String> {
        let parsed = url::Url::parse(url).ok()?;
        let segments: Vec<&str> = parsed.path().split('/').filter(|s| !s.is_empty()).collect();

        if segments.len() >= 3
            && segments[0].starts_with('@')
            && (segments[1] == "video" || segments[1] == "photo")
        {
            let id = segments[2];
            if id.chars().all(|c| c.is_ascii_digit()) {
                return Some(id.to_string());
            }
        }

        None
    }

    async fn resolve_short_link(&self, url: &str) -> anyhow::Result<String> {
        let redirect_client =
            crate::core::http_client::apply_global_proxy(reqwest::Client::builder())
                .user_agent(SHORT_LINK_UA)
                .redirect(reqwest::redirect::Policy::none())
                .build()
                .unwrap_or_default();

        let response = redirect_client.get(url).send().await?;

        if let Some(location) = response
            .headers()
            .get("location")
            .and_then(|v| v.to_str().ok())
        {
            let clean = location.split('?').next().unwrap_or(location).to_string();
            return Ok(clean);
        }

        let html = response.text().await?;

        if html.starts_with("<a href=\"https://") {
            if let Some(url_part) = html.split("<a href=\"").nth(1) {
                let full_url = url_part.split('"').next().unwrap_or(url_part);
                let clean = full_url.split('?').next().unwrap_or(full_url).to_string();
                return Ok(clean);
            }
        }

        Err(anyhow!("Could not resolve short link"))
    }

    fn is_captcha_page(html: &str) -> bool {
        html.contains("verify-bar-close")
            || html.contains("captcha_verify")
            || html.contains("tiktok-verify-page")
            || html.contains("verify/page")
            || (html.contains("Verify to continue")
                && !html.contains("__UNIVERSAL_DATA_FOR_REHYDRATION__"))
    }

    fn is_valid_play_addr(url: &str) -> bool {
        if url.is_empty() {
            return false;
        }
        if !url.starts_with("http://") && !url.starts_with("https://") {
            return false;
        }
        if url.contains("verify") || url.contains("captcha") {
            return false;
        }
        true
    }

    async fn fetch_detail(&self, post_id: &str) -> anyhow::Result<serde_json::Value> {
        let url = format!("https://www.tiktok.com/@i/video/{}", post_id);

        let response = self.client.get(&url).send().await?;

        let status = response.status();

        if !status.is_success() && status.as_u16() != 302 {
            return Err(anyhow!("TikTok retornou HTTP {}", status));
        }

        let mut cookie_parts = Vec::new();
        for cookie in response.cookies() {
            cookie_parts.push(format!("{}={}", cookie.name(), cookie.value()));
        }
        if !cookie_parts.is_empty() {
            let cookie_str = cookie_parts.join("; ");
            *self.captured_cookies.lock().await = Some(cookie_str);
        }

        let html = response.text().await?;

        if Self::is_captcha_page(&html) {
            return Err(anyhow!(
                "TikTok is blocking requests. Try again in a few minutes."
            ));
        }

        let json_str = html
            .split("<script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\" type=\"application/json\">")
            .nth(1)
            .and_then(|s| s.split("</script>").next())
            .ok_or_else(|| anyhow!("TikTok is blocking requests. Try again in a few minutes."))?;

        let data: serde_json::Value = serde_json::from_str(json_str)
            .map_err(|_| anyhow!("Erro ao processar resposta do TikTok"))?;

        let video_detail = data
            .get("__DEFAULT_SCOPE__")
            .and_then(|s| s.get("webapp.video-detail"))
            .ok_or_else(|| anyhow!("Video data not found in TikTok response"))?;

        if let Some(status_msg) = video_detail
            .get("statusMsg")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
        {
            return Err(anyhow!("Post not available: {}", status_msg));
        }

        if let Some(status_code) = video_detail.get("statusCode").and_then(|v| v.as_u64()) {
            if status_code != 0 {
                return Err(anyhow!("Post not available (status {})", status_code));
            }
        }

        let detail = video_detail
            .pointer("/itemInfo/itemStruct")
            .ok_or_else(|| anyhow!("Video data not found in TikTok response"))?
            .clone();

        if detail
            .get("isContentClassified")
            .and_then(|v| v.as_bool())
            .unwrap_or(false)
        {
            return Err(anyhow!("Age-restricted content"));
        }

        if detail.get("author").is_none() {
            return Err(anyhow!("Post not available"));
        }

        Ok(detail)
    }

    fn extract_author(detail: &serde_json::Value) -> String {
        detail
            .pointer("/author/uniqueId")
            .or_else(|| detail.pointer("/author/unique_id"))
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string()
    }

    fn extract_video_url(detail: &serde_json::Value) -> Option<String> {
        if let Some(play_addr) = detail.pointer("/video/playAddr") {
            if let Some(url) = play_addr.as_str() {
                if Self::is_valid_play_addr(url) {
                    return Some(url.to_string());
                }
            }
        }

        if let Some(play_addr) = detail.pointer("/video/play_addr/url_list") {
            if let Some(urls) = play_addr.as_array() {
                for u in urls {
                    if let Some(url) = u.as_str() {
                        if Self::is_valid_play_addr(url) {
                            return Some(url.to_string());
                        }
                    }
                }
            }
        }

        if let Some(download_addr) = detail.pointer("/video/downloadAddr") {
            if let Some(url) = download_addr.as_str() {
                if Self::is_valid_play_addr(url) {
                    return Some(url.to_string());
                }
            }
        }

        if let Some(bitrate_info) = detail
            .pointer("/video/bitrateInfo")
            .and_then(|v| v.as_array())
        {
            for bitrate in bitrate_info {
                if let Some(url_list) = bitrate
                    .pointer("/PlayAddr/UrlList")
                    .and_then(|v| v.as_array())
                {
                    for u in url_list {
                        if let Some(url) = u.as_str() {
                            if Self::is_valid_play_addr(url) {
                                return Some(url.to_string());
                            }
                        }
                    }
                }
            }
        }

        None
    }

    fn extract_image_urls(detail: &serde_json::Value) -> Option<Vec<String>> {
        let images = detail
            .pointer("/imagePost/images")
            .and_then(|v| v.as_array())?;

        let urls: Vec<String> = images
            .iter()
            .filter_map(|img| {
                let url_list = img.pointer("/imageURL/urlList")?.as_array()?;
                url_list
                    .iter()
                    .filter_map(|u| u.as_str())
                    .find(|u| u.contains(".jpeg"))
                    .or_else(|| {
                        url_list
                            .iter()
                            .filter_map(|u| u.as_str())
                            .find(|u| {
                                !u.is_empty()
                                    && (u.starts_with("http://") || u.starts_with("https://"))
                            })
                    })
                    .map(|u| u.to_string())
            })
            .collect();

        if urls.is_empty() {
            return None;
        }

        Some(urls)
    }

    async fn fallback_ytdlp(&self, url: &str, _post_id: Option<&str>) -> anyhow::Result<MediaInfo> {
        Err(anyhow!(
            "FALLBACK_YTDLP: tiktok native extraction unavailable for {}",
            url
        ))
    }

    fn extract_thumbnail(detail: &serde_json::Value) -> Option<String> {
        detail
            .pointer("/video/cover")
            .or_else(|| detail.pointer("/video/originCover"))
            .or_else(|| detail.pointer("/video/dynamicCover"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
    }

    fn extract_title(detail: &serde_json::Value, post_id: &str, author: &str) -> String {
        detail
            .get("desc")
            .and_then(|v| v.as_str())
            .map(|s| s.trim())
            .filter(|s| !s.is_empty())
            .map(|s| s.to_string())
            .unwrap_or_else(|| {
                format!("tiktok_{}_{}", sanitize_filename::sanitize(author), post_id)
            })
    }

    fn extract_music_url(detail: &serde_json::Value) -> Option<String> {
        detail
            .pointer("/music/playUrl")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .map(|s| s.to_string())
    }

    fn extract_duration(detail: &serde_json::Value) -> Option<f64> {
        detail.pointer("/video/duration").and_then(|v| v.as_f64())
    }
}

#[async_trait]
impl PlatformDownloader for TikTokDownloader {
    fn name(&self) -> &str {
        "tiktok"
    }

    fn can_handle(&self, url: &str) -> bool {
        if let Ok(parsed) = url::Url::parse(url) {
            if let Some(host) = parsed.host_str() {
                let host = host.to_lowercase();
                return host == "tiktok.com" || host.ends_with(".tiktok.com");
            }
        }
        false
    }

    async fn get_media_info(&self, url: &str) -> anyhow::Result<MediaInfo> {
        let post_id = match Self::extract_post_id(url) {
            Some(id) => Some(id),
            None => {
                let canonical = self
                    .resolve_short_link(url)
                    .await
                    .unwrap_or_else(|_| url.to_string());
                Self::extract_post_id(&canonical)
            }
        };

        let pid = post_id.unwrap_or_else(|| "unknown".to_string());
        let detail = match self.fetch_detail(&pid).await {
            Ok(d) => d,
            Err(first_err) => {
                tracing::warn!("[tiktok] native scraper failed: {}", first_err);
                return self.fallback_ytdlp(url, Some(&pid)).await;
            }
        };

        let author = Self::extract_author(&detail);
        let title = Self::extract_title(&detail, &pid, &author);
        let thumbnail = Self::extract_thumbnail(&detail);

        if let Some(image_urls) = Self::extract_image_urls(&detail) {
            let media_type = if image_urls.len() == 1 {
                MediaType::Photo
            } else {
                MediaType::Carousel
            };

            let mut qualities: Vec<VideoQuality> = image_urls
                .iter()
                .enumerate()
                .map(|(i, u)| VideoQuality {
                    label: format!("photo_{}", i + 1),
                    width: 0,
                    height: 0,
                    url: u.clone(),
                    format: "jpg".to_string(),
                })
                .collect();

            if let Some(music_url) = Self::extract_music_url(&detail) {
                qualities.push(VideoQuality {
                    label: "slideshow_audio".to_string(),
                    width: 0,
                    height: 0,
                    url: music_url,
                    format: "mp3".to_string(),
                });
            }

            return Ok(MediaInfo {
                title,
                author,
                platform: "tiktok".to_string(),
                duration_seconds: None,
                thumbnail_url: thumbnail.or_else(|| image_urls.first().cloned()),
                available_qualities: qualities,
                media_type,
                file_size_bytes: None,
            });
        }

        if let Some(video_url) = Self::extract_video_url(&detail) {
            return Ok(MediaInfo {
                title,
                author,
                platform: "tiktok".to_string(),
                duration_seconds: Self::extract_duration(&detail),
                thumbnail_url: thumbnail,
                available_qualities: vec![VideoQuality {
                    label: "best".to_string(),
                    width: 0,
                    height: 0,
                    url: video_url,
                    format: "tiktok_direct".to_string(),
                }],
                media_type: MediaType::Video,
                file_size_bytes: None,
            });
        }

        if let Some(music_url) = Self::extract_music_url(&detail) {
            return Ok(MediaInfo {
                title,
                author,
                platform: "tiktok".to_string(),
                duration_seconds: None,
                thumbnail_url: thumbnail,
                available_qualities: vec![VideoQuality {
                    label: "audio".to_string(),
                    width: 0,
                    height: 0,
                    url: music_url,
                    format: "mp3".to_string(),
                }],
                media_type: MediaType::Audio,
                file_size_bytes: None,
            });
        }

        Err(anyhow!("No media found in TikTok post"))
    }

    async fn download(
        &self,
        info: &MediaInfo,
        opts: &DownloadOptions,
        progress: mpsc::Sender<ProgressUpdate>,
    ) -> anyhow::Result<DownloadResult> {
        if info.available_qualities.iter().any(|q| q.format == "ytdlp") {
            let quality = info
                .available_qualities
                .iter()
                .find(|q| q.format == "ytdlp")
                .unwrap();
            return Err(anyhow!(
                "FALLBACK_YTDLP: tiktok download requires yt-dlp for {}",
                quality.url
            ));
        }

        let cookies = self.captured_cookies.lock().await.clone();
        let mut headers = self.download_headers(&cookies);
        crate::core::http_client::inject_ua_header(&mut headers, opts.user_agent.as_deref());

        match info.media_type {
            MediaType::Video => {
                if opts.download_mode.as_deref() == Some("audio") {
                    return Err(anyhow!(
                        "FALLBACK_YTDLP: audio extraction requires yt-dlp with FFmpeg"
                    ));
                }

                let quality = info
                    .available_qualities
                    .first()
                    .ok_or_else(|| anyhow!("No video URL available"))?;

                if quality.format == "tiktok_direct" {
                    let filename = format!("{}.mp4", sanitize_filename::sanitize(&info.title));
                    let output = opts.output_dir.join(&filename);

                    let result = direct_downloader::download_direct_with_headers(
                        &self.client,
                        &quality.url,
                        &output,
                        progress.clone(),
                        Some(headers),
                        Some(&opts.cancel_token),
                    )
                    .await;

                    match result {
                        Ok(bytes) => {
                            return Ok(DownloadResult {
                                file_path: output,
                                file_size_bytes: bytes,
                                duration_seconds: info.duration_seconds.unwrap_or(0.0),
                                torrent_id: None,
                            });
                        }
                        Err(e) => {
                            tracing::warn!(
                                "[tiktok] direct download failed: {}, falling back to yt-dlp",
                                e
                            );
                            let _ = tokio::fs::remove_file(&output).await;
                        }
                    }
                }

                Err(anyhow!(
                    "FALLBACK_YTDLP: tiktok direct download failed for {}",
                    quality.url
                ))
            }
            MediaType::Photo | MediaType::Carousel => {
                let photo_qualities: Vec<&VideoQuality> = info
                    .available_qualities
                    .iter()
                    .filter(|q| q.label != "slideshow_audio")
                    .collect();
                let audio_quality = info
                    .available_qualities
                    .iter()
                    .find(|q| q.label == "slideshow_audio");

                if opts.download_mode.as_deref() == Some("audio") {
                    if let Some(audio) = audio_quality {
                        let filename = format!("{}.mp3", sanitize_filename::sanitize(&info.title));
                        let output = opts.output_dir.join(&filename);
                        let bytes = direct_downloader::download_direct_with_headers(
                            &self.client,
                            &audio.url,
                            &output,
                            progress,
                            Some(headers),
                            Some(&opts.cancel_token),
                        )
                        .await?;
                        return Ok(DownloadResult {
                            file_path: output,
                            file_size_bytes: bytes,
                            duration_seconds: 0.0,
                            torrent_id: None,
                        });
                    }
                    return Err(anyhow!(
                        "FALLBACK_YTDLP: tiktok slideshow audio unavailable for direct extraction"
                    ));
                }

                let include_audio = opts.quality.as_deref() == Some("photos_with_audio")
                    && audio_quality.is_some();
                let total_steps = photo_qualities.len() + usize::from(include_audio);
                if total_steps == 0 {
                    return Err(anyhow!("No photo URLs available in TikTok slideshow"));
                }

                let mut total_bytes = 0u64;
                let count = photo_qualities.len();
                let mut last_path = opts.output_dir.clone();

                for (i, quality) in photo_qualities.iter().enumerate() {
                    let filename = if count == 1 {
                        format!("{}.jpg", sanitize_filename::sanitize(&info.title))
                    } else {
                        format!(
                            "{}_photo_{}.jpg",
                            sanitize_filename::sanitize(&info.title),
                            i + 1
                        )
                    };
                    let output = opts.output_dir.join(&filename);
                    let (tx, _rx) = mpsc::channel(8);

                    let bytes = direct_downloader::download_direct_with_headers(
                        &self.client,
                        &quality.url,
                        &output,
                        tx,
                        Some(headers.clone()),
                        Some(&opts.cancel_token),
                    )
                    .await?;

                    total_bytes += bytes;
                    last_path = output;

                    let percent = ((i + 1) as f64 / total_steps as f64) * 100.0;
                    let _ = progress.send(ProgressUpdate::percent(percent)).await;
                }

                if include_audio {
                    if let Some(audio) = audio_quality {
                        let audio_filename =
                            format!("{}_audio.mp3", sanitize_filename::sanitize(&info.title));
                        let audio_output = opts.output_dir.join(&audio_filename);
                        let (tx, _rx) = mpsc::channel(8);
                        match direct_downloader::download_direct_with_headers(
                            &self.client,
                            &audio.url,
                            &audio_output,
                            tx,
                            Some(headers),
                            Some(&opts.cancel_token),
                        )
                        .await
                        {
                            Ok(bytes) => {
                                total_bytes += bytes;
                                let _ = progress.send(ProgressUpdate::percent(100.0)).await;
                            }
                            Err(e) => {
                                tracing::warn!(
                                    "[tiktok] slideshow audio download failed (photos saved): {}",
                                    e
                                );
                            }
                        }
                    }
                }

                Ok(DownloadResult {
                    file_path: last_path,
                    file_size_bytes: total_bytes,
                    duration_seconds: 0.0,
                    torrent_id: None,
                })
            }
            MediaType::Audio => {
                let quality = info
                    .available_qualities
                    .first()
                    .ok_or_else(|| anyhow!("No audio URL available"))?;

                let filename = format!("{}.mp3", sanitize_filename::sanitize(&info.title));
                let output = opts.output_dir.join(&filename);

                let bytes = direct_downloader::download_direct_with_headers(
                    &self.client,
                    &quality.url,
                    &output,
                    progress,
                    Some(headers),
                    Some(&opts.cancel_token),
                )
                .await?;

                Ok(DownloadResult {
                    file_path: output,
                    file_size_bytes: bytes,
                    duration_seconds: 0.0,
                    torrent_id: None,
                })
            }
            _ => Err(anyhow!("Unsupported media type for download")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_thumbnail_from_detail() {
        let detail = serde_json::json!({
            "video": {
                "cover": "https://p16-sign.tiktokcdn.com/cover.jpg"
            }
        });
        assert_eq!(
            TikTokDownloader::extract_thumbnail(&detail).as_deref(),
            Some("https://p16-sign.tiktokcdn.com/cover.jpg")
        );
    }

    #[test]
    fn extract_title_from_detail_prefers_desc() {
        let detail = serde_json::json!({
            "desc": "Amazing performance in Seoul"
        });
        assert_eq!(
            TikTokDownloader::extract_title(&detail, "123456", "artist"),
            "Amazing performance in Seoul"
        );
    }

    #[test]
    fn extract_title_from_detail_falls_back_to_slug() {
        let detail = serde_json::json!({
            "desc": "   "
        });
        assert_eq!(
            TikTokDownloader::extract_title(&detail, "123456", "artist"),
            "tiktok_artist_123456"
        );
    }

    #[test]
    fn extract_image_urls_falls_back_to_non_jpeg_urls() {
        let detail = serde_json::json!({
            "imagePost": {
                "images": [
                    {
                        "imageURL": {
                            "urlList": [
                                "https://p16-sign.tiktokcdn.com/slide1.webp",
                                "https://p19-sign.tiktokcdn.com/slide1.jpeg"
                            ]
                        }
                    },
                    {
                        "imageURL": {
                            "urlList": [
                                "https://p16-sign.tiktokcdn.com/slide2.webp"
                            ]
                        }
                    }
                ]
            }
        });
        let urls = TikTokDownloader::extract_image_urls(&detail).unwrap();
        assert_eq!(
            urls,
            vec![
                "https://p19-sign.tiktokcdn.com/slide1.jpeg".to_string(),
                "https://p16-sign.tiktokcdn.com/slide2.webp".to_string(),
            ]
        );
    }
}
