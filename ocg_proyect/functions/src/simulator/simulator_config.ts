type SimulatorConfig = {
  openAiApiKey?: string;
  openAiImageModel?: string;
  aiSimulatorEnabled: boolean;
  maxSimulationAttempts: number;
};

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

export function loadSimulatorConfig(): SimulatorConfig {
  return {
    openAiApiKey: process.env.OPENAI_API_KEY,
    openAiImageModel: process.env.OPENAI_IMAGE_MODEL?.trim() || 'gpt-image-2',
    aiSimulatorEnabled: parseBoolean(process.env.AI_SIMULATOR_ENABLED),
    maxSimulationAttempts: parsePositiveInt(
      process.env.MAX_SIMULATION_ATTEMPTS,
      3,
    ),
  };
}
