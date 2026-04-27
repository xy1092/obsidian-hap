// Engine 结构体 — 协调所有子系统

use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use once_cell::sync::Lazy;

use crate::markdown;
use crate::highlight;
use crate::files;
use crate::storage;

/// 全局 Engine 实例
static ENGINE: Lazy<Mutex<Option<Engine>>> = Lazy::new(|| Mutex::new(None));

#[derive(Debug, Deserialize)]
pub struct EngineConfig {
    pub workspace_dir: String,
    pub db_path: String,
}

#[derive(Debug, Serialize)]
pub struct EngineStats {
    pub initialized: bool,
    pub workspace_dir: String,
    pub note_count: u64,
}

pub struct Engine {
    pub config: EngineConfig,
    initialized: bool,
}

impl Engine {
    pub fn new(config: EngineConfig) -> Self {
        Self {
            config,
            initialized: false,
        }
    }

    pub fn init(&mut self) -> Result<(), String> {
        // 确保工作目录存在
        files::ensure_workspace(&self.config.workspace_dir)?;

        // 初始化数据库
        storage::init_db(&self.config.db_path)?;

        self.initialized = true;
        Ok(())
    }

    pub fn shutdown(&mut self) {
        self.initialized = false;
    }

    pub fn is_initialized(&self) -> bool {
        self.initialized
    }

    fn get() -> Result<std::sync::MutexGuard<'static, Option<Engine>>, String> {
        ENGINE.lock().map_err(|e| e.to_string())
    }
}

// ── 供 C-ABI 调用的辅助函数 ──

pub fn do_init(workspace_dir: &str, db_path: &str) -> Result<String, String> {
    let config = EngineConfig {
        workspace_dir: workspace_dir.to_string(),
        db_path: db_path.to_string(),
    };
    let mut engine = Engine::new(config);
    engine.init()?;

    let mut guard = Engine::get()?;
    *guard = Some(engine);

    Ok(r#"{"ok":true}"#.into())
}

pub fn do_shutdown() -> Result<String, String> {
    let mut guard = Engine::get()?;
    if let Some(ref mut engine) = *guard {
        engine.shutdown();
    }
    *guard = None;
    Ok(r#"{"ok":true}"#.into())
}

#[derive(Deserialize)]
struct ParseRequest {
    text: String,
}

pub fn do_parse_markdown(json: &str) -> Result<String, String> {
    let req: ParseRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    let html = markdown::markdown_to_html(&req.text);
    let tokens = markdown::markdown_to_tokens(&req.text);
    let result = serde_json::json!({
        "ok": true,
        "html": html,
        "tokens": tokens,
    });
    Ok(result.to_string())
}

#[derive(Deserialize)]
struct LineRequest {
    text: String,
}

pub fn do_tokenize_line(json: &str) -> Result<String, String> {
    let req: LineRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    let tokens = markdown::tokenize_line(&req.text);
    let result = serde_json::json!({
        "ok": true,
        "tokens": tokens,
    });
    Ok(result.to_string())
}

pub fn do_highlight(json: &str) -> Result<String, String> {
    let req: ParseRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    // Use markdown tokenizer for structure highlighting
    let tokens = markdown::tokens_by_line(&req.text);
    let result = serde_json::json!({
        "ok": true,
        "tokens": tokens,
    });
    Ok(result.to_string())
}

pub fn do_highlight_line(json: &str) -> Result<String, String> {
    let req: LineRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    // Use markdown tokenizer for single-line highlighting
    let tokens = markdown::tokenize_line(&req.text);
    let result = serde_json::json!({
        "ok": true,
        "tokens": tokens,
    });
    Ok(result.to_string())
}

pub fn do_highlight_code(json: &str) -> Result<String, String> {
    #[derive(Deserialize)]
    struct CodeRequest {
        code: String,
        language: String,
    }
    let req: CodeRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    let html = highlight::highlight_code_block(&req.code, &req.language);
    let result = serde_json::json!({
        "ok": true,
        "html": html,
    });
    Ok(result.to_string())
}

#[derive(Deserialize)]
struct DirRequest {
    dir: String,
}

pub fn do_list_notes(json: &str) -> Result<String, String> {
    let req: DirRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    let list = files::list_notes(&req.dir)?;
    let result = serde_json::json!({
        "ok": true,
        "notes": list.notes,
    });
    Ok(result.to_string())
}

pub fn do_read_note(json: &str) -> Result<String, String> {
    #[derive(Deserialize)]
    struct PathRequest {
        path: String,
    }
    let req: PathRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    let note = files::read_note(&req.path)?;
    let result = serde_json::json!({
        "ok": true,
        "content": note.content,
        "meta": note.meta,
    });
    Ok(result.to_string())
}

pub fn do_write_note(json: &str) -> Result<String, String> {
    #[derive(Deserialize)]
    struct WriteRequest {
        path: String,
        content: String,
    }
    let req: WriteRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    files::write_note(&req.path, &req.content)?;
    Ok(r#"{"ok":true}"#.into())
}

pub fn do_delete_note(json: &str) -> Result<String, String> {
    #[derive(Deserialize)]
    struct PathRequest {
        path: String,
    }
    let req: PathRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    files::delete_note(&req.path)?;
    Ok(r#"{"ok":true}"#.into())
}

pub fn do_create_note(json: &str) -> Result<String, String> {
    #[derive(Deserialize)]
    struct CreateNoteRequest {
        dir: String,
        title: String,
    }
    let req: CreateNoteRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    let path = files::create_note(&req.dir, &req.title)?;
    let result = serde_json::json!({
        "ok": true,
        "path": path,
    });
    Ok(result.to_string())
}

#[derive(Deserialize)]
struct SearchRequest {
    query: String,
}

pub fn do_search(json: &str) -> Result<String, String> {
    let req: SearchRequest = serde_json::from_str(json).map_err(|e| e.to_string())?;
    let results = storage::search(&req.query)?;
    let result = serde_json::json!({
        "ok": true,
        "results": results,
    });
    Ok(result.to_string())
}
