// ModelRouter — 多模型路由：根据任务类型选择 AI 模型

import { ApiConfig } from './ApiClient';

export type TaskType = 'summary' | 'continue' | 'translate' | 'analyze' | 'chat';
export type ModelTier = 'fast' | 'deep';

export interface ModelEntry {
  id: string;
  name: string;
  tier: ModelTier;
  config: ApiConfig;
}

export class ModelRouter {
  private models: ModelEntry[] = [];
  private defaultModelId: string = '';
  private fastModelId: string = '';
  private deepModelId: string = '';

  constructor() {
    // Default built-in model configs (empty, user configures)
  }

  /** Register a model */
  register(model: ModelEntry): void {
    const existing = this.models.findIndex(m => m.id === model.id);
    if (existing >= 0) {
      this.models[existing] = model;
    } else {
      this.models.push(model);
    }

    if (model.tier === 'fast' && !this.fastModelId) {
      this.fastModelId = model.id;
    }
    if (model.tier === 'deep' && !this.deepModelId) {
      this.deepModelId = model.id;
    }
    if (!this.defaultModelId) {
      this.defaultModelId = model.id;
    }
  }

  /** Remove a model */
  unregister(id: string): void {
    this.models = this.models.filter(m => m.id !== id);
    if (this.defaultModelId === id) this.defaultModelId = this.models[0]?.id ?? '';
    if (this.fastModelId === id) this.fastModelId = this.models.find(m => m.tier === 'fast')?.id ?? '';
    if (this.deepModelId === id) this.deepModelId = this.models.find(m => m.tier === 'deep')?.id ?? '';
  }

  /** Route a task to the best model */
  routeTask(task: TaskType): ApiConfig | null {
    let tier: ModelTier;
    switch (task) {
      case 'summary':
      case 'translate':
        tier = 'fast';
        break;
      case 'analyze':
        tier = 'deep';
        break;
      case 'continue':
      case 'chat':
      default:
        tier = 'fast';
        break;
    }

    return this.getConfigForTier(tier);
  }

  /** Get model config by ID */
  getConfig(id: string): ApiConfig | null {
    return this.models.find(m => m.id === id)?.config ?? null;
  }

  /** Get model config for tier */
  private getConfigForTier(tier: ModelTier): ApiConfig | null {
    const targetId = tier === 'fast' ? (this.fastModelId || this.defaultModelId) : (this.deepModelId || this.defaultModelId);
    return this.getConfig(targetId);
  }

  /** Set default model for a tier */
  setTierModel(tier: ModelTier, modelId: string): void {
    const model = this.models.find(m => m.id === modelId);
    if (!model) return;

    if (tier === 'fast') this.fastModelId = modelId;
    else this.deepModelId = modelId;
  }

  /** Get all registered models */
  get allModels(): ModelEntry[] {
    return [...this.models];
  }

  /** Set default model */
  setDefault(modelId: string): void {
    if (this.models.find(m => m.id === modelId)) {
      this.defaultModelId = modelId;
    }
  }

  get defaultModel(): string {
    return this.defaultModelId;
  }
}
