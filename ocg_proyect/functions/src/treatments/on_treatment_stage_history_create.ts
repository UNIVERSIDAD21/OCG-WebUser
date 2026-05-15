import {onDocumentCreated} from 'firebase-functions/v2/firestore';

import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';

import {notifyPatientTreatmentStageEvent} from '../notifications/domain_notifications';

const STAGE_NAMES: Record<string, string> = {
  valoracionInicial: 'Valoracion inicial',
  estudioPlaneacion: 'Estudio y planeacion',
  instalacion: 'Instalacion',
  controles: 'Controles',
  retencion: 'Retencion',
  alta: 'Alta',
  diagnostico: 'Valoracion inicial',
  planificacion: 'Estudio y planeacion',
  seguimientoActivo: 'Controles',
  ajusteFinal: 'Controles',
};

function normalize(value: unknown): string {
  return String(value ?? '').trim();
}

function stageLabel(stage: string): string {
  return STAGE_NAMES[stage] ?? stage;
}

async function hasMatchingPatientStageHistory(params: {
  db: FirebaseFirestore.Firestore;
  patientId: string;
  treatmentId: string;
  previousStage: string;
  newStage: string;
}): Promise<boolean> {
  const snapshot = await params.db
    .collection(`patients/${params.patientId}/stageHistory`)
    .limit(20)
    .get();

  return snapshot.docs.some((doc) => {
    const data = doc.data() ?? {};
    const previous = normalize(data.etapaAnterior ?? data.etapa);
    const next = normalize(data.etapaNueva ?? data.etapa);
    const treatmentId = normalize(data.treatmentId);
    return (
      previous === params.previousStage &&
      next === params.newStage &&
      (!treatmentId || treatmentId === params.treatmentId)
    );
  });
}

export async function handleTreatmentStageHistoryCreate(
  db: FirebaseFirestore.Firestore,
  params: {
    patientId: string;
    treatmentId: string;
    historyId: string;
  },
  data: Record<string, unknown>,
): Promise<'notified' | 'skipped'> {
  const patientId = normalize(params.patientId);
  const treatmentId = normalize(params.treatmentId);
  const historyId = normalize(params.historyId);
  const previousStage = normalize(data.etapaAnterior ?? data.etapa);
  const newStage = normalize(data.etapaNueva ?? data.etapa);

  if (!patientId || !treatmentId || !historyId || !newStage) {
    return 'skipped';
  }

  if (
    await hasMatchingPatientStageHistory({
      db,
      patientId,
      treatmentId,
      previousStage,
      newStage,
    })
  ) {
    logger.info('Skipping treatment stage notification: patient history already covers it', {
      patientId,
      treatmentId,
      historyId,
      previousStage: previousStage || null,
      newStage,
    });
    return 'skipped';
  }

  logger.info('Processing treatment-specific stage history notification', {
    patientId,
    treatmentId,
    historyId,
    previousStage: previousStage || null,
    newStage,
  });

  await notifyPatientTreatmentStageEvent(db, {
    notificationId: `stage_treatment_${historyId}`,
    patientId,
    treatmentId,
    stageHistoryId: historyId,
    previousStage: previousStage || null,
    newStage,
    title: 'Tu tratamiento avanzo de etapa',
    body: previousStage
      ? `Tu tratamiento cambio de ${stageLabel(previousStage)} a ${stageLabel(newStage)}.`
      : `Tu tratamiento esta ahora en ${stageLabel(newStage)}.`,
  });

  return 'notified';
}

export const onTreatmentStageHistoryCreate = onDocumentCreated(
  {
    region: 'us-central1',
    document: 'patients/{patientId}/treatments/{treatmentId}/stageHistory/{historyId}',
  },
  async (event) => {
    await handleTreatmentStageHistoryCreate(
      admin.firestore(),
      {
        patientId: event.params.patientId,
        treatmentId: event.params.treatmentId,
        historyId: event.params.historyId,
      },
      event.data?.data() ?? {},
    );
  },
);
