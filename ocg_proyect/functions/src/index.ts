import * as admin from 'firebase-admin';

import {onAuthUserCreate} from './auth/on_auth_user_create';
import {addAdminRole, removeAdminRole} from './auth/admin_role_management';
import {setAdminRole} from './auth/set_admin_role';
import {deleteFcmToken, setFcmToken} from './auth/set_fcm_token';
import {createPatientAccount} from './auth/create_patient_account';
import {registerPatientSelf} from './auth/register_patient_self';
import {deletePatientAccount} from './auth/delete_patient_account';
import {reserveAppointment} from './appointments/reserve_appointment';
import {onAppointmentWrite} from './appointments/on_appointment_write';
import {seedAvailability} from './appointments/seed_availability';
import {reconcileNoShowAppointments} from './appointments/reconcile_no_show_appointments';
import {processScheduledNotifications} from './appointments/reminder_scheduler';
import {createPayuSession} from './payments/create_payu_session';
import {payuWebhook} from './payments/payu_webhook';
import {reconcilePatientBalances} from './payments/reconcile_balances';
import {initializeAllPaymentDocuments} from './payments/initialize_all_payment_documents';
import {onTreatmentFinancialItemWrite} from './payments/on_treatment_financial_item_write';

if (!admin.apps.length) {
  admin.initializeApp();
}

export {
  onAuthUserCreate,
  setAdminRole,
  addAdminRole,
  removeAdminRole,
  setFcmToken,
  deleteFcmToken,
  createPatientAccount,
  registerPatientSelf,
  deletePatientAccount,
  reserveAppointment,
  onAppointmentWrite,
  seedAvailability,
  reconcileNoShowAppointments,
  processScheduledNotifications,
  createPayuSession,
  payuWebhook,
  reconcilePatientBalances,
  initializeAllPaymentDocuments,
  onTreatmentFinancialItemWrite,
};
