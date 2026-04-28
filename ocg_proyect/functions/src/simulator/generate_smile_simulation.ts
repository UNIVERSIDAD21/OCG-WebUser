import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';
import OpenAI, {toFile} from 'openai';

import {buildSmilePrompt} from './build_smile_prompt';
import {loadSimulatorConfig, openAiApiKeySecret} from './simulator_config';

type GenerateSmileSimulationData = {
  patientId?: string;
  simulationId?: string;
  treatmentType?: string;
  notes?: string;
};

type AdminAuth = {
  uid: string;
  role?: string;
};

function getAuth(request: CallableRequest<GenerateSmileSimulationData>): AdminAuth {
  const uid = request.auth?.uid?.trim();
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Autenticación requerida.');
  }

  const roleToken = request.auth?.token?.role;
  return {uid, role: typeof roleToken === 'string' ? roleToken : undefined};
}

async function assertAdmin(
  request: CallableRequest<GenerateSmileSimulationData>,
): Promise<AdminAuth> {
  const auth = getAuth(request);
  const tokenIsAdmin =
    auth.role === 'admin' || request.auth?.token?.admin === true;

  if (tokenIsAdmin) return auth;

  const adminDoc = await admin.firestore().collection('admins').doc(auth.uid).get();
  const adminRole = adminDoc.data()?.['role'];
  if (adminDoc.exists && adminRole === 'admin') {
    return auth;
  }

  throw new HttpsError(
    'permission-denied',
    'Solo administradores pueden generar simulaciones.',
  );
}

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

function sanitizeErrorMessage(error: unknown): string {
  if (error instanceof HttpsError) {
    return error.message;
  }

  const message = error instanceof Error ? error.message : String(error ?? '');
  const normalized = message.replace(/\s+/g, ' ').trim();

  if (!normalized) {
    return 'No se pudo generar la simulación con IA.';
  }
  if (normalized.includes('OPENAI_API_KEY')) {
    return 'OPENAI_API_KEY no está configurada en backend.';
  }
  if (normalized.length > 220) {
    return `${normalized.slice(0, 217)}...`;
  }
  return normalized;
}

function decodeGeneratedImage(response: unknown): Buffer {
  const candidate = response as {
    data?: Array<{
      b64_json?: string | null;
    }>;
  };

  const base64 = candidate.data?.[0]?.b64_json?.trim();
  if (!base64) {
    throw new Error('OpenAI no devolvió una imagen generada válida.');
  }

  return Buffer.from(base64, 'base64');
}

export const generateSmileSimulation = onCall<GenerateSmileSimulationData>(
  {
    region: 'us-central1',
    cors: true,
    secrets: [openAiApiKeySecret],
  },
  async (request: CallableRequest<GenerateSmileSimulationData>) => {
    await assertAdmin(request);

    const patientId = request.data?.patientId?.trim() ?? '';
    const simulationId = request.data?.simulationId?.trim() ?? '';
    const treatmentType = request.data?.treatmentType?.trim() ?? '';
    const notes = request.data?.notes?.trim() ?? '';

    if (!patientId) {
      throw new HttpsError('invalid-argument', 'patientId es obligatorio.');
    }
    if (!simulationId) {
      throw new HttpsError('invalid-argument', 'simulationId es obligatorio.');
    }

    const db = admin.firestore();
    const storage = admin.storage().bucket();
    const patientRef = db.collection('patients').doc(patientId);
    const simulationRef = patientRef.collection('simulations').doc(simulationId);

    const [patientSnap, simulationSnap] = await Promise.all([
      patientRef.get(),
      simulationRef.get(),
    ]);

    if (!patientSnap.exists) {
      throw new HttpsError('not-found', 'El paciente no existe.');
    }
    if (!simulationSnap.exists || !simulationSnap.data()) {
      throw new HttpsError('not-found', 'La simulación no existe.');
    }

    const simulation = simulationSnap.data()!;
    const simulationPatientId = (simulation['patientId'] ?? '').toString().trim();
    if (simulationPatientId !== patientId) {
      throw new HttpsError(
        'failed-precondition',
        'La simulación no pertenece al paciente indicado.',
      );
    }

    const originalPath = (simulation['originalPath'] ?? simulation['originalUrl'] ?? '')
      .toString()
      .trim();
    if (!originalPath) {
      throw new HttpsError(
        'failed-precondition',
        'La simulación no tiene originalPath válido.',
      );
    }

    const allowedStatuses = new Set(['draft', 'ready', 'failed']);
    const status = (simulation['status'] ?? '').toString().trim();
    if (!allowedStatuses.has(status)) {
      throw new HttpsError(
        'failed-precondition',
        'El estado de la simulación no permite generación.',
      );
    }

    const config = loadSimulatorConfig();
    const currentAttemptCount = parseAttemptCount(simulation['attemptCount']);
    if (currentAttemptCount >= config.maxSimulationAttempts) {
      throw new HttpsError(
        'failed-precondition',
        'La simulación superó el máximo de intentos permitidos.',
      );
    }

    if (!config.aiSimulatorEnabled) {
      throw new HttpsError(
        'failed-precondition',
        'La generación con IA no está habilitada.',
      );
    }

    if (!config.openAiApiKey?.trim()) {
      throw new HttpsError(
        'failed-precondition',
        'OPENAI_API_KEY no está configurada en backend.',
      );
    }

    const prompt = buildSmilePrompt({
      treatmentType: treatmentType || (simulation['treatmentType'] ?? '').toString(),
      notes: notes || (simulation['notes'] ?? '').toString(),
    });

    const nextAttemptCount = currentAttemptCount + 1;

    await simulationRef.set(
      {
        status: 'generating',
        attemptCount: nextAttemptCount,
        errorMessage: null,
        promptUsed: prompt.promptUsed,
        promptVersion: prompt.promptVersion,
        generationProvider: 'openai',
        modelUsed: config.openAiImageModel ?? 'gpt-image-2',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastGenerationRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    try {
      const [originalBytes] = await storage.file(originalPath).download();
      if (!originalBytes || originalBytes.length === 0) {
        throw new Error('No se pudo leer la imagen original desde Storage.');
      }

      const client = new OpenAI({apiKey: config.openAiApiKey});
      const originalFile = await toFile(originalBytes, 'original.jpg', {
        type: 'image/jpeg',
      });

      const response = await client.images.edit({
        model: config.openAiImageModel ?? 'gpt-image-2',
        image: originalFile,
        prompt: prompt.promptUsed,
        size: config.openAiImageSize,
        quality: config.openAiImageQuality,
      });

      const resultBytes = decodeGeneratedImage(response);
      const resultPath = `simulations/${patientId}/${simulationId}/result.jpg`;
      await storage.file(resultPath).save(resultBytes, {
        metadata: {
          contentType: 'image/jpeg',
          cacheControl: 'private, max-age=31536000',
        },
        resumable: false,
      });

      await simulationRef.set(
        {
          resultPath,
          status: 'ready',
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          promptUsed: prompt.promptUsed,
          promptVersion: prompt.promptVersion,
          modelUsed: config.openAiImageModel ?? 'gpt-image-2',
          generationProvider: 'openai',
          errorMessage: null,
          compartidaConPaciente: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      return {
        ok: true,
        patientId,
        simulationId,
        resultPath,
        status: 'ready',
        generationProvider: 'openai',
        modelUsed: config.openAiImageModel ?? 'gpt-image-2',
        promptVersion: prompt.promptVersion,
      };
    } catch (error) {
      const safeMessage = sanitizeErrorMessage(error);
      await simulationRef.set(
        {
          status: 'failed',
          errorMessage: safeMessage,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      throw new HttpsError('internal', safeMessage);
    }
  },
);
