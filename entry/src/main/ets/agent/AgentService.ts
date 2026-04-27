// AgentService — 核心 Agent 逻辑：上下文管理 + prompt 构建 + 动作调度

import { ApiClient, ChatMessage, ApiConfig } from './ApiClient';
import { ModelRouter, TaskType } from './ModelRouter';

export type AgentAction = 'summary' | 'continue' | 'translate' | 'analyze' | 'chat';

export interface AgentConfig {
  router: ModelRouter;
}

export class AgentService {
  private router: ModelRouter;
  private history: ChatMessage[] = [];
  private documentContext: string = '';
  private maxHistory: number = 20;

  constructor(config: AgentConfig) {
    this.router = config.router;
  }

  /** Set current document context (automatically injected) */
  setDocumentContext(title: string, selectedText: string, fullContent: string = ''): void {
    this.documentContext = `Current document: "${title}"\n`;
    if (selectedText) {
      this.documentContext += `Selected text:\n"""\n${selectedText}\n"""\n`;
    }
    if (fullContent && fullContent.length < 8000) {
      this.documentContext += `Full document:\n"""\n${fullContent}\n"""\n`;
    }
  }

  /** Clear conversation history */
  clearHistory(): void {
    this.history = [];
  }

  /** Summarize */
  async summarize(text: string, language: string = 'zh'): Promise<string> {
    const config = this.router.routeTask('summary');
    return this.execute(config, [
      { role: 'system', content: `You are a professional summarizer. Summarize the following text concisely in ${language}. Use bullet points for key points. Keep it under 200 words.` },
      { role: 'user', content: text },
    ]);
  }

  /** Continue writing */
  async continueWrite(text: string, context: string = ''): Promise<string> {
    const config = this.router.routeTask('continue');
    return this.execute(config, [
      { role: 'system', content: 'You are a writing assistant. Continue the following text in the same tone and style. Do not repeat the original text — just provide the continuation.' },
      { role: 'user', content: context ? `Context:\n${context}\n\nContinue:\n${text}` : `Continue:\n${text}` },
    ]);
  }

  /** Translate */
  async translate(text: string, targetLang: string = 'zh'): Promise<string> {
    const config = this.router.routeTask('translate');
    return this.execute(config, [
      { role: 'system', content: `Translate the following text to ${targetLang === 'zh' ? 'Chinese' : targetLang}. Keep the original formatting and tone.` },
      { role: 'user', content: text },
    ]);
  }

  /** Deep analysis */
  async analyze(text: string): Promise<string> {
    const config = this.router.routeTask('analyze');
    return this.execute(config, [
      { role: 'system', content: 'Analyze the following text deeply. Identify: 1) Main arguments 2) Key evidence 3) Assumptions 4) Potential counterarguments 5) Structural quality. Be concise.' },
      { role: 'user', content: text },
    ]);
  }

  /** Open-ended chat */
  async chat(prompt: string): Promise<string> {
    const config = this.router.routeTask('chat');
    const messages: ChatMessage[] = [];

    if (this.documentContext) {
      messages.push({ role: 'system', content: `You are a helpful note-taking assistant. ${this.documentContext}` });
    }
    messages.push({ role: 'user', content: prompt });

    return this.execute(config, messages);
  }

  /** Handle agent action on selection */
  async onSelection(text: string, action: AgentAction): Promise<string> {
    switch (action) {
      case 'summary': return this.summarize(text);
      case 'continue': return this.continueWrite(text);
      case 'translate': return this.translate(text);
      case 'analyze': return this.analyze(text);
      case 'chat': return this.chat(text);
      default: return this.chat(text);
    }
  }

  private async execute(config: ApiConfig | null, messages: ChatMessage[]): Promise<string> {
    if (!config) return 'Error: No AI model configured. Go to Settings to add an API key.';

    try {
      const client = new ApiClient(config);
      const response = await client.chat(messages);

      // update history
      this.history.push(...messages.filter(m => m.role === 'user'));
      this.history.push({ role: 'assistant', content: response });

      // trim history
      if (this.history.length > this.maxHistory) {
        this.history = this.history.slice(-this.maxHistory);
      }

      return response;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return `AI Error: ${msg}`;
    }
  }
}
