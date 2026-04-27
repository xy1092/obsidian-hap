// EditorToolbar — 编辑工具栏

@Component
export struct EditorToolbar {
  @Link isPreview: boolean;
  onTogglePreview?: () => void;
  onBold?: () => void;
  onItalic?: () => void;
  onHeading?: () => void;
  onCode?: () => void;
  onAgentToggle?: () => void;

  build() {
    Row() {
      // Formatting buttons
      Button('B')
        .fontSize(16).fontWeight(FontWeight.Bold)
        .width(36).height(36).margin({ right: 4 })
        .type(ButtonType.Normal)
        .onClick(() => this.onBold?.());

      Button('I')
        .fontSize(16).fontStyle(FontStyle.Italic)
        .width(36).height(36).margin({ right: 4 })
        .type(ButtonType.Normal)
        .onClick(() => this.onItalic?.());

      Button('H')
        .fontSize(16).fontWeight(FontWeight.Bold)
        .width(36).height(36).margin({ right: 4 })
        .type(ButtonType.Normal)
        .onClick(() => this.onHeading?.());

      Button('<>')
        .fontSize(14)
        .width(36).height(36).margin({ right: 4 })
        .type(ButtonType.Normal)
        .onClick(() => this.onCode?.());

      Divider().vertical(true).height(28).margin({ left: 8, right: 8 });

      // Preview toggle
      Button(this.isPreview ? 'Edit' : 'Preview')
        .fontSize(14)
        .height(36)
        .type(ButtonType.Normal)
        .onClick(() => {
          this.isPreview = !this.isPreview;
          this.onTogglePreview?.();
        });

      Blank();

      // AI Agent toggle
      Button('AI')
        .fontSize(14).fontWeight(FontWeight.Bold)
        .height(36).width(44)
        .backgroundColor('#4C6EF5').fontColor('#FFFFFF')
        .type(ButtonType.Normal)
        .borderRadius(8)
        .onClick(() => this.onAgentToggle?.());
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#2D2D2D')
    .borderRadius({ topLeft: 8, topRight: 8 });
  }
}
