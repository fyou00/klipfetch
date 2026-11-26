pub mod cookie_provider;
pub mod instagram;
pub mod tiktok;
pub mod traits;

pub use instagram::InstagramDownloader;
pub use tiktok::TikTokDownloader;
pub use traits::PlatformDownloader;

use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Platform {
    YouTube,
    Instagram,
    TikTok,
}

impl fmt::Display for Platform {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            Platform::YouTube => "youtube",
            Platform::Instagram => "instagram",
            Platform::TikTok => "tiktok",
        };
        write!(f, "{}", name)
    }
}

impl FromStr for Platform {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "youtube" | "yt" => Ok(Platform::YouTube),
            "instagram" | "ig" => Ok(Platform::Instagram),
            "tiktok" | "tt" => Ok(Platform::TikTok),
            _ => Err(format!("Unsupported platform: {}", s)),
        }
    }
}

impl Platform {
    /// Classifies a URL strictly within KlipFetch's supported mobile scope:
    /// TikTok, Instagram, and YouTube.
    pub fn detect(url_str: &str) -> Option<Self> {
        let parsed = url::Url::parse(url_str.trim()).ok()?;
        if parsed.scheme() != "http" && parsed.scheme() != "https" {
            return None;
        }
        let host = parsed.host_str()?.to_lowercase();

        let matches =
            |domain: &str| -> bool { host == domain || host.ends_with(&format!(".{}", domain)) };

        if matches("youtube.com") || matches("youtube-nocookie.com") || host == "youtu.be" {
            Some(Platform::YouTube)
        } else if matches("instagram.com") || matches("ddinstagram.com") {
            Some(Platform::Instagram)
        } else if matches("tiktok.com") {
            Some(Platform::TikTok)
        } else {
            None
        }
    }

    pub fn from_url(url_str: &str) -> Option<Self> {
        Self::detect(url_str)
    }

    pub fn all() -> &'static [Platform] {
        &[Platform::TikTok, Platform::Instagram, Platform::YouTube]
    }
}

#[cfg(test)]
mod tests {
    use super::Platform;

    #[test]
    fn detects_tiktok_urls() {
        assert_eq!(
            Platform::detect("https://www.tiktok.com/@user/video/7123456789012345678"),
            Some(Platform::TikTok)
        );
        assert_eq!(
            Platform::detect("https://vm.tiktok.com/ZM8abcdef/"),
            Some(Platform::TikTok)
        );
        assert_eq!(
            Platform::detect("https://vt.tiktok.com/ZS8abcdef/"),
            Some(Platform::TikTok)
        );
    }

    #[test]
    fn detects_instagram_urls() {
        assert_eq!(
            Platform::detect("https://www.instagram.com/reel/Dbi_MeVOphM/"),
            Some(Platform::Instagram)
        );
        assert_eq!(
            Platform::detect("https://instagram.com/p/ABC123/"),
            Some(Platform::Instagram)
        );
        assert_eq!(
            Platform::detect("https://www.ddinstagram.com/p/ABC123/"),
            Some(Platform::Instagram)
        );
    }

    #[test]
    fn detects_youtube_urls() {
        assert_eq!(
            Platform::detect("https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
            Some(Platform::YouTube)
        );
        assert_eq!(
            Platform::detect("https://youtu.be/dQw4w9WgXcQ"),
            Some(Platform::YouTube)
        );
        assert_eq!(
            Platform::detect("https://m.youtube.com/shorts/abcDEF12345"),
            Some(Platform::YouTube)
        );
    }

    #[test]
    fn rejects_out_of_scope_domains_and_invalid_urls() {
        assert_eq!(Platform::detect("https://x.com/user/status/123"), None);
        assert_eq!(Platform::detect("https://www.bilibili.com/video/BV1xx411c7mD"), None);
        assert_eq!(Platform::detect("https://www.udemy.com/course/rust/"), None);
        assert_eq!(Platform::detect("not a url"), None);
    }
}
