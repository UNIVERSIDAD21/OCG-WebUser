import * as admin from 'firebase-admin';

export type NotificationRecipientRole = 'admin' | 'patient';

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

export interface AndroidDeliveryResult {
  attempted: number;
  successCount: number;
  failureCount: number;
  invalidDeviceIds: string[];
  errors: Array<{ deviceId: string; code: string; message: string }>;
}

interface DeviceTokenRecord {
  id: string;
  token: string;
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
      invalidDeviceIds: [],
      errors: [],
    };
  }

  const messaging = admin.messaging();
  const errors: AndroidDeliveryResult['errors'] = [];
  const invalidDeviceIds: string[] = [];
  let successCount = 0;

  await Promise.all(
    devices.map(async (device) => {
      try {
        await messaging.send({
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
          data: {
            type: payload.type,
            route: payload.targetRoute ?? '',
            entityId: payload.entityId ?? '',
            entityType: payload.entityType ?? '',
            ...payload.data,
          },
        });
        successCount++;
      } catch (error) {
        const code = getMessagingErrorCode(error);
        const message = error instanceof Error ? error.message : String(error);
        errors.push({deviceId: device.id, code, message});
        if (isInvalidTokenError(code)) {
          invalidDeviceIds.push(device.id);
        }
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

  return {
    attempted: devices.length,
    successCount,
    failureCount: devices.length - successCount,
    invalidDeviceIds,
    errors,
  };
}

export async function resolveActiveAndroidTokens(
  db: FirebaseFirestore.Firestore,
  role: NotificationRecipientRole,
  uid: string,
): Promise<DeviceTokenRecord[]> {
  const snap = await db
    .collection(role === 'admin' ? 'admins' : 'patients')
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
    .filter((item) => item.token.isNotEmpty);
}

export async function deactivateDeviceToken(
  db: FirebaseFirestore.Firestore,
  role: NotificationRecipientRole,
  uid: string,
  deviceId: string,
): Promise<void> {
  await db
    .collection(role === 'admin' ? 'admins' : 'patients')
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
