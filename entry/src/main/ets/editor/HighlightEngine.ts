// HighlightEngine — 驱动 Rust 语法高亮的 ArkTS 逻辑

import { NoteBridge, TokenInfo } from '../engine/NoteBridge';

// syntect scope → RichEditor 颜色映射
const STYLE_COLORS: Record<string, string> = {
  heading1:    '#FF6B6B',
  heading2:    '#FFA94D',
  heading3:    '#FFD43B',
  bold:        '#FFFFFF',
  italic:      '#D4D4D4',
  code:        '#69DB7C',
  codeblock:   '#69DB7C',
  link:        '#74C0FC',
  list:        '#D4D4D4',
  listitem:    '#D4D4D4',
  blockquote:  '#868E96',
  strikethrough: '#868E96',
  math:        '#DA77F2',
  html:        '#FF8787',
  normal:      '#D4D4D4',
};

const STYLE_BOLD: string[] = ['heading1', 'heading2', 'heading3'];

export class HighlightEngine {
  private lineTokenCache: Map<number, TokenInfo[]> = new Map();

  /** 对全文重新进行高亮分析 */
  recalculateAll(text: string): Map<number, TokenInfo[]> {
    const lines = text.split('\n');
    const result = new Map<number, TokenInfo[]>();

    for (let i = 0; i < lines.length; i++) {
      const tokens = NoteBridge.tokenizeLine(lines[i]);
      if (tokens.length > 0) {
        result.set(i, tokens);
      }
    }

    this.lineTokenCache = result;
    return result;
  }

  /** 增量更新：只重新高亮变更行附近的行 */
  recalculateLines(text: string, changedLines: number[]): Map<number, TokenInfo[]> {
    const lines = text.split('\n');
    const affected = new Set<number>();

    // include ±2 context lines
    for (const lineIdx of changedLines) {
      for (let d = -2; d <= 2; d++) {
        const idx = lineIdx + d;
        if (idx >= 0 && idx < lines.length) {
          affected.add(idx);
        }
      }
    }

    const updates = new Map<number, TokenInfo[]>();
    for (const idx of affected) {
      const tokens = NoteBridge.tokenizeLine(lines[idx]);
      updates.set(idx, tokens);
      this.lineTokenCache.set(idx, tokens);
    }

    return updates;
  }

  /** 获取行的颜色信息（取第一个 token 的主色） */
  getLineColor(lineTokens: TokenInfo[]): string {
    if (lineTokens.length === 0) return STYLE_COLORS['normal'];
    const style = lineTokens[0].style;
    return STYLE_COLORS[style] ?? STYLE_COLORS['normal'];
  }

  /** 判断是否为粗体样式 */
  isBold(lineTokens: TokenInfo[]): boolean {
    if (lineTokens.length === 0) return false;
    return STYLE_BOLD.includes(lineTokens[0].style);
  }

  get cachedLineCount(): number {
    return this.lineTokenCache.size;
  }
}
