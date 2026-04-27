# HmNote

鸿蒙原生 Markdown 笔记应用，体验接近 Obsidian，内建多模型 AI Agent 和本地 OCR 识图能力。

## 架构

```
┌─────────────────────────────────────────┐
│  ArkUI / ArkTS (HarmonyOS NEXT)         │
│  ├─ RichEditor 原生编辑器 + 语法高亮     │
│  ├─ WebView Markdown 实时预览           │
│  ├─ AI Agent 面板 (多模型路由)          │
│  └─ 📷 本地 OCR → 任意文本模型管道      │
├─────────────────────────────────────────┤
│  NAPI C Bridge (napi_bridge.c)          │
├─────────────────────────────────────────┤
│  Rust 核心引擎 (libnote_core.so)        │
│  ├─ pulldown-cmark  Markdown → HTML     │
│  ├─ syntect        代码块语法高亮       │
│  ├─ rusqlite       全文搜索索引         │
│  └─ 14 个 C-ABI exports                │
└─────────────────────────────────────────┘
```

## 功能

### MVP (已实现)

**编辑器**
- 原生 RichEditor 编辑区
- pulldown-cmark Markdown 解析 → 语法 token 提取
- syntect 代码块着色 (50+ 语言)
- WebView Markdown HTML 预览
- 工具栏：粗体/斜体/标题/代码/预览切换

**AI Agent**
- 多模型路由：OpenAI / Anthropic / 通义千问 / 自定义
- 快/深双 tier 策略：摘要翻译用快模型, 深度分析用强模型
- 5 种 Agent 动作：Chat / Summary / Continue / Translate / Analyze
- 上下文感知：自动注入当前文档标题和选中文本

**📷 识图 (OCR 管道)**
- 相机拍照 / 相册选取
- 鸿蒙本地 `textRecognition` OCR 提取文字
- 文字喂给**任意文本模型**（DeepSeek 等无视觉能力的模型也能用）
- 5 个快捷意图：摘要/转表格/翻译/转笔记/提取关键词

**文件管理**
- 本地文件系统存储 `.md` 文件
- 文件列表浏览、新建、删除
- 全文搜索 (SQLite FTS5)

## 项目结构

```
hm-note/
├── native/                          # Rust 核心引擎
│   ├── Cargo.toml
│   ├── .cargo/config.toml           # 交叉编译 (aarch64)
│   ├── scripts/build.sh             # 一键编译
│   └── src/
│       ├── lib.rs                   # C-ABI exports
│       ├── engine.rs                # Engine 协调层
│       ├── markdown.rs              # Markdown 解析
│       ├── highlight.rs             # 代码高亮
│       ├── files.rs                 # 文件操作
│       ├── storage.rs               # SQLite 索引
│       └── napi_bridge.c            # NAPI C 桥接
├── entry/                           # HarmonyOS Entry 模块
│   └── src/main/
│       ├── ets/
│       │   ├── engine/NoteBridge.ts      # NAPI 封装
│       │   ├── editor/                   # 编辑器组件
│       │   ├── preview/PreviewPanel.ets  # 预览
│       │   ├── agent/                    # AI Agent
│       │   │   ├── ApiClient.ts          # 多 API HTTP 客户端
│       │   │   ├── ModelRouter.ts        # 模型路由
│       │   │   ├── AgentService.ts       # Agent 核心
│       │   │   ├── AgentPanel.ets        # AI 面板 UI
│       │   │   └── ImageProcessor.ts     # OCR 管道
│       │   ├── components/FileList.ets   # 文件列表
│       │   └── pages/                    # 页面
│       └── module.json5
├── build-profile.json5
└── oh-package.json5
```

## 构建

### 前置依赖

- Rust toolchain (`rustup`)
- `aarch64-linux-gnu-gcc` (交叉编译器)
- Node.js headers (`/usr/include/node/node_api.h`)
- HarmonyOS DevEco Studio (构建 HAP)

### 编译 Rust → .so

```bash
cd native
bash scripts/build.sh
# 输出: target/aarch64-unknown-linux-gnu/release/libnote_core.so
```

### 构建 HAP

1. 用 DevEco Studio 打开项目根目录
2. 将 `libnote_core.so` 放入 `entry/libs/arm64-v8a/`
3. Build → Build HAP

## 技术栈

| 层 | 技术 |
|----|------|
| UI | ArkTS / ArkUI (HarmonyOS NEXT API 15) |
| 原生桥接 | NAPI (Node-API 标准) |
| 核心引擎 | Rust (pulldown-cmark + syntect + rusqlite) |
| AI 调用 | `@ohos.net.http` → OpenAI / Anthropic / Qwen API |
| 识图 OCR | `@kit.AIKit` textRecognition (本地离线) |
| 存储 | 文件系统 (.md) + SQLite FTS5 (全文搜索) |
| 交叉编译 | `aarch64-linux-gnu-gcc` + Rust `aarch64-unknown-linux-gnu` |

## 设计理念

- **本地优先** — 笔记存为纯 `.md` 文件，不出卖数据
- **AI 辅助而非替代** — Agent 帮你总结、续写、翻译，但不替你思考
- **模型无关** — 可接入任何 AI API，切换模型不需要改代码
- **OCR 与模型解耦** — 识图用本地 OCR，不依赖视觉模型，DeepSeek 等纯文本模型也能"看懂"图片

## License

MIT
