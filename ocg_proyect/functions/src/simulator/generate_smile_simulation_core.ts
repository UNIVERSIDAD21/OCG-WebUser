import * as admin from 'firebase-admin';
import {HttpsError} from 'firebase-functions/v2/https';

import {buildDentalTreatmentPrompt} from './build_dental_treatment_prompt';
import {resolveTreatmentProfile} from './treatment_profiles';

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
  treatmentType?: string; // legacy
  treatmentProfileId?: string;
  visualGoal?: string;
  doctorConfig?: Record<string, unknown>;
  photoQuality?: Record<string, unknown>;
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

// ── Helpers ─────────────────────────────────────────────

function parseAttemptCount(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.floor(value);
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.floor(parsed);
  }
  return 0;
}

function normalizeText(value?: string): string {
  return (value ?? '').replace(/\s+/g, ' ').trim();
}

function toStorableMap(
  value: Record<string, unknown> | undefined,
): Record<string, unknown> | undefined {
  if (!value || Object.keys(value).length === 0) return undefined;
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(value)) {
    out[k] = v;
  }
  return Object.keys(out).length === 0 ? undefined : out;
}

// ── Error sanitization ──────────────────────────────────

export function sanitizeSimulationErrorMessage(
  error: unknown,
): string {
  if (error instanceof HttpsError) return error.message;
  const message =
    error instanceof Error ? error.message : String(error ?? '');
  const normalized = message.replace(/\s+/g, ' ').trim();
  if (!normalized) return 'No se pudo generar la simulación con IA.';
  if (normalized.includes('OPENAI_API_KEY')) {
    return 'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.';
  }
  if (
    normalized.includes('No such object') ||
    normalized.includes('No such file') ||
    normalized.includes('object-not-found') ||
    normalized.includes('storage object not found') ||
    normalized.includes('original image not found')
  ) {
    return 'No se encontró la imagen original de esta simulación. Toma la foto nuevamente o crea una nueva simulación.';
  }
  if (normalized.length > 220) {
    return `${normalized.slice(0, 217)}...`;
  }
  return normalized;
}

// ── Auth ────────────────────────────────────────────────

export async function assertSimulationAdmin(
  deps: ProcessDeps,
): Promise<void> {
  if (!deps.auth.uid.trim()) {
    throw new HttpsError(
      'unauthenticated',
      'Autenticación requerida.',
    );
  }
  if (deps.auth.role === 'admin' || deps.auth.admin === true) return;
  const adminRole = await deps.loadAdminRole(deps.auth.uid);
  if (adminRole === 'admin') return;
  throw new HttpsError(
    'permission-denied',
    'Solo administradores pueden generar simulaciones.',
  );
}

// ── Main process ────────────────────────────────────────

export async function processGenerateSmileSimulation(
  deps: ProcessDeps,
  data: GenerateSmileSimulationData,
): Promise<Record<string, unknown>> {
  await assertSimulationAdmin(deps);

  const patientId = (data.patientId ?? '').trim();
  const simulationId = (data.simulationId ?? '').trim();
  const treatmentType = normalizeText(data.treatmentType);
  const treatmentProfileId = normalizeText(data.treatmentProfileId);
  const visualGoal = normalizeText(data.visualGoal);
  const doctorConfig = toStorableMap(data.doctorConfig);
  const photoQuality = toStorableMap(data.photoQuality);
  const notes = normalizeText(data.notes);

  if (!patientId) {
    throw new HttpsError(
      'invalid-argument',
      'patientId es obligatorio.',
    );
  }
  if (!simulationId) {
    throw new HttpsError(
      'invalid-argument',
      'simulationId es obligatorio.',
    );
  }

  const patientRef = deps.db.collection('patients').doc(patientId);
  const simulationRef = patientRef
    .collection('simulations')
    .doc(simulationId);
  const [patientSnap, simulationSnap] = await Promise.all([
    patientRef.get(),
    simulationRef.get(),
  ]);

  const profile = resolveTreatmentProfile(
    treatmentProfileId || undefined,
    treatmentType || undefined,
  );

  console.info('[SimulatorCore][start]', {
    patientId,
    simulationId,
    treatmentProfileId: profile.id,
    legacyTreatmentType: treatmentType || null,
    visualGoal: visualGoal || null,
  });

  if (!patientSnap.exists) {
    console.warn('[SimulatorCore][patient.not_found]', {
      patientId,
      simulationId,
    });
    throw new HttpsError('not-found', 'El paciente no existe.');
  }
  if (!simulationSnap.exists || !simulationSnap.data()) {
    console.warn('[SimulatorCore][simulation.not_found]', {
      patientId,
      simulationId,
    });
    throw new HttpsError(
      'not-found',
      'La simulación no existe.',
    );
  }

  const simulation = simulationSnap.data()!;
  const simulationPatientId = (simulation['patientId'] ?? '')
    .toString()
    .trim();
  if (simulationPatientId !== patientId) {
    throw new HttpsError(
      'failed-precondition',
      'La simulación no pertenece al paciente indicado.',
    );
  }

  const originalPath = (
    simulation['originalPath'] ??
    simulation['originalUrl'] ??
    ''
  )
    .toString()
    .trim();

  console.info('[SimulatorCore][simulation.loaded]', {
    patientId,
    simulationId,
    originalPath,
    simulationPatientId,
    status: (simulation['status'] ?? '').toString().trim(),
  });

  if (!originalPath) {
    console.warn('[SimulatorCore][original_path.empty]', {
      patientId,
      simulationId,
    });
    throw new HttpsError(
      'failed-precondition',
      'La simulación no tiene originalPath válido.',
    );
  }

  const allowedStatuses = new Set([
    'draft',
    'ready',
    'failed',
  ]);
  const status = (simulation['status'] ?? '').toString().trim();
  if (!allowedStatuses.has(status)) {
    throw new HttpsError(
      'failed-precondition',
      'El estado de la simulación no permite generación.',
    );
  }

  const currentAttemptCount = parseAttemptCount(
    simulation['attemptCount'],
  );
  if (currentAttemptCount >= deps.config.maxSimulationAttempts) {
    throw new HttpsError(
      'failed-precondition',
      'La simulación superó el máximo de intentos permitidos.',
    );
  }

  if (!deps.config.aiSimulatorEnabled) {
    throw new HttpsError(
      'failed-precondition',
      'El simulador IA está instalado, pero está desactivado en Firebase Functions.',
    );
  }
  if (!deps.config.openAiApiKey?.trim()) {
    throw new HttpsError(
      'failed-precondition',
      'El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.',
    );
  }

  // ── Build treatment-specific prompt (v2) ───────────────
  const promptResult = buildDentalTreatmentPrompt({
    treatmentProfileId: profile.id,
    legacyTreatmentType: treatmentType || undefined,
    visualGoal: visualGoal || undefined,
    doctorConfig: doctorConfig,
    notes: notes || undefined,
  });

  const modelUsed = deps.config.openAiImageModel ?? 'gpt-image-2';
  const nextAttemptCount = currentAttemptCount + 1;

  // ── Mark generating + save profile metadata ────────────
  await simulationRef.set(
    {
      status: 'generating',
      attemptCount: nextAttemptCount,
      errorMessage: null,
      promptUsed: promptResult.promptUsed,
      promptVersion: promptResult.promptVersion,
      generationProvider: 'openai',
      modelUsed,
      treatmentProfileId: profile.id,
      visualGoal: visualGoal || null,
      doctorConfig: doctorConfig ?? null,
      photoQuality: photoQuality ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastGenerationRequestedAt:
        admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  console.info('[SimulatorCore][prompt.built]', {
    promptVersion: promptResult.promptVersion,
    treatmentProfileId: profile.id,
    // Do NOT log full prompt — may contain sensitive clinical notes
  });

  // ── Generate with OpenAI ───────────────────────────────
  try {
    const originalBytes = await deps.storage.download(
      originalPath,
    );
    if (originalBytes.length === 0) {
      throw new Error(
        'No se pudo leer la imagen original desde Storage.',
      );
    }

    const client = deps.createOpenAiClient(
      deps.config.openAiApiKey,
    );
    const resultBytes = await client.generateEditedImage({
      originalBytes,
      prompt: promptResult.promptUsed,
      model: modelUsed,
      size: deps.config.openAiImageSize,
      quality: deps.config.openAiImageQuality,
    });

    const resultPath = `simulations/${patientId}/${simulationId}/result.jpg`;
    await deps.storage.save(resultPath, resultBytes);

    await simulationRef.set(
      {
        resultPath,
        status: 'ready',
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        promptUsed: promptResult.promptUsed,
        promptVersion: promptResult.promptVersion,
        treatmentProfileId: profile.id,
        visualGoal: visualGoal || null,
        doctorConfig: doctorConfig ?? null,
        photoQuality: photoQuality ?? null,
        modelUsed,
        generationProvider: 'openai',
        errorMessage: null,
        compartidaConPaciente: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    console.info('[SimulatorCore][generated.success]', {
      patientId,
      simulationId,
      treatmentProfileId: profile.id,
      promptVersion: promptResult.promptVersion,
    });

    return {
      ok: true,
      patientId,
      simulationId,
      resultPath,
      status: 'ready',
      generationProvider: 'openai',
      modelUsed,
      promptVersion: promptResult.promptVersion,
      treatmentProfileId: profile.id,
    };
  } catch (error) {
    const safeMessage = sanitizeSimulationErrorMessage(error);
    await simulationRef.set(
      {
        status: 'failed',
        errorMessage: safeMessage,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    console.warn('[SimulatorCore][generated.failed]', {
      patientId,
      simulationId,
      treatmentProfileId: profile.id,
      error: safeMessage,
    });
    throw new HttpsError('internal', safeMessage);
  }
}
