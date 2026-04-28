import {defineSecret} from 'firebase-functions/params';

type OpenAiImageQuality = 'low' | 'medium' | 'high' | 'auto';
type OpenAiImageSize =
  | 'auto'
  | '1024x1024'
  | '256x256'
  | '512x512'
  | '1536x1024'
  | '1024x1536';

type SimulatorConfig = {
  openAiApiKey?: string;
  openAiImageModel?: string;
  openAiImageQuality: OpenAiImageQuality;
  openAiImageSize: OpenAiImageSize;
  aiSimulatorEnabled: boolean;
  maxSimulationAttempts: number;
};

export const openAiApiKeySecret = defineSecret('OPENAI_API_KEY');

function parseBoolean(value: string | undefined): boolean {
  if (!value) return false;
  const normalized = value.trim().toLowerCase();
  return normalized === 'true' || normalized === '1' || normalized === 'yes';
}

function parsePositiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number(value ?? '');
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
}

function parseQuality(value: string | undefined): OpenAiImageQuality {
  const normalized = (value ?? '').trim().toLowerCase();
  if (
    normalized === 'low' ||
    normalized === 'medium' ||
    normalized === 'high' ||
    normalized === 'auto'
  ) {
    return normalized;
  }
  return 'medium';
}

function parseSize(value: string | undefined): OpenAiImageSize {
  const normalized = (value ?? '').trim();
  if (
    normalized === 'auto' ||
    normalized === '1024x1024' ||
    normalized === '256x256' ||
    normalized === '512x512' ||
    normalized === '1536x1024' ||
    normalized === '1024x1536'
  ) {
    return normalized;
  }
  return '1024x1024';
}

export function loadSimulatorConfig(): SimulatorConfig {
  return {
    openAiApiKey: openAiApiKeySecret.value(),
    openAiImageModel: process.env.OPENAI_IMAGE_MODEL?.trim() || 'gpt-image-2',
    openAiImageQuality: parseQuality(process.env.OPENAI_IMAGE_QUALITY),
    openAiImageSize: parseSize(process.env.OPENAI_IMAGE_SIZE),
    aiSimulatorEnabled: parseBoolean(process.env.AI_SIMULATOR_ENABLED),
    maxSimulationAttempts: parsePositiveInt(
      process.env.MAX_SIMULATION_ATTEMPTS,
      3,
    ),
  };
}
