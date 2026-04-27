// AgentPanel — AI 对话侧边栏/弹窗

import { AgentService, AgentAction } from './AgentService';
import { ModelRouter, ModelEntry } from './ModelRouter';

@Component
export struct AgentPanel {
  @Prop agentService: AgentService;
  @Prop modelRouter: ModelRouter;
  @State inputText: string = '';
  @State chatHistory: ChatItem[] = [];
  @State isLoading: boolean = false;
  @State selectedAction: AgentAction = 'chat';
  @State showModelPicker: boolean = false;
  @State selectedText: string = '';

  private actions: { label: string; action: AgentAction; icon: string }[] = [
    { label: 'Chat', action: 'chat', icon: '💬' },
    { label: 'Summary', action: 'summary', icon: '📝' },
    { label: 'Continue', action: 'continue', icon: '✍️' },
    { label: 'Translate', action: 'translate', icon: '🌐' },
    { label: 'Analyze', action: 'analyze', icon: '🔍' },
  ];

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

      // Action buttons
      Row() {
        ForEach(this.actions, (action: { label: string; action: AgentAction; icon: string }) => {
          Button(action.icon + ' ' + action.label)
            .fontSize(13)
            .height(36)
            .margin({ right: 6 })
            .type(ButtonType.Normal)
            .backgroundColor(this.selectedAction === action.action ? '#4C6EF5' : '#3D3D3D')
            .fontColor(this.selectedAction === action.action ? '#FFFFFF' : '#AAAAAA')
            .borderRadius(18)
            .onClick(() => { this.selectedAction = action.action; });
        });
      }
      .width('100%').padding({ left: 16, right: 16, bottom: 8 });

      Divider().color('#444').width('100%');

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
                .borderRadius(8).padding(12)
                .width('100%');
            }.alignItems(item.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start);
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 4 });
        }, (item: ChatItem, index: number) => index.toString());
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#252526');

      // Input area
      Row() {
        TextInput({ placeholder: 'Ask AI...', text: this.inputText })
          .placeholderColor('#666')
          .fontColor('#D4D4D4')
          .backgroundColor('#3D3D3D')
          .borderRadius(8)
          .height(44)
          .layoutWeight(1)
          .onChange((value: string) => { this.inputText = value; });

        Button('Send')
          .fontSize(14)
          .height(44)
          .width(60)
          .margin({ left: 8 })
          .type(ButtonType.Normal)
          .backgroundColor('#4C6EF5')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .enabled(!this.isLoading && this.inputText.trim().length > 0)
          .onClick(() => this.handleSend());
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#1E1E1E');
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#252526');
  }

  onClose?: () => void;

  private async handleSend(): Promise<void> {
    const text = this.inputText.trim();
    if (!text) return;

    this.chatHistory.push({ role: 'user', content: text });
    this.inputText = '';
    this.isLoading = true;

    try {
      const response = await this.agentService.onSelection(text, this.selectedAction);
      this.chatHistory.push({ role: 'assistant', content: response });
    } catch (e) {
      this.chatHistory.push({ role: 'assistant', content: 'Error: ' + (e instanceof Error ? e.message : String(e)) });
    } finally {
      this.isLoading = false;
    }
  }

  setSelectedText(text: string): void {
    this.selectedText = text;
    this.agentService.setDocumentContext('Current Note', text);
  }
}

interface ChatItem {
  role: 'user' | 'assistant';
  content: string;
}
