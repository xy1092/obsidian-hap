// AgentPanel — AI 对话面板 + 图片 OCR 识别

import { AgentService, AgentAction } from './AgentService';
import { ModelRouter, ModelEntry } from './ModelRouter';
import { ImageProcessor, OcrResult } from './ImageProcessor';

@Component
export struct AgentPanel {
  @Prop agentService: AgentService;
  @Prop modelRouter: ModelRouter;
  @State inputText: string = '';
  @State chatHistory: ChatItem[] = [];
  @State isLoading: boolean = false;
  @State selectedAction: AgentAction = 'chat';
  @State selectedText: string = '';
  // OCR states
  @State ocrResult: OcrResult | null = null;
  @State isCapturing: boolean = false;
  @State showQuickIntents: boolean = false;

  private actions: { label: string; action: AgentAction; icon: string }[] = [
    { label: 'Chat',    action: 'chat',      icon: '💬' },
    { label: 'Summary', action: 'summary',   icon: '📝' },
    { label: 'Continue',action: 'continue',  icon: '✍️' },
    { label: 'Translate',action:'translate', icon: '🌐' },
    { label: 'Analyze', action: 'analyze',   icon: '🔍' },
  ];

  private quickIntents = ImageProcessor.getQuickIntents();

  build() {
    Column() {
      // Header
      Row() {
        Text('AI Assistant').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF');
        Blank();
        Button('✕').width(32).height(32).type(ButtonType.Normal)
          .onClick(() => this.onClose?.());
      }
      .width('100%').padding(16);

      // Action buttons (row 1)
      Scroll() {
        Row() {
          ForEach(this.actions, (action: { label: string; action: AgentAction; icon: string }) => {
            Button(action.icon + ' ' + action.label)
              .fontSize(12).height(34).margin({ right: 4 })
              .type(ButtonType.Normal)
              .backgroundColor(this.selectedAction === action.action ? '#4C6EF5' : '#3D3D3D')
              .fontColor(this.selectedAction === action.action ? '#FFFFFF' : '#AAAAAA')
              .borderRadius(17)
              .onClick(() => { this.selectedAction = action.action; });
          });
        }.padding({ left: 16, right: 16 });
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      .width('100%').height(46).padding({ bottom: 8 });

      // Action row 2 — OCR / image button
      Row() {
        Button('📷 Capture Image')
          .fontSize(13).height(36).padding({ left: 12, right: 12 })
          .type(ButtonType.Normal)
          .backgroundColor(this.isCapturing ? '#F08C00' : '#3D3D3D')
          .fontColor('#FFFFFF')
          .borderRadius(18)
          .onClick(() => this.handleCapture());

        Button('🖼️ Gallery')
          .fontSize(13).height(36).padding({ left: 12, right: 12 })
          .margin({ left: 8 })
          .type(ButtonType.Normal)
          .backgroundColor('#3D3D3D')
          .fontColor('#AAAAAA')
          .borderRadius(18)
          .onClick(() => this.handleGallery());
      }
      .width('100%').padding({ left: 16, right: 16, bottom: 8 });

      Divider().color('#444').width('100%');

      // OCR preview (when an image has been captured)
      if (this.ocrResult) {
        this.ocrPreview();
        Divider().color('#555').width('100%');
      }

      // Quick intent buttons (after OCR)
      if (this.showQuickIntents && this.ocrResult?.success) {
        Column() {
          Text('What to do with the text?').fontSize(12).fontColor('#868E96').padding({ left: 16, top: 8 });
          Row() {
            ForEach(this.quickIntents.slice(0, 5), (intent: { label: string; prompt: string }) => {
              Button(intent.label)
                .fontSize(12).height(32).margin({ right: 4 })
                .type(ButtonType.Normal)
                .backgroundColor('#1E3A5F').fontColor('#74C0FC').borderRadius(16)
                .onClick(() => this.processOcrWithIntent(intent.prompt));
            });
          }.padding({ left: 16, right: 16, bottom: 8 }).scrollable(ScrollDirection.Horizontal);

          // Show OCR text preview
          Text(this.ocrResult.text.length > 200
            ? this.ocrResult.text.substring(0, 200) + '...'
            : this.ocrResult.text)
            .fontSize(12).fontColor('#868E96').maxLines(4)
            .padding(12).backgroundColor('#2D2D2D').borderRadius(8)
            .margin({ left: 16, right: 16, bottom: 8 });
        };
        Divider().color('#555').width('100%');
      }

      // Chat history
      List() {
        ForEach(this.chatHistory, (item: ChatItem) => {
          ListItem() {
            Column() {
              Text(item.role === 'user' ? 'You' : 'AI')
                .fontSize(12).fontColor('#868E96').margin({ bottom: 4 });
              Text(item.content)
                .fontSize(14).fontColor('#D4D4D4')
                .backgroundColor(item.role === 'user' ? '#2D2D2D' : '#1E3A5F')
                .borderRadius(8).padding(12).width('100%');
            }.alignItems(item.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start);
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 4 });
        }, (item: ChatItem, index: number) => index.toString());
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#252526');

      // Input area
      Row() {
        TextInput({ placeholder: this.ocrResult ? 'Or type a question about the image...' : 'Ask AI...', text: this.inputText })
          .placeholderColor('#666')
          .fontColor('#D4D4D4')
          .backgroundColor('#3D3D3D')
          .borderRadius(8).height(44).layoutWeight(1)
          .onChange((value: string) => { this.inputText = value; });

        Button('Send')
          .fontSize(14).height(44).width(60).margin({ left: 8 })
          .type(ButtonType.Normal)
          .backgroundColor('#4C6EF5').fontColor('#FFFFFF').borderRadius(8)
          .enabled(!this.isLoading && this.inputText.trim().length > 0)
          .onClick(() => this.handleSend());
      }
      .width('100%').padding(12).backgroundColor('#1E1E1E');
    }
    .width('100%').height('100%').backgroundColor('#252526');
  }

  // ── OCR Preview Component ──

  @Builder ocrPreview() {
    Row() {
      Text(this.ocrResult!.method === 'ocr'
        ? '✅ Text extracted via local OCR'
        : '⚠ No text detected')
        .fontSize(13).fontColor(this.ocrResult!.success ? '#69DB7C' : '#FF8787')
        .layoutWeight(1);
      Button('✕').width(28).height(28).fontSize(12).type(ButtonType.Normal)
        .onClick(() => { this.ocrResult = null; this.showQuickIntents = false; });
    }
    .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 4 });
  }

  // ── Public API ──

  onClose?: () => void;

  setSelectedText(text: string): void {
    this.selectedText = text;
    this.agentService.setDocumentContext('Current Note', text);
  }

  // ── Handlers ──

  private async handleCapture(): Promise<void> {
    this.isCapturing = true;
    try {
      this.ocrResult = await ImageProcessor.captureAndOcr('camera');
      this.showQuickIntents = this.ocrResult.success && this.ocrResult.text.trim().length > 0;
    } catch (e) {
      this.ocrResult = { success: false, text: '', method: 'fallback', error: String(e) };
    } finally {
      this.isCapturing = false;
    }
  }

  private async handleGallery(): Promise<void> {
    this.isCapturing = true;
    try {
      this.ocrResult = await ImageProcessor.captureAndOcr('gallery');
      this.showQuickIntents = this.ocrResult.success && this.ocrResult.text.trim().length > 0;
    } catch (e) {
      this.ocrResult = { success: false, text: '', method: 'fallback', error: String(e) };
    } finally {
      this.isCapturing = false;
    }
  }

  private async processOcrWithIntent(intent: string): Promise<void> {
    if (!this.ocrResult?.success || !this.ocrResult.text.trim()) return;

    const displayText = `📷 [Image OCR text, ${this.ocrResult.text.length} chars]\nIntent: ${intent}`;
    this.chatHistory.push({ role: 'user', content: displayText });
    this.isLoading = true;
    this.showQuickIntents = false;

    try {
      const response = await this.agentService.processImage(this.ocrResult.text, intent);
      this.chatHistory.push({ role: 'assistant', content: response });
    } catch (e) {
      this.chatHistory.push({
        role: 'assistant',
        content: 'Error: ' + (e instanceof Error ? e.message : String(e))
      });
    } finally {
      this.isLoading = false;
      this.ocrResult = null;
    }
  }

  private async handleSend(): Promise<void> {
    const text = this.inputText.trim();
    if (!text) return;

    // If we have OCR result, include it as context
    let prompt = text;
    if (this.ocrResult?.success && this.ocrResult.text.trim()) {
      prompt = ImageProcessor.buildPrompt(this.ocrResult, text);
      this.ocrResult = null;
      this.showQuickIntents = false;
    }

    this.chatHistory.push({ role: 'user', content: prompt });
    this.inputText = '';
    this.isLoading = true;

    try {
      const response = await this.agentService.onSelection(prompt, this.selectedAction);
      this.chatHistory.push({ role: 'assistant', content: response });
    } catch (e) {
      this.chatHistory.push({
        role: 'assistant',
        content: 'Error: ' + (e instanceof Error ? e.message : String(e))
      });
    } finally {
      this.isLoading = false;
    }
  }
}

interface ChatItem {
  role: 'user' | 'assistant';
  content: string;
}
