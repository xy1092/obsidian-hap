// EditorPage — 主编辑页面，整合编辑器 + 预览 + AI 面板 + 文件列表

import { NoteBridge } from '../engine/NoteBridge';
import { EditorPanel } from '../editor/EditorPanel';
import { EditorToolbar } from '../editor/EditorToolbar';
import { PreviewPanel } from '../preview/PreviewPanel';
import { AgentPanel } from '../agent/AgentPanel';
import { AgentService } from '../agent/AgentService';
import { ModelRouter, ModelEntry } from '../agent/ModelRouter';
import { ApiConfig } from '../agent/ApiClient';
import { FileList } from '../components/FileList';

@Entry
@Component
struct EditorPage {
  @State currentContent: string = '# Untitled\n\nStart writing in Markdown...\n\n## Features\n\n- **Bold** and *italic* text\n- AI-powered editing\n- Syntax highlighting\n\n```rust\nfn main() {\n    println!("Hello, HmNote!");\n}\n```';
  @State currentPath: string = '';
  @State currentTitle: string = 'Untitled';
  @State isPreview: boolean = false;
  @State showAgent: boolean = false;
  @State showFileList: boolean = false;
  @State workspaceDir: string = '';
  @State isInitialized: boolean = false;

  private agentService: AgentService;
  private modelRouter: ModelRouter;

  aboutToAppear(): void {
    // Initialize model router with defaults (user can add API keys later)
    this.modelRouter = new ModelRouter();
    this.agentService = new AgentService({ router: this.modelRouter });

    // Try to load saved config
    this.loadConfig();
  }

  private loadConfig(): void {
    // For MVP, workspace defaults to app sandbox
    // In production, this would use preferences API
    this.workspaceDir = '/data/storage/el2/base/files/notes';
  }

  build() {
    Column() {
      // Toolbar
      EditorToolbar({
        isPreview: this.isPreview,
        onTogglePreview: () => this.isPreview = !this.isPreview,
        onAgentToggle: () => this.showAgent = !this.showAgent,
        onBold: () => this.insertMarkdown('**', '**'),
        onItalic: () => this.insertMarkdown('*', '*'),
        onHeading: () => this.insertAtLineStart('## '),
        onCode: () => this.insertMarkdown('`', '`'),
      });

      // Main content area
      Row() {
        // File list sidebar (toggle)
        if (this.showFileList) {
          FileList({
            workspaceDir: this.workspaceDir,
            onSelectNote: (path: string) => this.openNote(path),
            onNewNote: () => this.newNote(),
            onClose: () => this.showFileList = false,
          }).width(260);
          Divider().vertical(true).color('#444');
        }

        // Editor or Preview
        if (this.isPreview) {
          PreviewPanel({ markdown: this.currentContent })
            .layoutWeight(1);
        } else {
          EditorPanel({ text: this.currentContent, isPreview: this.isPreview })
            .layoutWeight(1);
        }

        // AI Agent panel (slide in from right)
        if (this.showAgent) {
          Divider().vertical(true).color('#444');
          AgentPanel({
            agentService: this.agentService,
            modelRouter: this.modelRouter,
          }).width(360);
        }
      }
      .layoutWeight(1);

      // Status bar
      Row() {
        Button(this.showFileList ? '✕ Files' : '☰ Files')
          .fontSize(12).height(28).type(ButtonType.Normal)
          .backgroundColor('#00000000').fontColor('#868E96')
          .onClick(() => this.showFileList = !this.showFileList);

        Blank();

        Text(this.currentTitle)
          .fontSize(12).fontColor('#868E96');

        Blank();

        Text('Markdown')
          .fontSize(11).fontColor('#4C6EF5')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#1E3A5F')
          .borderRadius(4);
      }
      .width('100%')
      .height(28)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#252526');
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1E1E1E');
  }

  private insertMarkdown(before: string, after: string): void {
    // Insert markdown formatting at selection/cursor
    // In production, uses RichEditor.getSelection()
    console.info(`[EditorPage] insert: ${before}...${after}`);
  }

  private insertAtLineStart(prefix: string): void {
    console.info(`[EditorPage] insert at line start: ${prefix}`);
  }

  private openNote(path: string): void {
    const result = NoteBridge.readNote(path);
    if (result.content) {
      this.currentContent = result.content;
      this.currentPath = path;
      this.currentTitle = result.meta?.title ?? 'Untitled';
    }
  }

  private newNote(): void {
    const path = NoteBridge.createNote(this.workspaceDir, 'New Note');
    if (path) {
      this.currentPath = path;
      this.currentContent = '# New Note\n\n';
      this.currentTitle = 'New Note';
    }
  }
}
