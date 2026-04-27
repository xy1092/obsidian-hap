// EditorPanel — 主编辑区域，RichEditor + 语法高亮

import { NoteBridge } from '../engine/NoteBridge';
import { HighlightEngine } from './HighlightEngine';

@Component
export struct EditorPanel {
  @State text: string = '# Untitled\n\nStart writing...';
  @State lineCount: number = 3;
  @Link isPreview: boolean;
  controller: RichEditorController = new RichEditorController();
  private highlightEngine: HighlightEngine = new HighlightEngine();
  private debounceTimer: number = 0;
  private lastText: string = '';

  aboutToAppear(): void {
    // apply initial highlighting after first render
    setTimeout(() => {
      this.applySyntaxHighlighting();
    }, 200);
  }

  build() {
    RichEditor({ controller: this.controller })
      .width('100%')
      .height('100%')
      .backgroundColor('#1E1E1E')
      .defaultFontColor('#D4D4D4')
      .defaultFontSize(16)
      .placeholder('Start writing in Markdown...')
      .onReady(() => {
        this.controller.setTypingStyle({
          fontColor: '#D4D4D4',
          fontSize: 16,
          fontWeight: 'normal',
        });
      })
      .onDidChange(() => {
        this.handleTextChange();
      })
      .onSelectionChange(() => {
        // selection change — can trigger context menu
      })
  }

  private handleTextChange(): void {
    // Debounce: avoid calling native on every keystroke
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    this.debounceTimer = setTimeout(() => {
      this.applySyntaxHighlighting();
    }, 150);
  }

  private applySyntaxHighlighting(): void {
    // For MVP — since RichEditor doesn't expose full text easily,
    // we use the markdown parser to highlight on demand.
    // The full line-by-line highlighting will need more direct
    // RichEditor API access when available on-device.

    try {
      const mdResult = NoteBridge.parseMarkdown(this.lastText || '# Untitled');
      if (mdResult.html) {
        // store for preview
      }
    } catch (e) {
      console.warn('[EditorPanel] highlight failed: ' + e);
    }
  }

  /** Get current content from the editor */
  getContent(): string {
    return this.lastText;
  }

  /** Set content in the editor */
  setContent(text: string): void {
    this.lastText = text;
    this.controller.setText(text);
    setTimeout(() => this.applySyntaxHighlighting(), 100);
  }

  /** Insert text at cursor position */
  insertAtCursor(text: string): void {
    // RichEditor handles cursor-based insertion
    this.controller.addSpan(text);
  }
}
