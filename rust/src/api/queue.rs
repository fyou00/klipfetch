use std::path::{Path, PathBuf};

use anyhow::anyhow;
use chrono::Utc;
use libreget_core::core::paths::app_data_dir;
use rusqlite::{params, Connection};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QueueTaskStatus {
    Queued,
    Downloading,
    Paused,
    Completed,
    Failed,
    Cancelled,
}

impl QueueTaskStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            QueueTaskStatus::Queued => "queued",
            QueueTaskStatus::Downloading => "downloading",
            QueueTaskStatus::Paused => "paused",
            QueueTaskStatus::Completed => "completed",
            QueueTaskStatus::Failed => "failed",
            QueueTaskStatus::Cancelled => "cancelled",
        }
    }

    pub fn from_db(s: &str) -> Self {
        match s {
            "downloading" => QueueTaskStatus::Downloading,
            "paused" => QueueTaskStatus::Paused,
            "completed" => QueueTaskStatus::Completed,
            "failed" => QueueTaskStatus::Failed,
            "cancelled" => QueueTaskStatus::Cancelled,
            _ => QueueTaskStatus::Queued,
        }
    }
}

#[derive(Debug, Clone)]
pub struct QueueTaskRecord {
    pub id: String,
    pub url: String,
    pub platform: String,
    pub title: String,
    pub engine: String,
    pub status: QueueTaskStatus,
    pub output_path: Option<String>,
    pub error_message: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

fn queue_db_path() -> anyhow::Result<PathBuf> {
    let dir = app_data_dir().ok_or_else(|| anyhow!("Core data directory unavailable"))?;
    Ok(dir.join("klipfetch_queue.sqlite"))
}

fn open_connection(db_path: &Path) -> anyhow::Result<Connection> {
    if let Some(parent) = db_path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let conn = Connection::open(db_path)?;
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS download_queue (
            id TEXT PRIMARY KEY,
            url TEXT NOT NULL,
            platform TEXT NOT NULL,
            title TEXT NOT NULL,
            engine TEXT NOT NULL,
            status TEXT NOT NULL,
            output_path TEXT,
            error_message TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_download_queue_created_at
            ON download_queue (created_at DESC);",
    )?;
    Ok(conn)
}

pub(crate) fn ensure_queue_schema() -> anyhow::Result<()> {
    let path = queue_db_path()?;
    let _ = open_connection(&path)?;
    Ok(())
}

fn enqueue_task_at(
    db_path: &Path,
    url: String,
    platform: String,
    title: String,
    engine: String,
) -> anyhow::Result<QueueTaskRecord> {
    let conn = open_connection(db_path)?;
    let now = Utc::now().timestamp_millis();
    let record = QueueTaskRecord {
        id: Uuid::new_v4().to_string(),
        url,
        platform,
        title,
        engine,
        status: QueueTaskStatus::Queued,
        output_path: None,
        error_message: None,
        created_at: now,
        updated_at: now,
    };

    conn.execute(
        "INSERT INTO download_queue
         (id, url, platform, title, engine, status, output_path, error_message, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
        params![
            record.id,
            record.url,
            record.platform,
            record.title,
            record.engine,
            record.status.as_str(),
            record.output_path,
            record.error_message,
            record.created_at,
            record.updated_at,
        ],
    )?;

    Ok(record)
}

fn list_tasks_at(db_path: &Path) -> anyhow::Result<Vec<QueueTaskRecord>> {
    let conn = open_connection(db_path)?;
    let mut stmt = conn.prepare(
        "SELECT id, url, platform, title, engine, status, output_path, error_message, created_at, updated_at
         FROM download_queue
         ORDER BY created_at DESC",
    )?;
    let rows = stmt.query_map([], |row| {
        let status_str: String = row.get(5)?;
        Ok(QueueTaskRecord {
            id: row.get(0)?,
            url: row.get(1)?,
            platform: row.get(2)?,
            title: row.get(3)?,
            engine: row.get(4)?,
            status: QueueTaskStatus::from_db(&status_str),
            output_path: row.get(6)?,
            error_message: row.get(7)?,
            created_at: row.get(8)?,
            updated_at: row.get(9)?,
        })
    })?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

fn update_task_status_at(
    db_path: &Path,
    id: &str,
    status: QueueTaskStatus,
    output_path: Option<String>,
    error_message: Option<String>,
) -> anyhow::Result<bool> {
    let conn = open_connection(db_path)?;
    let now = Utc::now().timestamp_millis();
    let changed = conn.execute(
        "UPDATE download_queue
         SET status = ?1,
             output_path = COALESCE(?2, output_path),
             error_message = ?3,
             updated_at = ?4
         WHERE id = ?5",
        params![status.as_str(), output_path, error_message, now, id],
    )?;
    Ok(changed > 0)
}

fn delete_task_at(db_path: &Path, id: &str) -> anyhow::Result<bool> {
    let conn = open_connection(db_path)?;
    let deleted = conn.execute("DELETE FROM download_queue WHERE id = ?1", params![id])?;
    Ok(deleted > 0)
}

pub fn enqueue_task(
    url: String,
    platform: String,
    title: String,
    engine: String,
) -> anyhow::Result<QueueTaskRecord> {
    enqueue_task_at(&queue_db_path()?, url, platform, title, engine)
}

pub fn list_tasks() -> anyhow::Result<Vec<QueueTaskRecord>> {
    list_tasks_at(&queue_db_path()?)
}

pub fn update_task_status(
    id: String,
    status: QueueTaskStatus,
    output_path: Option<String>,
    error_message: Option<String>,
) -> anyhow::Result<bool> {
    update_task_status_at(&queue_db_path()?, &id, status, output_path, error_message)
}

pub fn delete_task(id: String) -> anyhow::Result<bool> {
    delete_task_at(&queue_db_path()?, &id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sqlite_wal_queue_crud_round_trip() {
        let temp_dir = std::env::temp_dir().join(format!("klipfetch_q_{}", Uuid::new_v4()));
        let db_path = temp_dir.join("queue.sqlite");

        let created = enqueue_task_at(
            &db_path,
            "https://www.tiktok.com/@user/video/123".to_string(),
            "tiktok".to_string(),
            "Sample TikTok".to_string(),
            "rust_core".to_string(),
        )
        .expect("enqueue succeeds");
        assert_eq!(created.status, QueueTaskStatus::Queued);

        let items = list_tasks_at(&db_path).expect("list succeeds");
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, created.id);

        let updated = update_task_status_at(
            &db_path,
            &created.id,
            QueueTaskStatus::Completed,
            Some("/storage/emulated/0/Download/KlipFetch/TikTok/sample.mp4".to_string()),
            None,
        )
        .expect("update succeeds");
        assert!(updated);

        let after_update = list_tasks_at(&db_path).expect("list after update succeeds");
        assert_eq!(after_update[0].status, QueueTaskStatus::Completed);
        assert_eq!(
            after_update[0].output_path.as_deref(),
            Some("/storage/emulated/0/Download/KlipFetch/TikTok/sample.mp4")
        );

        let deleted = delete_task_at(&db_path, &created.id).expect("delete succeeds");
        assert!(deleted);
        assert!(list_tasks_at(&db_path).unwrap().is_empty());

        let _ = std::fs::remove_dir_all(temp_dir);
    }
}
