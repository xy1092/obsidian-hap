// C-ABI exports — 供 HarmonyOS NAPI 调用的 extern "C" 函数
//
// 复用 hm-tailscale 项目的 JSON-in/JSON-out 模式:
// 所有成功/错误都序列化为 JSON 字符串返回

mod markdown;
mod highlight;
mod files;
mod storage;
mod engine;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

// ── 内存管理辅助函数 ──

unsafe fn cstr_to_str<'a>(ptr: *const c_char) -> Result<&'a str, String> {
    if ptr.is_null() {
        return Err("null pointer".into());
    }
    CStr::from_ptr(ptr)
        .to_str()
        .map_err(|e| format!("invalid utf8: {e}"))
}

fn make_c_string(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

fn wrap_result(result: Result<String, String>) -> *mut c_char {
    match result {
        Ok(s) => make_c_string(s),
        Err(e) => make_c_string(format!(r#"{{"ok":false,"error":"{}"}}"#, e)),
    }
}

// ── 初始化 ──

#[no_mangle]
pub extern "C" fn note_engine_init(config_json: *const c_char) -> *mut c_char {
    let result = (|| {
        let json = unsafe { cstr_to_str(config_json)? };
        #[derive(serde::Deserialize)]
        struct InitConfig {
            workspace_dir: String,
            db_path: String,
        }
        let cfg: InitConfig = serde_json::from_str(json).map_err(|e| e.to_string())?;
        engine::do_init(&cfg.workspace_dir, &cfg.db_path)
    })();
    wrap_result(result)
}

#[no_mangle]
pub extern "C" fn note_engine_shutdown() -> *mut c_char {
    wrap_result(engine::do_shutdown())
}

// ── Markdown 解析 ──

#[no_mangle]
pub extern "C" fn note_parse_markdown(md_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(md_json)? };
        engine::do_parse_markdown(json)
    })();
    wrap_result(result)
}

#[no_mangle]
pub extern "C" fn note_tokenize_line(line_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(line_json)? };
        engine::do_tokenize_line(json)
    })();
    wrap_result(result)
}

// ── 语法高亮 ──

#[no_mangle]
pub extern "C" fn note_highlight(md_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(md_json)? };
        engine::do_highlight(json)
    })();
    wrap_result(result)
}

#[no_mangle]
pub extern "C" fn note_highlight_line(line_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(line_json)? };
        engine::do_highlight_line(json)
    })();
    wrap_result(result)
}

#[no_mangle]
pub extern "C" fn note_highlight_code(req_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(req_json)? };
        engine::do_highlight_code(json)
    })();
    wrap_result(result)
}

// ── 文件操作 ──

#[no_mangle]
pub extern "C" fn note_list_notes(dir_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(dir_json)? };
        engine::do_list_notes(json)
    })();
    wrap_result(result)
}

#[no_mangle]
pub extern "C" fn note_read_note(path_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(path_json)? };
        engine::do_read_note(json)
    })();
    wrap_result(result)
}

#[no_mangle]
pub extern "C" fn note_write_note(req_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(req_json)? };
        engine::do_write_note(json)
    })();
    wrap_result(result)
}

#[no_mangle]
pub extern "C" fn note_delete_note(path_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(path_json)? };
        engine::do_delete_note(json)
    })();
    wrap_result(result)
}

#[no_mangle]
pub extern "C" fn note_create_note(req_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(req_json)? };
        engine::do_create_note(json)
    })();
    wrap_result(result)
}

// ── 搜索 ──

#[no_mangle]
pub extern "C" fn note_search(query_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let json = unsafe { cstr_to_str(query_json)? };
        engine::do_search(json)
    })();
    wrap_result(result)
}

// ── 内存管理 ──

#[no_mangle]
pub extern "C" fn note_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { let _ = CString::from_raw(ptr); }
    }
}

#[no_mangle]
pub extern "C" fn note_free_buffer(ptr: *mut u8, len: u32) {
    if !ptr.is_null() && len > 0 {
        unsafe { let _ = Vec::from_raw_parts(ptr, len as usize, len as usize); }
    }
}
