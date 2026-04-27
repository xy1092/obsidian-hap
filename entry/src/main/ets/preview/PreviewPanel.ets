// PreviewPanel — Markdown 预览 (WebView 渲染)

import { NoteBridge } from '../engine/NoteBridge';

@Component
export struct PreviewPanel {
  @Prop markdown: string;
  @State htmlContent: string = '';
  controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.renderPreview();
  }

  build() {
    Web({ controller: this.controller })
      .width('100%')
      .height('100%')
      .backgroundColor('#1E1E1E')
      .javaScriptAccess(true)
      .darkMode(WebDarkMode.On)
      .onControllerAttached(() => {
        this.loadHtml();
      });
  }

  private renderPreview(): void {
    try {
      const result = NoteBridge.parseMarkdown(this.markdown);
      if (result.html) {
        this.htmlContent = this.wrapHtml(result.html);
      } else {
        this.htmlContent = this.wrapHtml('<p><em>Preview unavailable</em></p>');
      }
    } catch (e) {
      this.htmlContent = this.wrapHtml('<p><em>Preview error: ' + e + '</em></p>');
    }
  }

  private loadHtml(): void {
    this.controller.loadData(
      this.htmlContent,
      'text/html',
      'UTF-8',
      'http://localhost/'
    );
  }

  private wrapHtml(body: string): string {
    return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body {
    font-family: -apple-system, "HarmonyOS Sans SC", sans-serif;
    padding: 24px;
    max-width: 800px;
    margin: 0 auto;
    background: #1E1E1E;
    color: #D4D4D4;
    line-height: 1.7;
  }
  h1 { color: #FF6B6B; font-size: 2em; border-bottom: 2px solid #FF6B6B; padding-bottom: 8px; }
  h2 { color: #FFA94D; font-size: 1.5em; }
  h3 { color: #FFD43B; font-size: 1.17em; }
  strong { color: #FFFFFF; }
  code { background: #2D2D2D; padding: 2px 6px; border-radius: 4px; color: #69DB7C; }
  pre { background: #2D2D2D; padding: 16px; border-radius: 8px; overflow-x: auto; }
  pre code { background: none; padding: 0; }
  blockquote { border-left: 4px solid #4C6EF5; padding-left: 16px; color: #868E96; margin-left: 0; }
  a { color: #74C0FC; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #444; padding: 8px 12px; text-align: left; }
  th { background: #2D2D2D; }
  ul, ol { padding-left: 24px; }
  hr { border: none; border-top: 1px solid #444; margin: 24px 0; }
  img { max-width: 100%; }
  .task-list-item { list-style: none; }
</style>
</head>
<body>${body}</body>
</html>`;
  }
}
