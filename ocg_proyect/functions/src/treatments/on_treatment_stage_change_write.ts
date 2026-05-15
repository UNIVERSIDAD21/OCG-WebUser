import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';
import {onDocumentUpdated} from 'firebase-functions/v2/firestore';

function db(): FirebaseFirestore.Firestore {
  return admin.firestore();
}

function normalize(value: unknown): string {
  return String(value ?? '').trim();
}

function stageFrom(data: Record<string, unknown>): string {
  return normalize(data.currentStageId ?? data.etapaActual);
}

async function hasRecentMatchingTreatmentStageHistory(params: {
  firestore: FirebaseFirestore.Firestore;
  patientId: string;
  treatmentId: string;
  previousStage: string;
  newStage: string;
}): Promise<boolean> {
  const snapshot = await params.firestore
    .collection(`patients/${params.patientId}/treatments/${params.treatmentId}/stageHistory`)
    .limit(10)
    .get();

  return snapshot.docs.some((doc) => {
    const data = doc.data() ?? {};
    return (
      normalize(data.etapaAnterior ?? data.etapa) === params.previousStage &&
      normalize(data.etapaNueva ?? data.etapa) === params.newStage
    );
  });
}

export async function handleTreatmentStageChangeWrite(
  firestore: FirebaseFirestore.Firestore,
  params: {
    patientId: string;
    treatmentId: string;
  },
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): Promise<'created_history' | 'skipped'> {
  const patientId = normalize(params.patientId);
  const treatmentId = normalize(params.treatmentId);
  const previousStage = stageFrom(before);
  const newStage = stageFrom(after);
  const isPrimary = after.isPrimary === true;

  if (!patientId || !treatmentId || !previousStage || !newStage || previousStage === newStage) {
    return 'skipped';
  }

  if (isPrimary) {
    logger.info('Skipping treatment stage auto-history: primary treatment is mirrored by patient trigger', {
      patientId,
      treatmentId,
      previousStage,
      newStage,
    });
    return 'skipped';
  }

  if (
    await hasRecentMatchingTreatmentStageHistory({
      firestore,
      patientId,
      treatmentId,
      previousStage,
      newStage,
    })
  ) {
    return 'skipped';
  }

  const historyRef = firestore
    .collection(`patients/${patientId}/treatments/${treatmentId}/stageHistory`)
    .doc();

  await historyRef.set(
    {
      id: historyRef.id,
      patientId,
      treatmentId,
      etapaAnterior: previousStage,
      etapaNueva: newStage,
      esRetroceso: false,
      notas: 'Historial generado automaticamente desde cambio directo en el tratamiento.',
      motivoCambio: 'auto_sync_treatment_stage',
      diagnosticoBreve: null,
      planSiguienteEtapa: null,
      adjuntosDescripcion: null,
      adminId: normalize(after.updatedBy ?? after.createdBy) || 'system:onTreatmentStageChangeWrite',
      status: 'completed',
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      fechaCambio: admin.firestore.FieldValue.serverTimestamp(),
      fechaEfectiva: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  logger.info('Treatment stage auto-history created', {
    patientId,
    treatmentId,
    historyId: historyRef.id,
    previousStage,
    newStage,
  });

  return 'created_history';
}

export const onTreatmentStageChangeWrite = onDocumentUpdated(
  {
    region: 'us-central1',
    document: 'patients/{patientId}/treatments/{treatmentId}',
  },
  async (event) => {
    await handleTreatmentStageChangeWrite(
      db(),
      {
        patientId: event.params.patientId,
        treatmentId: event.params.treatmentId,
      },
      event.data?.before.data() ?? {},
      event.data?.after.data() ?? {},
    );
  },
);
