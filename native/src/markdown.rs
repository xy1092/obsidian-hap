// Markdown 解析引擎 — pulldown-cmark → HTML + token 流

use pulldown_cmark::{Event, Options, Parser, Tag, TagEnd, CodeBlockKind, HeadingLevel, html};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TokenInfo {
    pub text: String,
    pub style: String,       // heading / bold / italic / code / link / codeblock / normal
    pub start: usize,        // byte offset start
    pub end: usize,          // byte offset end
}

#[derive(Debug, Serialize, Deserialize)]
pub struct HtmlConfig {
    pub title: String,
    pub lang: String,
}

impl Default for HtmlConfig {
    fn default() -> Self {
        Self { title: "Untitled".into(), lang: "zh-CN".into() }
    }
}

/// 解析 Markdown 文本，返回 HTML（用于预览）
pub fn markdown_to_html(text: &str) -> String {
    let parser = Parser::new_ext(text, Options::ENABLE_TABLES
        | Options::ENABLE_FOOTNOTES
        | Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TASKLISTS
        | Options::ENABLE_HEADING_ATTRIBUTES);

    let mut html = String::new();
    html.push_str("<div class=\"hm-note-preview\">\n");
    html::push_html(&mut html, parser);
    html.push_str("\n</div>");
    html
}

/// 提取 Markdown 的 token 流（用于编辑器语法高亮）
pub fn markdown_to_tokens(text: &str) -> Vec<TokenInfo> {
    let parser = Parser::new_ext(text, Options::ENABLE_TABLES
        | Options::ENABLE_FOOTNOTES
        | Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TASKLISTS
        | Options::ENABLE_HEADING_ATTRIBUTES);

    let mut tokens = Vec::new();
    let offset_iter = parser.into_offset_iter();

    for (event, range) in offset_iter {
        match event {
            Event::Start(tag) => {
                let style = tag_to_style(&tag);
                if !style.is_empty() {
                    tokens.push(TokenInfo {
                        text: String::new(),
                        style,
                        start: range.start,
                        end: range.start,
                    });
                }
            }
            Event::Text(ref content) | Event::Code(ref content) => {
                if let Some(last) = tokens.last() {
                    let style = last.style.clone();
                    if !style.is_empty() && style != "codeblock" {
                        tokens.push(TokenInfo {
                            text: content.to_string(),
                            style,
                            start: range.start,
                            end: range.end,
                        });
                        continue;
                    }
                }
                tokens.push(TokenInfo {
                    text: content.to_string(),
                    style: "normal".into(),
                    start: range.start,
                    end: range.end,
                });
            }
            Event::InlineMath(ref content) | Event::DisplayMath(ref content) => {
                tokens.push(TokenInfo {
                    text: content.to_string(),
                    style: "math".into(),
                    start: range.start,
                    end: range.end,
                });
            }
            Event::InlineHtml(ref content) | Event::Html(ref content) => {
                tokens.push(TokenInfo {
                    text: content.to_string(),
                    style: "html".into(),
                    start: range.start,
                    end: range.end,
                });
            }
            Event::End(_) => {
                // pop style stack
            }
            _ => {}
        }
    }

    tokens
}

/// 按行提取 tokens（用于增量高亮更新）
pub fn tokens_by_line(text: &str) -> Vec<Vec<TokenInfo>> {
    let line_offsets: Vec<(usize, &str)> = text.lines()
        .map(|line| {
            let start = line.as_ptr() as usize - text.as_ptr() as usize;
            (start, line)
        })
        .collect();

    let all_tokens = markdown_to_tokens(text);
    let mut lines: Vec<Vec<TokenInfo>> = vec![Vec::new(); line_offsets.len()];

    for token in &all_tokens {
        for (line_idx, &(line_start, line_str)) in line_offsets.iter().enumerate() {
            let line_end = line_start + line_str.len();
            if token.end > line_start && token.start < line_end {
                // token overlaps with this line
                let local_start = token.start.saturating_sub(line_start);
                let local_end = (token.end.min(line_end)).saturating_sub(line_start);
                let visible = &token.text[local_start..(local_start + (local_end - local_start)).min(token.text.len())];
                if !visible.is_empty() {
                    lines[line_idx].push(TokenInfo {
                        text: visible.to_string(),
                        style: token.style.clone(),
                        start: local_start,
                        end: local_end,
                    });
                }
            }
        }
    }

    lines
}

/// 单行 token 化（用于增量编辑器更新）
pub fn tokenize_line(line_text: &str) -> Vec<TokenInfo> {
    let parser = Parser::new_ext(line_text, Options::ENABLE_TABLES
        | Options::ENABLE_FOOTNOTES
        | Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TASKLISTS
        | Options::ENABLE_HEADING_ATTRIBUTES);

    let mut tokens = Vec::new();
    let offset_iter = parser.into_offset_iter();

    for (event, range) in offset_iter {
        match event {
            Event::Start(tag) => {
                let style = tag_to_style(&tag);
                if !style.is_empty() {
                    tokens.push(TokenInfo {
                        text: String::new(),
                        style,
                        start: range.start,
                        end: range.start,
                    });
                }
            }
            Event::Text(ref content) | Event::Code(ref content) => {
                let style = tokens.last()
                    .map(|t| t.style.clone())
                    .filter(|s| !s.is_empty() && s != "codeblock")
                    .unwrap_or_else(|| "normal".into());
                tokens.push(TokenInfo {
                    text: content.to_string(),
                    style,
                    start: range.start,
                    end: range.end,
                });
            }
            Event::InlineMath(ref content) => {
                tokens.push(TokenInfo {
                    text: content.to_string(),
                    style: "math".into(),
                    start: range.start,
                    end: range.end,
                });
            }
            Event::InlineHtml(ref content) => {
                tokens.push(TokenInfo {
                    text: content.to_string(),
                    style: "html".into(),
                    start: range.start,
                    end: range.end,
                });
            }
            _ => {}
        }
    }

    tokens
}

fn tag_to_style(tag: &Tag) -> String {
    match tag {
        Tag::Heading { level: HeadingLevel::H1, .. } => "heading1".into(),
        Tag::Heading { level: HeadingLevel::H2, .. } => "heading2".into(),
        Tag::Heading { .. } => "heading3".into(),
        Tag::Emphasis => "italic".into(),
        Tag::Strong => "bold".into(),
        Tag::CodeBlock(CodeBlockKind::Fenced(_)) => "codeblock".into(),
        Tag::Link { .. } => "link".into(),
        Tag::List(_) => "list".into(),
        Tag::Item => "listitem".into(),
        Tag::BlockQuote(_) => "blockquote".into(),
        Tag::Strikethrough => "strikethrough".into(),
        _ => String::new(),
    }
}
