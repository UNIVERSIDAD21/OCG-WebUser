import * as admin from 'firebase-admin';
import {onDocumentUpdated} from 'firebase-functions/v2/firestore';

const db = admin.firestore();

async function hasRecentMatchingStageHistory(
  patientId: string,
  previousStage: string,
  newStage: string,
): Promise<boolean> {
  const snap = await db
    .collection(`patients/${patientId}/stageHistory`)
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();

  return snap.docs.some((doc) => {
    const data = doc.data() ?? {};
    return String(data.etapaAnterior ?? data.etapa ?? '').trim() === previousStage &&
      String(data.etapaNueva ?? data.etapa ?? '').trim() === newStage;
  });
}

export const onPatientStageChangeWrite = onDocumentUpdated(
  {
    region: 'us-central1',
    document: 'patients/{patientId}',
  },
  async (event) => {
    const patientId = event.params.patientId;
    const before = event.data?.before.data() ?? {};
    const after = event.data?.after.data() ?? {};

    const previousStage = String(before.etapaActual ?? '').trim();
    const newStage = String(after.etapaActual ?? '').trim();

    if (!patientId || !previousStage || !newStage || previousStage === newStage) {
      return;
    }

    const alreadyTracked = await hasRecentMatchingStageHistory(
      patientId,
      previousStage,
      newStage,
    );
    if (alreadyTracked) return;

    const historyRef = db.collection(`patients/${patientId}/stageHistory`).doc();
    await historyRef.set({
      id: historyRef.id,
      patientId,
      treatmentId: String(after.primaryTreatmentId ?? '').trim(),
      etapaAnterior: previousStage,
      etapaNueva: newStage,
      esRetroceso: false,
      notas: 'Historial generado automáticamente desde cambio directo en patients.etapaActual.',
      motivoCambio: 'auto_sync_patient_stage',
      diagnosticoBreve: null,
      planSiguienteEtapa: null,
      adjuntosDescripcion: null,
      adminId: 'system:onPatientStageChangeWrite',
      status: 'completed',
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      fechaCambio: admin.firestore.FieldValue.serverTimestamp(),
      fechaEfectiva: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  },
);
