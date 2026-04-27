// ApiClient — 封装 @ohos.net.http 调用多个 AI API

import http from '@ohos.net.http';

export interface ApiConfig {
  provider: string;
  endpoint: string;
  apiKey: string;
  model: string;
  maxTokens: number;
  temperature: number;
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export class ApiClient {
  private config: ApiConfig;

  constructor(config: ApiConfig) {
    this.config = config;
  }

  setConfig(config: Partial<ApiConfig>): void {
    this.config = { ...this.config, ...config };
  }

  async chat(messages: ChatMessage[]): Promise<string> {
    const body = this.buildRequestBody(messages);
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    // different providers use different auth headers
    switch (this.config.provider) {
      case 'openai':
      case 'custom':
        headers['Authorization'] = `Bearer ${this.config.apiKey}`;
        break;
      case 'anthropic':
        headers['x-api-key'] = this.config.apiKey;
        headers['anthropic-version'] = '2023-06-01';
        break;
      case 'qwen':
        headers['Authorization'] = `Bearer ${this.config.apiKey}`;
        break;
      default:
        headers['Authorization'] = `Bearer ${this.config.apiKey}`;
    }

    const req = http.createHttp();
    const resp = await req.request(this.config.endpoint, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(body),
      connectTimeout: 15000,
      readTimeout: 90000,
    });

    req.destroy();

    if (resp.responseCode === 200 || resp.responseCode === 201) {
      const text = typeof resp.result === 'string'
        ? resp.result
        : JSON.stringify(resp.result);
      return this.parseResponse(text);
    }

    throw new Error(`API error ${resp.responseCode}: ${resp.result}`);
  }

  async chatStream(
    messages: ChatMessage[],
    onChunk: (chunk: string) => void
  ): Promise<void> {
    // For MVP, use non-streaming chat.
    // Streaming can be added later with SSE parsing.
    const result = await this.chat(messages);
    onChunk(result);
  }

  private buildRequestBody(messages: ChatMessage[]): Record<string, Object> {
    switch (this.config.provider) {
      case 'openai':
      case 'custom':
      case 'qwen':
        return {
          model: this.config.model,
          messages: messages,
          max_tokens: this.config.maxTokens,
          temperature: this.config.temperature,
        };
      case 'anthropic':
        const systemMsg = messages.find(m => m.role === 'system')?.content ?? '';
        const chatMsgs = messages.filter(m => m.role !== 'system');
        return {
          model: this.config.model,
          system: systemMsg || undefined,
          messages: chatMsgs.map(m => ({ role: m.role, content: m.content })),
          max_tokens: this.config.maxTokens,
          temperature: this.config.temperature,
        };
      default:
        return {
          model: this.config.model,
          messages: messages,
          max_tokens: this.config.maxTokens,
          temperature: this.config.temperature,
        };
    }
  }

  private parseResponse(text: string): string {
    const data = JSON.parse(text) as Record<string, Object>;

    switch (this.config.provider) {
      case 'openai':
      case 'qwen':
      case 'custom': {
        const choices = data['choices'] as Record<string, Object>[];
        const msg = choices?.[0]?.['message'] as Record<string, Object>;
        return (msg?.['content'] as string) ?? '';
      }
      case 'anthropic': {
        const content = data['content'] as Record<string, Object>[];
        return (content?.[0]?.['text'] as string) ?? '';
      }
      default:
        return '';
    }
  }
}
