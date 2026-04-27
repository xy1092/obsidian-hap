// NAPI Bridge — 封装 Rust note-core 的 ArkTS 接口

export interface TokenInfo {
  text: string;
  style: string;
  start: number;
  end: number;
}

export interface NoteMeta {
  path: string;
  title: string;
  modified: number;
  size: number;
}

export interface NoteContent {
  content: string;
  meta: NoteMeta;
}

export interface SearchResult {
  path: string;
  title: string;
  preview: string;
  score: number;
}

export interface ParseResult {
  ok: boolean;
  html?: string;
  tokens?: TokenInfo[];
  error?: string;
}

export interface NoteListResult {
  ok: boolean;
  notes?: NoteMeta[];
  error?: string;
}

export interface NoteReadResult {
  ok: boolean;
  content?: string;
  meta?: NoteMeta;
  error?: string;
}

// ── Native module type ──

declare interface NativeModule {
  noteEngineInit(configJson: string): string;
  noteEngineShutdown(): string;
  noteParseMarkdown(mdJson: string): string;
  noteTokenizeLine(lineJson: string): string;
  noteHighlight(mdJson: string): string;
  noteHighlightLine(lineJson: string): string;
  noteHighlightCode(reqJson: string): string;
  noteListNotes(dirJson: string): string;
  noteReadNote(pathJson: string): string;
  noteWriteNote(reqJson: string): string;
  noteDeleteNote(pathJson: string): string;
  noteCreateNote(reqJson: string): string;
  noteSearch(queryJson: string): string;
}

// ── Stub for dev without native .so ──

function createStubNative(): NativeModule {
  const fakeJson = (result: Record<string, Object>) => JSON.stringify(result);
  return {
    noteEngineInit: (_: string) => fakeJson({ ok: true }),
    noteEngineShutdown: () => fakeJson({ ok: true }),
    noteParseMarkdown: (md) => fakeJson({
      ok: true,
      html: `<div class="preview"><em>Preview unavailable in stub mode</em></div>`,
      tokens: []
    }),
    noteTokenizeLine: (line) => fakeJson({ ok: true, tokens: [] }),
    noteHighlight: (_: string) => fakeJson({ ok: true, tokens: [] }),
    noteHighlightLine: (_: string) => fakeJson({ ok: true, tokens: [] }),
    noteHighlightCode: (code) => fakeJson({ ok: true, html: `<pre><code>${code}</code></pre>` }),
    noteListNotes: (_: string) => fakeJson({ ok: true, notes: [] }),
    noteReadNote: (_: string) => fakeJson({ ok: true, content: '# New Note\n\nStart writing...', meta: { path: '', title: 'New Note', modified: Date.now(), size: 0 } }),
    noteWriteNote: (_: string) => fakeJson({ ok: true }),
    noteDeleteNote: (_: string) => fakeJson({ ok: true }),
    noteCreateNote: (_: string) => fakeJson({ ok: true, path: '/new.md' }),
    noteSearch: (_: string) => fakeJson({ ok: true, results: [] }),
  };
}

let native: NativeModule;
try {
  native = requireNative('note_core') as NativeModule;
  console.info('[NoteBridge] NAPI module loaded');
} catch (_) {
  console.warn('[NoteBridge] NAPI module not found, using stub');
  native = createStubNative();
}

// ── Helper ──

function parseNativeJson(raw: string): Record<string, Object> {
  try { return JSON.parse(raw) as Record<string, Object>; }
  catch { return { ok: false, error: 'json parse error' }; }
}

// ── Typed Bridge API ──

export class NoteBridge {
  static init(workspaceDir: string, dbPath: string): boolean {
    const raw = native.noteEngineInit(JSON.stringify({ workspace_dir: workspaceDir, db_path: dbPath }));
    const r = parseNativeJson(raw);
    return r['ok'] === true;
  }

  static shutdown(): boolean {
    const raw = native.noteEngineShutdown();
    const r = parseNativeJson(raw);
    return r['ok'] === true;
  }

  static parseMarkdown(text: string): ParseResult {
    const raw = native.noteParseMarkdown(JSON.stringify({ text }));
    return parseNativeJson(raw) as unknown as ParseResult;
  }

  static tokenizeLine(line: string): TokenInfo[] {
    const raw = native.noteTokenizeLine(JSON.stringify({ text: line }));
    const r = parseNativeJson(raw);
    return (r['tokens'] as TokenInfo[]) ?? [];
  }

  static highlightCode(code: string, language: string): string {
    const raw = native.noteHighlightCode(JSON.stringify({ code, language }));
    const r = parseNativeJson(raw);
    return (r['html'] as string) ?? `<pre><code>${code}</code></pre>`;
  }

  static listNotes(dir: string): NoteMeta[] {
    const raw = native.noteListNotes(JSON.stringify({ dir }));
    const r = parseNativeJson(raw);
    return (r['notes'] as NoteMeta[]) ?? [];
  }

  static readNote(path: string): NoteReadResult {
    const raw = native.noteReadNote(JSON.stringify({ path }));
    return parseNativeJson(raw) as unknown as NoteReadResult;
  }

  static writeNote(path: string, content: string): boolean {
    const raw = native.noteWriteNote(JSON.stringify({ path, content }));
    const r = parseNativeJson(raw);
    return r['ok'] === true;
  }

  static deleteNote(path: string): boolean {
    const raw = native.noteDeleteNote(JSON.stringify({ path }));
    const r = parseNativeJson(raw);
    return r['ok'] === true;
  }

  static createNote(dir: string, title: string): string {
    const raw = native.noteCreateNote(JSON.stringify({ dir, title }));
    const r = parseNativeJson(raw);
    return (r['path'] as string) ?? '';
  }

  static search(query: string): SearchResult[] {
    const raw = native.noteSearch(JSON.stringify({ query }));
    const r = parseNativeJson(raw);
    return (r['results'] as SearchResult[]) ?? [];
  }
}
