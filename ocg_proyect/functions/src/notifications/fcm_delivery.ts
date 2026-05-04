import * as admin from 'firebase-admin';
import {logger} from 'firebase-functions';

export type NotificationRecipientRole = 'admin' | 'patient';
export type DevicePlatform = 'android' | 'ios' | 'web' | 'macos' | 'unknown';
export type NotificationDeliveryStatus =
  | 'sent'
  | 'partial'
  | 'failed'
  | 'skipped_no_active_tokens';

export interface NotificationPayload {
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

export interface DeviceTokenRecord {
  id: string;
  token: string;
  source: 'devices' | 'legacy_top_level';
  active: boolean;
  platform: DevicePlatform;
}

export interface DeliveryError {
  deviceId: string;
  token: string;
  code: string;
  message: string;
}

export interface DeliveryResult {
  attempted: number;
  successCount: number;
  failureCount: number;
  status: NotificationDeliveryStatus;
  invalidDeviceIds: string[];
  errors: DeliveryError[];
  providerMessageIds: string[];
}

export type AndroidNotificationPayload = NotificationPayload;
export type AndroidDeviceTokenRecord = DeviceTokenRecord;
export type AndroidDeliveryError = DeliveryError;
export type AndroidDeliveryResult = DeliveryResult;

function userCollection(role: NotificationRecipientRole): string {
  return role === 'admin' ? 'admins' : 'patients';
}

function tokenPreview(token: string): string {
  if (token.length <= 18) return token;
  return `${token.slice(0, 10)}…${token.slice(-6)}`;
}

function sanitizeData(data?: Record<string, string>): Record<string, string> {
  if (!data) return {};
  return Object.fromEntries(
    Object.entries(data)
      .map(([key, value]) => [key.trim(), String(value ?? '')])
      .filter(([key]) => key.length > 0),
  );
}

function normalizePlatform(value: unknown): DevicePlatform {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (normalized === 'android' || normalized === 'ios' || normalized === 'web' || normalized === 'macos') {
    return normalized;
  }
  return 'unknown';
}

function buildDataPayload(payload: NotificationPayload): Record<string, string> {
  return {
    type: payload.type,
    route: payload.targetRoute ?? '',
    entityId: payload.entityId ?? '',
    entityType: payload.entityType ?? '',
    recipientId: payload.recipientId,
    recipientRole: payload.recipientRole,
    title: payload.title,
    body: payload.body,
    ...sanitizeData(payload.data),
  };
}

export async function resolveActiveDeviceTokens(
  db: FirebaseFirestore.Firestore,
  role: NotificationRecipientRole,
  uid: string,
  platforms?: DevicePlatform[],
): Promise<DeviceTokenRecord[]> {
  const userRef = db.collection(userCollection(role)).doc(uid);
  const [userSnap, devicesSnap] = await Promise.all([
    userRef.get(),
    userRef.collection('devices').where('active', '==', true).get(),
  ]);

  const allowedPlatforms = platforms == null || platforms.length === 0
    ? null
    : new Set(platforms.map((platform) => normalizePlatform(platform)));

  const deduped = new Map<string, DeviceTokenRecord>();
  for (const doc of devicesSnap.docs) {
    const data = doc.data() ?? {};
    const token = String(data.token ?? '').trim();
    if (!token) continue;
    const platform = normalizePlatform(data.platform);
    if (allowedPlatforms && !allowedPlatforms.has(platform)) continue;
    deduped.set(token, {
      id: doc.id,
      token,
      source: 'devices',
      active: true,
      platform,
    });
  }

  const userData = userSnap.data() ?? {};
  const legacyToken = String(userData.fcmToken ?? '').trim();
  const legacyDeviceId = String(userData.fcmDeviceId ?? '').trim() || 'legacy_top_level';
  const legacyPlatform = normalizePlatform(userData.fcmPlatform);
  if (
    legacyToken &&
    !deduped.has(legacyToken) &&
    (!allowedPlatforms || allowedPlatforms.has(legacyPlatform) || legacyPlatform === 'unknown')
  ) {
    deduped.set(legacyToken, {
      id: legacyDeviceId,
      token: legacyToken,
      source: 'legacy_top_level',
      active: true,
      platform: legacyPlatform,
    });
  }

  return [...deduped.values()];
}

export async function resolveActiveAndroidTokens(
  db: FirebaseFirestore.Firestore,
  role: NotificationRecipientRole,
  uid: string,
): Promise<AndroidDeviceTokenRecord[]> {
  return resolveActiveDeviceTokens(db, role, uid, ['android']);
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
  if (typeof error === 'object' && error !== null && 'code' in error && typeof (error as {code?: unknown}).code === 'string') {
    return (error as {code: string}).code;
  }
  return 'unknown';
}

function isInvalidTokenError(code: string): boolean {
  return code.includes('registration-token-not-registered') ||
    code.includes('invalid-registration-token');
}

function resolveDeliveryStatus(attempted: number, successCount: number): NotificationDeliveryStatus {
  if (attempted === 0) return 'skipped_no_active_tokens';
  if (successCount === attempted) return 'sent';
  if (successCount === 0) return 'failed';
  return 'partial';
}

export function buildFcmMessageForDevice(
  payload: NotificationPayload,
  device: DeviceTokenRecord,
): admin.messaging.Message {
  const data = buildDataPayload(payload);
  const base: admin.messaging.Message = {
    token: device.token,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data,
  };

  if (device.platform === 'ios') {
    return {
      ...base,
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };
  }

  return {
    ...base,
    android: {
      priority: 'high',
      notification: {
        channelId: 'ocg_clinica_push',
      },
    },
  };
}

export async function sendFcmNotification(
  db: FirebaseFirestore.Firestore,
  payload: NotificationPayload,
  messagingOverride?: {send(message: admin.messaging.Message): Promise<string>},
): Promise<DeliveryResult> {
  const devices = await resolveActiveDeviceTokens(db, payload.recipientRole, payload.recipientId, ['android', 'ios']);

  logger.info('Resolved notification tokens', {
    recipientId: payload.recipientId,
    recipientRole: payload.recipientRole,
    type: payload.type,
    tokensFound: devices.length,
    deviceIds: devices.map((device) => device.id),
    tokenSources: devices.map((device) => ({
      deviceId: device.id,
      source: device.source,
      platform: device.platform,
      tokenPreview: tokenPreview(device.token),
    })),
  });

  if (devices.length === 0) {
    logger.warn('Skipping notification: no active tokens', {
      recipientId: payload.recipientId,
      recipientRole: payload.recipientRole,
      type: payload.type,
    });
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

  const messaging = messagingOverride ?? admin.messaging();
  const errors: DeliveryError[] = [];
  const invalidDeviceIds: string[] = [];
  const providerMessageIds: string[] = [];

  const responses = await Promise.all(
    devices.map(async (device) => {
      try {
        const providerMessageId = await messaging.send(buildFcmMessageForDevice(payload, device));
        providerMessageIds.push(providerMessageId);
        return {ok: true as const};
      } catch (error) {
        const code = getMessagingErrorCode(error);
        const message = error instanceof Error ? error.message : String(error);
        errors.push({deviceId: device.id, token: device.token, code, message});
        if (isInvalidTokenError(code)) invalidDeviceIds.push(device.id);
        return {ok: false as const};
      }
    }),
  );

  if (invalidDeviceIds.length > 0) {
    await Promise.all(
      invalidDeviceIds.map((deviceId) => deactivateDeviceToken(db, payload.recipientRole, payload.recipientId, deviceId)),
    );
  }

  const successCount = responses.filter((item) => item.ok).length;
  const failureCount = responses.length - successCount;
  const status = resolveDeliveryStatus(devices.length, successCount);

  logger.info('FCM delivery result', {
    recipientId: payload.recipientId,
    recipientRole: payload.recipientRole,
    type: payload.type,
    attempted: devices.length,
    successCount,
    failureCount,
    status,
    invalidDeviceIds,
    providerMessageIds,
    errors,
  });

  return {
    attempted: devices.length,
    successCount,
    failureCount,
    status,
    invalidDeviceIds,
    errors,
    providerMessageIds,
  };
}

export async function sendAndroidFcmNotification(
  db: FirebaseFirestore.Firestore,
  payload: AndroidNotificationPayload,
): Promise<AndroidDeliveryResult> {
  return sendFcmNotification(db, payload);
}
