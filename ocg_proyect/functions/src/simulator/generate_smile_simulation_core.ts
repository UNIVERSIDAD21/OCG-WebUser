import * as admin from 'firebase-admin';
import {HttpsError} from 'firebase-functions/v2/https';

import {buildSmilePrompt} from './build_smile_prompt';

export type SimulatorConfigLike = {
  openAiApiKey?: string;
  openAiImageModel?: string;
  openAiImageQuality: string;
  openAiImageSize: string;
  aiSimulatorEnabled: boolean;
  maxSimulationAttempts: number;
};

export type GenerateSmileSimulationData = {
  patientId?: string;
  simulationId?: string;
  treatmentType?: string;
  notes?: string;
};

export type AdminAuth = {
  uid: string;
  role?: string;
  admin?: boolean;
};

export type SimulationOpenAiClient = {
  generateEditedImage(args: {
    originalBytes: Buffer;
    prompt: string;
    model: string;
    size: string;
    quality: string;
  }): Promise<Buffer>;
};

export type ProcessDeps = {
  db: admin.firestore.Firestore;
  storage: {
    download(path: string): Promise<Buffer>;
    save(path: string, bytes: Buffer): Promise<void>;
  };
  config: SimulatorConfigLike;
  auth: AdminAuth;
  loadAdminRole: (uid: string) => Promise<string | null>;
  createOpenAiClient: (apiKey: string) => SimulationOpenAiClient;
};

function parseAttemptCount(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.floor(value);
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.floor(parsed);
  }
  return 0;
}

export function sanitizeSimulationErrorMessage(error: unknown): string {
  if (error instanceof HttpsError) return error.message;
  const message = error instanceof Error ? error.message : String(error ?? '');
  const normalized = message.replace(/\s+/g, ' ').trim();
  if (!normalized) return 'No se pudo generar la simulación con IA.';
  if (normalized.includes('OPENAI_API_KEY')) {
    return 'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.';
  }
  if (normalized.length > 220) return `${normalized.slice(0, 217)}...`;
  return normalized;
}

export async function assertSimulationAdmin(deps: ProcessDeps): Promise<void> {
  if (!deps.auth.uid.trim()) {
    throw new HttpsError('unauthenticated', 'Autenticación requerida.');
  }
  if (deps.auth.role === 'admin' || deps.auth.admin === true) return;
  const adminRole = await deps.loadAdminRole(deps.auth.uid);
  if (adminRole === 'admin') return;
  throw new HttpsError('permission-denied', 'Solo administradores pueden generar simulaciones.');
}

export async function processGenerateSmileSimulation(
  deps: ProcessDeps,
  data: GenerateSmileSimulationData,
): Promise<Record<string, unknown>> {
  await assertSimulationAdmin(deps);

  const patientId = data.patientId?.trim() ?? '';
  const simulationId = data.simulationId?.trim() ?? '';
  const treatmentType = data.treatmentType?.trim() ?? '';
  const notes = data.notes?.trim() ?? '';

  if (!patientId) throw new HttpsError('invalid-argument', 'patientId es obligatorio.');
  if (!simulationId) throw new HttpsError('invalid-argument', 'simulationId es obligatorio.');

  const patientRef = deps.db.collection('patients').doc(patientId);
  const simulationRef = patientRef.collection('simulations').doc(simulationId);
  const [patientSnap, simulationSnap] = await Promise.all([patientRef.get(), simulationRef.get()]);

  if (!patientSnap.exists) throw new HttpsError('not-found', 'El paciente no existe.');
  if (!simulationSnap.exists || !simulationSnap.data()) {
    throw new HttpsError('not-found', 'La simulación no existe.');
  }

  const simulation = simulationSnap.data()!;
  const simulationPatientId = (simulation['patientId'] ?? '').toString().trim();
  if (simulationPatientId !== patientId) {
    throw new HttpsError('failed-precondition', 'La simulación no pertenece al paciente indicado.');
  }

  const originalPath = (simulation['originalPath'] ?? simulation['originalUrl'] ?? '').toString().trim();
  if (!originalPath) {
    throw new HttpsError('failed-precondition', 'La simulación no tiene originalPath válido.');
  }

  const allowedStatuses = new Set(['draft', 'ready', 'failed']);
  const status = (simulation['status'] ?? '').toString().trim();
  if (!allowedStatuses.has(status)) {
    throw new HttpsError('failed-precondition', 'El estado de la simulación no permite generación.');
  }

  const currentAttemptCount = parseAttemptCount(simulation['attemptCount']);
  if (currentAttemptCount >= deps.config.maxSimulationAttempts) {
    throw new HttpsError('failed-precondition', 'La simulación superó el máximo de intentos permitidos.');
  }

  if (!deps.config.aiSimulatorEnabled) {
    throw new HttpsError('failed-precondition', 'El simulador IA está instalado, pero está desactivado en Firebase Functions.');
  }
  if (!deps.config.openAiApiKey?.trim()) {
    throw new HttpsError('failed-precondition', 'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.');
  }

  const prompt = buildSmilePrompt({
    treatmentType: treatmentType || (simulation['treatmentType'] ?? '').toString(),
    notes: notes || (simulation['notes'] ?? '').toString(),
  });
  const modelUsed = deps.config.openAiImageModel ?? 'gpt-image-2';
  const nextAttemptCount = currentAttemptCount + 1;

  await simulationRef.set({
    status: 'generating',
    attemptCount: nextAttemptCount,
    errorMessage: null,
    promptUsed: prompt.promptUsed,
    promptVersion: prompt.promptVersion,
    generationProvider: 'openai',
    modelUsed,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastGenerationRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  try {
    const originalBytes = await deps.storage.download(originalPath);
    if (originalBytes.length === 0) {
      throw new Error('No se pudo leer la imagen original desde Storage.');
    }

    const client = deps.createOpenAiClient(deps.config.openAiApiKey);
    const resultBytes = await client.generateEditedImage({
      originalBytes,
      prompt: prompt.promptUsed,
      model: modelUsed,
      size: deps.config.openAiImageSize,
      quality: deps.config.openAiImageQuality,
    });

    const resultPath = `simulations/${patientId}/${simulationId}/result.jpg`;
    await deps.storage.save(resultPath, resultBytes);

    await simulationRef.set({
      resultPath,
      status: 'ready',
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      promptUsed: prompt.promptUsed,
      promptVersion: prompt.promptVersion,
      modelUsed,
      generationProvider: 'openai',
      errorMessage: null,
      compartidaConPaciente: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return {
      ok: true,
      patientId,
      simulationId,
      resultPath,
      status: 'ready',
      generationProvider: 'openai',
      modelUsed,
      promptVersion: prompt.promptVersion,
    };
  } catch (error) {
    const safeMessage = sanitizeSimulationErrorMessage(error);
    await simulationRef.set({
      status: 'failed',
      errorMessage: safeMessage,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    throw new HttpsError('internal', safeMessage);
  }
}
