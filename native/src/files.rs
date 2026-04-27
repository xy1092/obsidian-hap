// 文件系统操作

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Debug, Serialize, Deserialize)]
pub struct NoteMeta {
    pub path: String,
    pub title: String,
    pub modified: u64,
    pub size: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NoteContent {
    pub content: String,
    pub meta: NoteMeta,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NoteList {
    pub notes: Vec<NoteMeta>,
}

/// 列出目录中的所有 .md 文件
pub fn list_notes(dir: &str) -> Result<NoteList, String> {
    let path = Path::new(dir);
    if !path.is_dir() {
        return Err(format!("not a directory: {}", dir));
    }

    let mut notes = Vec::new();
    let entries = fs::read_dir(path).map_err(|e| e.to_string())?;

    for entry in entries {
        let entry = entry.map_err(|e| e.to_string())?;
        let file_path = entry.path();

        if file_path.extension().map(|e| e == "md").unwrap_or(false) {
            let meta = fs::metadata(&file_path).map_err(|e| e.to_string())?;
            let modified = meta.modified()
                .map(|t| t.duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs())
                .unwrap_or(0);

            let content = fs::read_to_string(&file_path).unwrap_or_default();
            let title = extract_title(&content, &file_path);

            notes.push(NoteMeta {
                path: file_path.to_string_lossy().to_string(),
                title,
                modified,
                size: meta.len(),
            });
        }
    }

    // sort by modified desc
    notes.sort_by(|a, b| b.modified.cmp(&a.modified));

    Ok(NoteList { notes })
}

/// 读取单个 Markdown 文件
pub fn read_note(path: &str) -> Result<NoteContent, String> {
    let content = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let meta = fs::metadata(path).map_err(|e| e.to_string())?;
    let modified = meta.modified()
        .map(|t| t.duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs())
        .unwrap_or(0);

    let title = extract_title(&content, Path::new(path));

    Ok(NoteContent {
        content,
        meta: NoteMeta {
            path: path.to_string(),
            title,
            modified,
            size: meta.len(),
        },
    })
}

/// 写入 Markdown 文件
pub fn write_note(path: &str, content: &str) -> Result<(), String> {
    // ensure parent directory exists
    if let Some(parent) = Path::new(path).parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    fs::write(path, content).map_err(|e| e.to_string())
}

/// 删除文件
pub fn delete_note(path: &str) -> Result<(), String> {
    fs::remove_file(path).map_err(|e| e.to_string())
}

/// 确保工作目录存在
pub fn ensure_workspace(dir: &str) -> Result<(), String> {
    fs::create_dir_all(dir).map_err(|e| e.to_string())
}

/// 创建新笔记文件
pub fn create_note(dir: &str, title: &str) -> Result<String, String> {
    let sanitized = title.replace(['/', '\\', ':', '*', '?', '"', '<', '>', '|'], "_");
    let filename = format!("{}.md", sanitized);
    let path = Path::new(dir).join(&filename);
    let path_str = path.to_string_lossy().to_string();

    let content = format!("# {}\n\n", title);
    write_note(&path_str, &content)?;

    Ok(path_str)
}

fn extract_title(content: &str, path: &Path) -> String {
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("# ") {
            return trimmed[2..].trim().to_string();
        }
    }
    // fallback: filename without extension
    path.file_stem()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_else(|| "Untitled".to_string())
}
