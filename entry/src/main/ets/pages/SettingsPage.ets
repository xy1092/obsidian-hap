// SettingsPage — AI API 配置 + 工作区设置

import { ModelRouter, ModelEntry } from '../agent/ModelRouter';

@Entry
@Component
struct SettingsPage {
  @State models: ModelEntry[] = [];
  @State showAddForm: boolean = false;
  @State newName: string = '';
  @State newProvider: string = 'openai';
  @State newEndpoint: string = '';
  @State newApiKey: string = '';
  @State newModel: string = '';
  @State newTier: string = 'fast';
  @State workspaceDir: string = '/data/storage/el2/base/files/notes';

  private router: ModelRouter | null = null;

  build() {
    Column() {
      // Header
      Row() {
        Button('← Back').fontSize(14).height(36).type(ButtonType.Normal)
          .onClick(() => this.close?.());
        Blank();
        Text('Settings').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF');
        Blank();
        Text('').width(60);
      }
      .width('100%').padding(16).backgroundColor('#2D2D2D');

      Scroll() {
        Column() {
          // ── AI Models Section ──
          Text('AI Models').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .width('100%').padding({ left: 16, right: 16, top: 16, bottom: 8 });

          ForEach(this.models, (model: ModelEntry) => {
            Row() {
              Column() {
                Text(model.name).fontSize(14).fontColor('#FFFFFF');
                Text(`${model.config.provider} / ${model.config.model}`)
                  .fontSize(12).fontColor('#868E96');
              }.layoutWeight(1);

              Text(model.tier === 'fast' ? 'Fast' : 'Deep')
                .fontSize(11).fontColor('#FFFFFF')
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(model.tier === 'fast' ? '#69DB7C' : '#FF6B6B')
                .borderRadius(4);

              Button('✕').width(28).height(28).fontSize(12).type(ButtonType.Normal)
                .margin({ left: 8 })
                .onClick(() => this.removeModel(model.id));
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#2D2D2D')
            .borderRadius(8)
            .margin({ left: 16, right: 16, bottom: 8 });
          }, (model: ModelEntry) => model.id);

          Button('+ Add Model')
            .width('calc(100% - 32px)')
            .height(40)
            .type(ButtonType.Normal)
            .backgroundColor('#3D3D3D')
            .fontColor('#AAAAAA')
            .borderRadius(8)
            .margin({ left: 16, right: 16 })
            .onClick(() => this.showAddForm = !this.showAddForm);

          // Add model form
          if (this.showAddForm) {
            Column() {
              TextInput({ placeholder: 'Display name (e.g. GPT-4o)', text: this.newName })
                .onChange((v: string) => this.newName = v).margin({ bottom: 8 });

              Row() {
                ForEach(['openai', 'anthropic', 'qwen', 'custom'], (p: string) => {
                  Button(p)
                    .fontSize(12).height(32)
                    .type(ButtonType.Normal)
                    .backgroundColor(this.newProvider === p ? '#4C6EF5' : '#3D3D3D')
                    .fontColor(this.newProvider === p ? '#FFFFFF' : '#AAAAAA')
                    .borderRadius(8).margin({ right: 4 })
                    .onClick(() => this.newProvider = p);
                });
              }.margin({ bottom: 8 });

              TextInput({ placeholder: 'API Endpoint URL', text: this.newEndpoint })
                .onChange((v: string) => this.newEndpoint = v).margin({ bottom: 8 });
              TextInput({ placeholder: 'API Key', text: this.newApiKey, type: InputType.Password })
                .onChange((v: string) => this.newApiKey = v).margin({ bottom: 8 });
              TextInput({ placeholder: 'Model ID (e.g. gpt-4o)', text: this.newModel })
                .onChange((v: string) => this.newModel = v).margin({ bottom: 8 });

              Row() {
                Button('Fast Tier').fontSize(12).height(32)
                  .type(ButtonType.Normal)
                  .backgroundColor(this.newTier === 'fast' ? '#69DB7C' : '#3D3D3D')
                  .borderRadius(8).margin({ right: 4 })
                  .onClick(() => this.newTier = 'fast');
                Button('Deep Tier').fontSize(12).height(32)
                  .type(ButtonType.Normal)
                  .backgroundColor(this.newTier === 'deep' ? '#FF6B6B' : '#3D3D3D')
                  .borderRadius(8)
                  .onClick(() => this.newTier = 'deep');
              }.margin({ bottom: 8 });

              Button('Save Model')
                .height(40).width('100%')
                .type(ButtonType.Normal)
                .backgroundColor('#4C6EF5').fontColor('#FFFFFF').borderRadius(8)
                .onClick(() => this.addModel());
            }
            .width('calc(100% - 32px)')
            .padding(16)
            .backgroundColor('#252526')
            .borderRadius(8)
            .margin(16);
          }

          Divider().color('#444').margin({ top: 16, left: 16, right: 16 });

          // ── Workspace Section ──
          Text('Workspace').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .width('100%').padding(16).padding({ bottom: 8 });

          Row() {
            Text('Notes directory:').fontSize(14).fontColor('#D4D4D4').layoutWeight(1);
            Text(this.workspaceDir).fontSize(12).fontColor('#868E96')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
          }.width('calc(100% - 32px)').padding({ left: 16, right: 16, bottom: 16 });
        }
        .width('100%');
      }
      .layoutWeight(1)
      .backgroundColor('#1E1E1E');
    }
    .width('100%').height('100%').backgroundColor('#1E1E1E');
  }

  close?: () => void;

  private addModel(): void {
    if (!this.newName || !this.newEndpoint || !this.newApiKey || !this.newModel) return;

    const id = `${this.newProvider}-${Date.now()}`;
    const model: ModelEntry = {
      id,
      name: this.newName,
      tier: this.newTier as 'fast' | 'deep',
      config: {
        provider: this.newProvider,
        endpoint: this.newEndpoint,
        apiKey: this.newApiKey,
        model: this.newModel,
        maxTokens: 4096,
        temperature: 0.7,
      },
    };

    this.models.push(model);
    this.router?.register(model);

    // Reset form
    this.showAddForm = false;
    this.newName = '';
    this.newEndpoint = '';
    this.newApiKey = '';
    this.newModel = '';
  }

  private removeModel(id: string): void {
    this.models = this.models.filter(m => m.id !== id);
    this.router?.unregister(id);
  }
}
