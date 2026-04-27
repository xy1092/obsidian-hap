// ImageProcessor — 本地 OCR + 云侧多模态回退管道
//
// 管道:
//   图片 → @kit.AIKit textRecognition (本地 OCR 提取文字)
//        → 文本模型 (DeepSeek/任意) 结构化处理
//
// 如果设备不支持 OCR，回退到纯文本提示（用户手动描述图片）

import { textRecognition } from '@kit.AIKit';
import { image } from '@kit.ImageKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** OCR 提取结果 */
export interface OcrResult {
  success: boolean;
  text: string;           // OCR 提取的原始文字
  imageBase64?: string;   // 图片 base64（供支持多模态的模型用）
  imagePath?: string;     // 图片本地路径
  method: 'ocr' | 'multimodal' | 'fallback';  // 用哪种方式处理的
  error?: string;
}

/** 处理配置 */
export interface ImageProcessConfig {
  /** 主力模型是否支持多模态图片输入 */
  primaryModelHasVision: boolean;
  /** 备用多模态模型配置（可选，如 GPT-4o） */
  fallbackVisionModel?: string;
}

export class ImageProcessor {

  /** 从相机/相册获取图片并 OCR 提取文字 */
  static async captureAndOcr(
    source: 'camera' | 'gallery' = 'gallery'
  ): Promise<OcrResult> {
    try {
      // 1. 选取图片
      const uris = await this.pickImage(source);
      if (!uris || uris.length === 0) {
        return { success: false, text: '', method: 'fallback', error: 'No image selected' };
      }

      const uri = uris[0];

      // 2. 读取图片为 PixelMap
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(fileIo.statSync(uri).size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);

      const imageSource = image.createImageSource(buf);
      const pixelMap = await imageSource.createPixelMap();

      // 3. 本地 OCR 提取文字
      const ocrText = await this.runOcr(pixelMap);

      if (ocrText.trim()) {
        return {
          success: true,
          text: ocrText,
          imagePath: uri,
          method: 'ocr',
        };
      }

      // OCR 没提取到文字，回退
      return {
        success: true,
        text: '[Image selected — no text detected by OCR]',
        imagePath: uri,
        method: 'fallback',
      };
    } catch (e) {
      const msg = e instanceof BusinessError ? e.message : String(e);
      return { success: false, text: '', method: 'fallback', error: msg };
    }
  }

  /** 从已有的 PixelMap 做 OCR */
  static async ocrFromPixelMap(pixelMap: image.PixelMap): Promise<OcrResult> {
    try {
      const text = await this.runOcr(pixelMap);
      return {
        success: true,
        text,
        method: 'ocr',
      };
    } catch (e) {
      return {
        success: false,
        text: '',
        method: 'fallback',
        error: String(e),
      };
    }
  }

  /** 构建发给 AI 的 prompt（OCR 文字 + 用户意图） */
  static buildPrompt(ocrResult: OcrResult, userIntent: string): string {
    const parts: string[] = [];

    if (ocrResult.method === 'ocr' && ocrResult.text) {
      parts.push('The following text was extracted from an image via OCR:');
      parts.push('"""');
      parts.push(ocrResult.text);
      parts.push('"""');
    }

    parts.push('');
    parts.push(userIntent);

    return parts.join('\n');
  }

  /** 预设的快捷意图 prompt */
  static getQuickIntents(): { label: string; prompt: string }[] {
    return [
      { label: 'Summarize', prompt: 'Summarize the content from the image above concisely. Use bullet points.' },
      { label: 'To Table', prompt: 'Convert any tabular data in the image above into a Markdown table.' },
      { label: 'Translate to EN', prompt: 'Translate the text from the image above to English.' },
      { label: 'To Note', prompt: 'Convert the content from the image above into a well-structured Markdown note with headings, bullet points, and emphasis where appropriate.' },
      { label: 'Extract Keywords', prompt: 'Extract 5-10 key concepts/keywords from the image above. List them as tags.' },
    ];
  }

  // ── Private helpers ──

  private static async pickImage(source: 'camera' | 'gallery'): Promise<string[]> {
    const documentPicker = new picker.PhotoViewPicker();
    const result = await documentPicker.select({
      MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1,
    });
    return result.photoUris;
  }

  private static async runOcr(pixelMap: image.PixelMap): Promise<string> {
    try {
      // HarmonyOS textRecognition API
      const visionInfo: textRecognition.VisionInfo = {
        pixelMap: pixelMap,
        // 只提取文字，不做结构化
      };
      const result = await textRecognition.recognizeText(pixelMap);
      return result.text ?? '';
    } catch (_) {
      // OCR API 可能不可用（老设备/权限不足）
      return '';
    }
  }
}
