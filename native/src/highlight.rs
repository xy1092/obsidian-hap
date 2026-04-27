// 代码块语法高亮 — 使用 syntect 生成着色 HTML

use syntect::parsing::SyntaxSet;
use syntect::highlighting::ThemeSet;
use syntect::html::highlighted_html_for_string;
use once_cell::sync::Lazy;

/// syntect 全局单例
static SYNTAX_SET: Lazy<SyntaxSet> = Lazy::new(SyntaxSet::load_defaults_newlines);
static THEME_SET: Lazy<ThemeSet> = Lazy::new(ThemeSet::load_defaults);

/// 对代码块内容生成着色 HTML
pub fn highlight_code_block(code: &str, language: &str) -> String {
    let syntax = SYNTAX_SET.find_syntax_by_token(language)
        .unwrap_or_else(|| SYNTAX_SET.find_syntax_plain_text());
    let theme = &THEME_SET.themes["base16-ocean.dark"];

    highlighted_html_for_string(code, &SYNTAX_SET, syntax, theme)
        .unwrap_or_else(|_| {
            format!("<pre><code>{}</code></pre>", escape_html(code))
        })
}

/// 获取支持的语言列表
pub fn supported_languages() -> Vec<String> {
    SYNTAX_SET.syntaxes().iter()
        .map(|s| s.name.clone())
        .collect()
}

fn escape_html(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}
