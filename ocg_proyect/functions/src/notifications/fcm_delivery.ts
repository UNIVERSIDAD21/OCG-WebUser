import * as admin from 'firebase-admin';

export type NotificationRecipientRole = 'admin' | 'patient';
export type NotificationDeliveryStatus =
  | 'sent'
  | 'partial'
  | 'failed'
  | 'skipped_no_active_tokens';

export interface AndroidNotificationPayload {
  recipientId: string;
  recipientRole: NotificationRecipientRole;
  title: string;
  body: string;
  type: string;
  targetRoute?: string;
  entityId?: string;
  entityType?: string;
  data?: Record<string, string>;
}

export interface AndroidDeviceTokenRecord {
  id: string;
  token: string;
}

export interface AndroidDeliveryError {
  deviceId: string;
  token: string;
  code: string;
  message: string;
}

export interface AndroidDeliveryResult {
  attempted: number;
  successCount: number;
  failureCount: number;
  status: NotificationDeliveryStatus;
  invalidDeviceIds: string[];
  errors: AndroidDeliveryError[];
  providerMessageIds: string[];
}

function userCollection(role: NotificationRecipientRole): string {
  return role === 'admin' ? 'admins' : 'patients';
}

function sanitizeData(data?: Record<string, string>): Record<string, string> {
  if (!data) return {};

  return Object.fromEntries(
    Object.entries(data)
      .map(([key, value]) => [key.trim(), String(value ?? '')])
      .filter(([key]) => key.length > 0),
  );
}

function buildAndroidDataPayload(payload: AndroidNotificationPayload): Record<string, string> {
  return {
    type: payload.type,
    route: payload.targetRoute ?? '',
    entityId: payload.entityId ?? '',
    entityType: payload.entityType ?? '',
    recipientId: payload.recipientId,
    recipientRole: payload.recipientRole,
    ...sanitizeData(payload.data),
  };
}

export async function resolveActiveAndroidTokens(
  db: FirebaseFirestore.Firestore,
  role: NotificationRecipientRole,
  uid: string,
): Promise<AndroidDeviceTokenRecord[]> {
  const snap = await db
    .collection(userCollection(role))
    .doc(uid)
    .collection('devices')
    .where('active', '==', true)
    .where('platform', '==', 'android')
    .get();

  return snap.docs
    .map((doc) => ({
      id: doc.id,
      token: String(doc.data().token ?? '').trim(),
    }))
    .filter((item) => item.token.length > 0);
}

export async function deactivateDeviceToken(
  db: FirebaseFirestore.Firestore,
  role: NotificationRecipientRole,
  uid: string,
  deviceId: string,
): Promise<void> {
  await db
    .collection(userCollection(role))
    .doc(uid)
    .collection('devices')
    .doc(deviceId)
    .set(
      {
        active: false,
        invalidatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
}

function getMessagingErrorCode(error: unknown): string {
  if (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    typeof (error as {code?: unknown}).code === 'string'
  ) {
    return (error as {code: string}).code;
  }
  return 'unknown';
}

function isInvalidTokenError(code: string): boolean {
  return code.includes('registration-token-not-registered') ||
    code.includes('invalid-registration-token');
}

function resolveDeliveryStatus(
  attempted: number,
  successCount: number,
): NotificationDeliveryStatus {
  if (attempted === 0) return 'skipped_no_active_tokens';
  if (successCount === attempted) return 'sent';
  if (successCount === 0) return 'failed';
  return 'partial';
}

export async function sendAndroidFcmNotification(
  db: FirebaseFirestore.Firestore,
  payload: AndroidNotificationPayload,
): Promise<AndroidDeliveryResult> {
  const devices = await resolveActiveAndroidTokens(
    db,
    payload.recipientRole,
    payload.recipientId,
  );

  if (devices.length === 0) {
    return {
      attempted: 0,
      successCount: 0,
      failureCount: 0,
      status: 'skipped_no_active_tokens',
      invalidDeviceIds: [],
      errors: [],
      providerMessageIds: [],
    };
  }

  const messaging = admin.messaging();
  const errors: AndroidDeliveryError[] = [];
  const invalidDeviceIds: string[] = [];
  const providerMessageIds: string[] = [];

  const responses = await Promise.all(
    devices.map(async (device) => {
      try {
        const providerMessageId = await messaging.send({
          token: device.token,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'ocg_clinica_push',
            },
          },
          data: buildAndroidDataPayload(payload),
        });

        providerMessageIds.push(providerMessageId);
        return {ok: true as const};
      } catch (error) {
        const code = getMessagingErrorCode(error);
        const message = error instanceof Error ? error.message : String(error);
        errors.push({deviceId: device.id, token: device.token, code, message});
        if (isInvalidTokenError(code)) {
          invalidDeviceIds.push(device.id);
        }
        return {ok: false as const};
      }
    }),
  );

  if (invalidDeviceIds.length > 0) {
    await Promise.all(
      invalidDeviceIds.map((deviceId) =>
        deactivateDeviceToken(db, payload.recipientRole, payload.recipientId, deviceId),
      ),
    );
  }

  const successCount = responses.filter((item) => item.ok).length;
  const failureCount = responses.length - successCount;

  return {
    attempted: devices.length,
    successCount,
    failureCount,
    status: resolveDeliveryStatus(devices.length, successCount),
    invalidDeviceIds,
    errors,
    providerMessageIds,
  };
}
