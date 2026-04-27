// FileList — 文件列表面板

import { NoteBridge, NoteMeta } from '../engine/NoteBridge';

@Component
export struct FileList {
  @Prop workspaceDir: string;
  @State notes: NoteMeta[] = [];
  @State searchQuery: string = '';
  onSelectNote?: (path: string) => void;
  onNewNote?: () => void;
  onClose?: () => void;

  aboutToAppear(): void {
    this.refreshList();
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('Notes').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF');
        Blank();
        Button('+').width(32).height(32).type(ButtonType.Normal)
          .fontSize(20).fontColor('#4C6EF5')
          .onClick(() => this.handleNew());
      }
      .width('100%').padding(12);

      // Search
      TextInput({ placeholder: 'Search notes...', text: this.searchQuery })
        .placeholderColor('#666')
        .fontColor('#D4D4D4')
        .backgroundColor('#3D3D3D')
        .borderRadius(8)
        .height(36)
        .margin({ left: 12, right: 12, bottom: 8 })
        .onChange((value: string) => {
          this.searchQuery = value;
          if (value.trim()) {
            const results = NoteBridge.search(value);
            this.notes = results.map(r => ({
              path: r.path,
              title: r.title,
              modified: 0,
              size: 0,
            }));
          } else {
            this.refreshList();
          }
        });

      // File list
      List() {
        ForEach(this.notes, (note: NoteMeta) => {
          ListItem() {
            Column() {
              Text(note.title || 'Untitled')
                .fontSize(14).fontColor('#D4D4D4').maxLines(1);
              Text(note.path)
                .fontSize(11).fontColor('#868E96').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
            .width('100%')
            .padding(12)
            .onClick(() => this.onSelectNote?.(note.path));
          }
          .width('100%')
          .backgroundColor('#00000000');
        }, (note: NoteMeta) => note.path);
      }
      .width('100%')
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#252526');
  }

  private refreshList(): void {
    if (this.workspaceDir) {
      this.notes = NoteBridge.listNotes(this.workspaceDir);
    }
  }

  private handleNew(): void {
    this.onNewNote?.();
    this.refreshList();
  }
}
