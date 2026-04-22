import {onDocumentCreated} from 'firebase-functions/v2/firestore';

import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';

import {notifyPatientTreatmentStageEvent} from '../notifications/domain_notifications';

const STAGE_NAMES: Record<string, string> = {
  valoracionInicial: 'Valoración inicial',
  estudioPlaneacion: 'Estudio y planeación',
  instalacion: 'Instalación',
  controles: 'Controles',
  retencion: 'Retención',
  alta: 'Alta',
  diagnostico: 'Valoración inicial',
  planificacion: 'Estudio y planeación',
  seguimientoActivo: 'Controles',
  ajusteFinal: 'Controles',
};

function stageLabel(stage: string): string {
  return STAGE_NAMES[stage] ?? stage;
}

export const onPatientStageHistoryCreate = onDocumentCreated(
  {
    region: 'us-central1',
    document: 'patients/{patientId}/stageHistory/{historyId}',
  },
  async (event) => {
    const db = admin.firestore();
    const patientId = event.params.patientId;
    const historyId = event.params.historyId;
    const data = event.data?.data() ?? {};

    const previousStage = String(data.etapaAnterior ?? '').trim() || String(data.etapa ?? '').trim();
    const newStage = String(data.etapaNueva ?? data.etapa ?? '').trim();
    const treatmentId = String(data.treatmentId ?? '').trim();

    if (!patientId || !historyId || !newStage) return;

    logger.info('Processing treatment stage history notification', {
      patientId,
      historyId,
      treatmentId,
      previousStage: previousStage || null,
      newStage,
    });

    await notifyPatientTreatmentStageEvent(db, {
      notificationId: `stage_${historyId}`,
      patientId,
      treatmentId,
      stageHistoryId: historyId,
      previousStage: previousStage || null,
      newStage,
      title: 'Tu tratamiento avanzó de etapa',
      body: previousStage
        ? `Tu tratamiento cambió de ${stageLabel(previousStage)} a ${stageLabel(newStage)}.`
        : `Tu tratamiento está ahora en ${stageLabel(newStage)}.`,
    });
  },
);
