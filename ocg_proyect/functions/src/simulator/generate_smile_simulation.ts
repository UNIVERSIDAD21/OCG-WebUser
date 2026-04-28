import * as admin from 'firebase-admin';
import {CallableRequest, HttpsError, onCall} from 'firebase-functions/v2/https';

import {buildSmilePrompt} from './build_smile_prompt';
import {loadSimulatorConfig} from './simulator_config';

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

export const generateSmileSimulation = onCall<GenerateSmileSimulationData>(
  {region: 'us-central1', cors: true},
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
    if (simulationPatientId != patientId) {
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
    const attemptCount = parseAttemptCount(simulation['attemptCount']);
    if (attemptCount >= config.maxSimulationAttempts) {
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
      treatmentType,
      notes,
    });

    await simulationRef.set(
      {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        promptUsed: prompt.promptUsed,
        promptVersion: prompt.promptVersion,
        generationProvider: 'openai',
        modelUsed: config.openAiImageModel ?? 'gpt-image-2',
        lastGenerationRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {
      ok: true,
      patientId,
      simulationId,
      generationProvider: 'openai',
      modelUsed: config.openAiImageModel ?? 'gpt-image-2',
      promptVersion: prompt.promptVersion,
      message:
        'Base backend lista. La conexión real con GPT-Image-2 se implementará en el siguiente bloque.',
    };
  },
);
