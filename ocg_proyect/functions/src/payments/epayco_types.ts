import * as admin from 'firebase-admin';

export type EpaycoSessionRecord = {
  patientId?: string;
  treatmentId?: string;
  monto?: number;
  estado?: string;
  checkoutUrl?: string;
  entorno?: string;
  patientEmail?: string;
  patientName?: string;
  referencia?: string;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue | null;
  updatedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue | null;
  appliedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue | null;
  errorCode?: string;
  errorDetail?: string;
  epaycoOrderId?: string;
  epaycoTransactionId?: string;
};

export type EpaycoWebhookPayload = {
  reference: string;
  customerId: string;
  value: number;
  currency: string;
  estado: string;
  statePol?: number;
  stateLabel: string;
  sign: string;
  epaycoOrderId: string;
  epaycoTransactionId: string;
};

export type EpaycoWebhookResult = {
  ok: true;
  action:
    | 'ignored_invalid_signature'
    | 'ignored_missing_session'
    | 'ignored_terminal_approved'
    | 'approved_applied'
    | 'approved_already_applied'
    | 'non_approved_recorded'
    | 'error_recorded';
  sessionState?: string;
  transactionId?: string;
  appliedAmount?: number;
};
