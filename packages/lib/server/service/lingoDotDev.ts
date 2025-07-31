// Fallback implementation without @lingo.dev/_sdk dependency
import logger from "@calcom/lib/logger";

export class LingoDotDevService {
  /**
   * Localizes text from one language to another
   * @param text The text to localize
   * @param sourceLocale The source language locale
   * @param targetLocale The target language locale
   * @returns The localized text (fallback returns null)
   */
  static async localizeText(
    text: string,
    sourceLocale: string,
    targetLocale: string
  ): Promise<string | null> {
    if (!text?.trim()) {
      return null;
    }

    try {
      // Fallback: return null since the SDK is not available
      logger.warn(`LingoDotDevService.localizeText() called but SDK not available. Returning null.`);
      return null;
    } catch (error) {
      logger.error(`LingoDotDevService.localizeText() failed for targetLocale: ${targetLocale} - ${error}`);
      return null;
    }
  }

  /**
   * Localize a text string to multiple target locales
   * @param text The text to localize
   * @param sourceLocale The source language locale
   * @param targetLocales Array of the target language locales
   * @returns The localized texts (fallback returns empty array)
   */
  static async batchLocalizeText(
    text: string,
    sourceLocale: string,
    targetLocales: string[]
  ): Promise<string[]> {
    try {
      // Fallback: return empty array since the SDK is not available
      logger.warn(
        `LingoDotDevService.batchLocalizeText() called but SDK not available. Returning empty array.`
      );
      return [];
    } catch (error) {
      logger.error(`LingoDotDevService.batchLocalizeText() failed: ${error}`);
      return [];
    }
  }

  /**
   * Localizes an array of texts from one language to another
   * @param texts Array of texts to localize
   * @param sourceLocale The source language locale
   * @param targetLocale The target language locale
   * @returns The localized texts array (fallback returns original texts)
   */
  static async localizeTexts(texts: string[], sourceLocale: string, targetLocale: string): Promise<string[]> {
    if (!texts.length) {
      return texts;
    }

    try {
      // Fallback: return original texts since the SDK is not available
      logger.warn(
        `LingoDotDevService.localizeTexts() called but SDK not available. Returning original texts.`
      );
      return texts;
    } catch (error) {
      logger.error(`LingoDotDevService.localizeTexts() failed: ${error}`);
      return texts;
    }
  }
}
