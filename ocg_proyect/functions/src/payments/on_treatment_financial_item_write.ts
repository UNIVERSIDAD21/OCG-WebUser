import * as admin from 'firebase-admin';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';

export const onTreatmentFinancialItemWrite = onDocumentWritten(
  {
    region: 'us-central1',
    document: 'patients/{patientId}/treatments/{treatmentId}/financialItems/{itemId}',
  },
  async (event) => {
    const patientId = event.params.patientId;
    const treatmentId = event.params.treatmentId;
    const db = admin.firestore();

    const treatmentRef = db.doc(`patients/${patientId}/treatments/${treatmentId}`);
    const treatmentSnap = await treatmentRef.get();
    if (!treatmentSnap.exists) return;

    const treatmentData = treatmentSnap.data() ?? {};
    const isPrimary = treatmentData.isPrimary === true;

    const itemsSnap = await db.collection(`patients/${patientId}/treatments/${treatmentId}/financialItems`).get();
    const activeItems = itemsSnap.docs
      .map((doc) => doc.data())
      .filter((item) => item.active !== false);

    const total = activeItems.reduce((sum, item) => sum + Number(item.amount ?? 0), 0);
    const previousTotal = Number(treatmentData.totalTratamiento ?? 0);
    const previousPending = Number(treatmentData.saldoPendiente ?? 0);
    const paidAmount = Math.max(previousTotal - previousPending, 0);
    const pendingAmount = Math.max(total - paidAmount, 0);

    const summary = {
      currency: 'COP',
      subtotalAmount: total,
      discountAmount: 0,
      totalAmount: total,
      paidAmount,
      pendingAmount,
      itemsCount: activeItems.length,
      lastPricingUpdateAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const batch = db.batch();
    batch.set(
      treatmentRef,
      {
        totalTratamiento: total,
        saldoPendiente: pendingAmount,
        financialSummary: summary,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    if (isPrimary) {
      const paymentRef = db.doc(`payments/${patientId}`);
      const paymentSnap = await paymentRef.get();
      const nextPaymentDate = paymentSnap.data()?.fechaProximoPago ?? null;
      batch.set(
        paymentRef,
        {
          id: patientId,
          patientId,
          treatmentId,
          totalTratamiento: total,
          montoPagado: paidAmount,
          saldoPendiente: pendingAmount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: paymentSnap.data()?.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
          fechaProximoPago: nextPaymentDate,
          'financialSummary.paidAmount': paidAmount,
          'financialSummary.pendingAmount': pendingAmount,
        },
        {merge: true},
      );

      batch.set(
        db.doc(`patients/${patientId}`),
        {
          primaryTreatmentId: treatmentId,
          totalTratamiento: total,
          saldoPendiente: pendingAmount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }

    await batch.commit();
  },
);
