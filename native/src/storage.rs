// SQLite 元数据存储

use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use once_cell::sync::Lazy;

#[cfg(target_os = "linux")]
use rusqlite::Connection;

/// 全局数据库连接
#[cfg(target_os = "linux")]
static DB: Lazy<Mutex<Option<Connection>>> = Lazy::new(|| Mutex::new(None));

#[derive(Debug, Serialize, Deserialize)]
pub struct DocMeta {
    pub path: String,
    pub title: String,
    pub tags: Vec<String>,
    pub word_count: u32,
    pub created_at: u64,
    pub updated_at: u64,
    pub pinned: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SearchResult {
    pub path: String,
    pub title: String,
    pub preview: String,
    pub score: f64,
}

/// 初始化数据库
#[cfg(target_os = "linux")]
pub fn init_db(db_path: &str) -> Result<(), String> {
    let conn = Connection::open(db_path).map_err(|e| e.to_string())?;

    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS docs (
            path TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT '',
            tags TEXT NOT NULL DEFAULT '[]',
            word_count INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            pinned INTEGER NOT NULL DEFAULT 0
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS docs_fts USING fts5(
            path, title, content,
            tokenize='unicode61'
        );"
    ).map_err(|e| e.to_string())?;

    let mut db = DB.lock().map_err(|e| e.to_string())?;
    *db = Some(conn);
    Ok(())
}

#[cfg(not(target_os = "linux"))]
pub fn init_db(_db_path: &str) -> Result<(), String> {
    Ok(()) // no-op for non-linux (will be cross-compiled)
}

/// 保存文档元数据
#[cfg(target_os = "linux")]
pub fn save_meta(meta: &DocMeta) -> Result<(), String> {
    let db = DB.lock().map_err(|e| e.to_string())?;
    let conn = db.as_ref().ok_or("db not initialized")?;

    conn.execute(
        "INSERT OR REPLACE INTO docs (path, title, tags, word_count, created_at, updated_at, pinned)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        rusqlite::params![
            meta.path,
            meta.title,
            serde_json::to_string(&meta.tags).unwrap_or_default(),
            meta.word_count,
            meta.created_at,
            meta.updated_at,
            meta.pinned as i32,
        ],
    ).map_err(|e| e.to_string())?;

    Ok(())
}

#[cfg(not(target_os = "linux"))]
pub fn save_meta(_meta: &DocMeta) -> Result<(), String> { Ok(()) }

/// 全文搜索
#[cfg(target_os = "linux")]
pub fn search(query: &str) -> Result<Vec<SearchResult>, String> {
    let db = DB.lock().map_err(|e| e.to_string())?;
    let conn = db.as_ref().ok_or("db not initialized")?;

    let mut stmt = conn.prepare(
        "SELECT d.path, d.title, snippet(docs_fts, 2, '<mark>', '</mark>', '...', 32) as preview, rank
         FROM docs_fts JOIN docs d ON docs_fts.path = d.path
         WHERE docs_fts MATCH ?1
         ORDER BY rank
         LIMIT 50"
    ).map_err(|e| e.to_string())?;

    let results = stmt.query_map([query], |row| {
        Ok(SearchResult {
            path: row.get(0)?,
            title: row.get(1)?,
            preview: row.get::<_, String>(2).unwrap_or_default(),
            score: row.get::<_, f64>(3).unwrap_or(0.0),
        })
    }).map_err(|e| e.to_string())?
    .filter_map(|r| r.ok())
    .collect();

    Ok(results)
}

#[cfg(not(target_os = "linux"))]
pub fn search(_query: &str) -> Result<Vec<SearchResult>, String> {
    Ok(Vec::new())
}

/// 更新文档全文索引
#[cfg(target_os = "linux")]
pub fn index_doc(path: &str, title: &str, content: &str) -> Result<(), String> {
    let db = DB.lock().map_err(|e| e.to_string())?;
    let conn = db.as_ref().ok_or("db not initialized")?;

    conn.execute(
        "INSERT OR REPLACE INTO docs_fts (path, title, content) VALUES (?1, ?2, ?3)",
        rusqlite::params![path, title, content],
    ).map_err(|e| e.to_string())?;

    Ok(())
}

#[cfg(not(target_os = "linux"))]
pub fn index_doc(_path: &str, _title: &str, _content: &str) -> Result<(), String> {
    Ok(())
}

/// 获取所有文档标签
#[cfg(target_os = "linux")]
pub fn all_tags() -> Result<Vec<String>, String> {
    let db = DB.lock().map_err(|e| e.to_string())?;
    let conn = db.as_ref().ok_or("db not initialized")?;

    let mut stmt = conn.prepare("SELECT DISTINCT tags FROM docs WHERE tags != '[]'")
        .map_err(|e| e.to_string())?;

    let mut all_tags = Vec::new();
    let rows = stmt.query_map([], |row| {
        row.get::<_, String>(0)
    }).map_err(|e| e.to_string())?;

    for row in rows {
        if let Ok(tags_json) = row {
            if let Ok(tags) = serde_json::from_str::<Vec<String>>(&tags_json) {
                for tag in tags {
                    if !all_tags.contains(&tag) {
                        all_tags.push(tag);
                    }
                }
            }
        }
    }

    Ok(all_tags)
}

#[cfg(not(target_os = "linux"))]
pub fn all_tags() -> Result<Vec<String>, String> { Ok(Vec::new()) }
