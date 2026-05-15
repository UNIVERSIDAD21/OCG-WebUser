import * as admin from 'firebase-admin';

export type PaymentAccountSnapshot = {
  patientId: string;
  treatmentId: string;
  treatmentIsPrimary: boolean;
  patientName: string;
  patientEmail: string;
  treatmentName: string;
  totalTratamiento: number;
  montoPagado: number;
  saldoPendiente: number;
  fechaProximoPago: admin.firestore.Timestamp | null;
};

function asTrimmedString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : String(value ?? '').trim();
}

function asNumber(value: unknown): number {
  return typeof value === 'number' ? value : Number(value ?? 0);
}

export async function loadTreatmentPaymentAccount(
  db: admin.firestore.Firestore,
  patientId: string,
  treatmentId: string,
): Promise<PaymentAccountSnapshot | null> {
  const patientRef = db.collection('patients').doc(patientId);
  const treatmentRef = patientRef.collection('treatments').doc(treatmentId);
  const paymentRef = db
    .collection('payments')
    .doc(patientId)
    .collection('treatments')
    .doc(treatmentId);

  const [patientSnap, treatmentSnap, paymentSnap] = await Promise.all([
    patientRef.get(),
    treatmentRef.get(),
    paymentRef.get(),
  ]);

  if (!patientSnap.exists || !treatmentSnap.exists || !paymentSnap.exists) {
    return null;
  }

  const patient = patientSnap.data() ?? {};
  const treatment = treatmentSnap.data() ?? {};
  const payment = paymentSnap.data() ?? {};

  return {
    patientId,
    treatmentId,
    treatmentIsPrimary: Boolean(treatment.isPrimary),
    patientName:
      asTrimmedString(patient.nombre) || asTrimmedString(patient.name) || 'Paciente',
    patientEmail:
      asTrimmedString(patient.email) ||
      asTrimmedString(patient.correo) ||
      asTrimmedString(patient.patientEmail),
    treatmentName:
      asTrimmedString(treatment.visibleName) ||
      asTrimmedString(treatment.clinicalTreatmentName) ||
      asTrimmedString(treatment.name) ||
      asTrimmedString(treatment.nombre) ||
      treatmentId,
    totalTratamiento: asNumber(payment.totalTratamiento),
    montoPagado: asNumber(payment.montoPagado),
    saldoPendiente: asNumber(payment.saldoPendiente),
    fechaProximoPago:
      payment.fechaProximoPago instanceof admin.firestore.Timestamp
        ? payment.fechaProximoPago
        : null,
  };
}

/**
 * Normaliza el estado numérico de Epayco a estado interno.
 * Epayco estados: 1=Pendiente, 2=Fallido, 3=Exitoso, 4=Rechazado
 */
export function normalizePaymentGatewayState(statePol: number): string {
  if (statePol === 3) return 'aprobado';
  if (statePol === 4) return 'rechazado';
  if (statePol === 1) return 'pendiente_confirmacion';
  return `state_${statePol}`;
}
