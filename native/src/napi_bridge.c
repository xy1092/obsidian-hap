// NAPI Bridge — 将 Rust note-core C-ABI 函数注册到 HarmonyOS NAPI 运行时
//
// 编译: 与 Rust .a 静态库链接
//   aarch64-linux-gnu-gcc -shared -fPIC -I/usr/include/node \
//     napi_bridge.c -Ltarget/aarch64-unknown-linux-gnu/release \
//     -lnote_core -lpthread -ldl -lm \
//     -o libnote_core.so

#include <node_api.h>
#include <string.h>
#include <stdlib.h>

// Rust extern declarations
extern char* note_engine_init(const char* config_json);
extern char* note_engine_shutdown(void);
extern char* note_parse_markdown(const char* md_json);
extern char* note_tokenize_line(const char* line_json);
extern char* note_highlight(const char* md_json);
extern char* note_highlight_line(const char* line_json);
extern char* note_highlight_code(const char* req_json);
extern char* note_list_notes(const char* dir_json);
extern char* note_read_note(const char* path_json);
extern char* note_write_note(const char* req_json);
extern char* note_delete_note(const char* path_json);
extern char* note_create_note(const char* req_json);
extern char* note_search(const char* query_json);
extern void  note_free_string(char* ptr);
extern void  note_free_buffer(unsigned char* ptr, unsigned int len);

// ── Helper ──

static char* value2string(napi_env env, napi_value value) {
    size_t len = 0;
    napi_get_value_string_utf8(env, value, NULL, 0, &len);
    char* buf = (char*)malloc(len + 1);
    napi_get_value_string_utf8(env, value, buf, len + 1, &len);
    return buf;
}

// ── NAPI Wrappers ──

// (String input → String output pattern)

#define DEFINE_STRING_FN(name, rust_fn) \
static napi_value Napi_##name(napi_env env, napi_callback_info info) { \
    size_t argc = 1; \
    napi_value args[1]; \
    napi_get_cb_info(env, info, &argc, args, NULL, NULL); \
    char* input = value2string(env, args[0]); \
    char* result = rust_fn(input); \
    free(input); \
    napi_value js_result; \
    napi_create_string_utf8(env, result, NAPI_AUTO_LENGTH, &js_result); \
    note_free_string(result); \
    return js_result; \
}

// (No input → String output pattern)

#define DEFINE_NOARG_FN(name, rust_fn) \
static napi_value Napi_##name(napi_env env, napi_callback_info info) { \
    char* result = rust_fn(); \
    napi_value js_result; \
    napi_create_string_utf8(env, result, NAPI_AUTO_LENGTH, &js_result); \
    note_free_string(result); \
    return js_result; \
}

DEFINE_STRING_FN(EngineInit,         note_engine_init)
DEFINE_NOARG_FN(EngineShutdown,     note_engine_shutdown)
DEFINE_STRING_FN(ParseMarkdown,     note_parse_markdown)
DEFINE_STRING_FN(TokenizeLine,      note_tokenize_line)
DEFINE_STRING_FN(Highlight,         note_highlight)
DEFINE_STRING_FN(HighlightLine,     note_highlight_line)
DEFINE_STRING_FN(HighlightCode,     note_highlight_code)
DEFINE_STRING_FN(ListNotes,         note_list_notes)
DEFINE_STRING_FN(ReadNote,          note_read_note)
DEFINE_STRING_FN(WriteNote,         note_write_note)
DEFINE_STRING_FN(DeleteNote,        note_delete_note)
DEFINE_STRING_FN(CreateNote,        note_create_note)
DEFINE_STRING_FN(Search,            note_search)

// ── Module Registration ──

static napi_value InitModule(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"noteEngineInit",     NULL, Napi_EngineInit,     NULL, NULL, NULL, napi_default, NULL},
        {"noteEngineShutdown", NULL, Napi_EngineShutdown, NULL, NULL, NULL, napi_default, NULL},
        {"noteParseMarkdown",  NULL, Napi_ParseMarkdown,  NULL, NULL, NULL, napi_default, NULL},
        {"noteTokenizeLine",   NULL, Napi_TokenizeLine,   NULL, NULL, NULL, napi_default, NULL},
        {"noteHighlight",      NULL, Napi_Highlight,      NULL, NULL, NULL, napi_default, NULL},
        {"noteHighlightLine",  NULL, Napi_HighlightLine,  NULL, NULL, NULL, napi_default, NULL},
        {"noteHighlightCode",  NULL, Napi_HighlightCode,  NULL, NULL, NULL, napi_default, NULL},
        {"noteListNotes",      NULL, Napi_ListNotes,      NULL, NULL, NULL, napi_default, NULL},
        {"noteReadNote",       NULL, Napi_ReadNote,       NULL, NULL, NULL, napi_default, NULL},
        {"noteWriteNote",      NULL, Napi_WriteNote,      NULL, NULL, NULL, napi_default, NULL},
        {"noteDeleteNote",     NULL, Napi_DeleteNote,     NULL, NULL, NULL, napi_default, NULL},
        {"noteCreateNote",     NULL, Napi_CreateNote,     NULL, NULL, NULL, napi_default, NULL},
        {"noteSearch",         NULL, Napi_Search,         NULL, NULL, NULL, napi_default, NULL},
    };

    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

NAPI_MODULE(note_core, InitModule)
