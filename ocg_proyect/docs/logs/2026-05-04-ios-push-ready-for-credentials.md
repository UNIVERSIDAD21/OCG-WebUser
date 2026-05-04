# iOS Push ready for credentials

Fecha: 2026-05-04

## Archivos auditados

### Flutter
- `lib/services/notifications/fcm_service.dart`
- `lib/services/notifications/fcm_payload_router.dart`
- `lib/services/notifications/notification_navigation_service.dart`
- `lib/features/auth/providers/auth_providers.dart`
- `lib/services/firebase/auth_service.dart`
- `lib/features/notifications/providers/notifications_provider.dart`
- `lib/features/dashboard/presentation/admin_notifications_screen.dart`
- `lib/features/notifications/presentation/patient_notifications_screen.dart`

### Functions
- `functions/src/auth/set_fcm_token.ts`
- `functions/src/notifications/fcm_delivery.ts`
- `functions/src/notifications/android_notification_service.ts`
- `functions/src/notifications/domain_notifications.ts`
- `functions/src/notifications/send_android_notification.ts`
- `functions/src/notifications/notification_history.ts`
- `functions/src/appointments/reminder_scheduler.ts`
- `functions/src/payments/payment_due_scheduler.ts`
- `functions/src/appointments/appointment_patient_notifications.ts`

### iOS
- `ios/Runner/Info.plist`
- `ios/Runner/AppDelegate.swift`

## Qué ya estaba listo

- Registro/limpieza de token en login/logout.
- Fallback directo a Firestore si el callable falla.
- Routing de payload y navegación local ya existentes.
- `Info.plist` ya incluye `UIBackgroundModes -> remote-notification`.
- Historial persistido en colección `notifications`.

## Qué estaba Android-only

- Flutter registraba `platform: 'android'` fijo.
- Local notifications se inicializaban solo con `AndroidInitializationSettings`.
- Foreground notification usaba solo `AndroidNotificationDetails`.
- Backend resolvía tokens activos filtrando `platform == 'android'`.
- La entrega se hacía vía `sendAndroidFcmNotification` / `deliverAndroidNotification`.
- El payload FCM no construía `apns` para iOS.

## Cambios hechos

### Flutter
- Se creó helper testeable `resolveFcmPlatform()`.
- `FcmService` ya no registra Android fijo; ahora sube `android`, `ios`, `macos` o ignora `web`/plataformas no soportadas.
- Se añadió inicialización `DarwinInitializationSettings`.
- Se añadieron permisos/presentación foreground para iOS/macOS:
  - alert
  - badge
  - sound
- Se añadieron `DarwinNotificationDetails` al mostrar notificaciones locales.
- Se extrajo helper `syncResolvedDeviceToken()` para pruebas sin Firebase real.

### Functions
- Se generalizó la resolución a `resolveActiveDeviceTokens()`.
- Ahora resuelve tokens Android e iOS y deduplica por token.
- Se mantiene compatibilidad con token legacy top-level (`fcmToken`).
- Se generalizó la entrega con `sendFcmNotification()`.
- `sendAndroidFcmNotification()` queda como wrapper compatible.
- El payload construye:
  - bloque `android` para Android con `channelId`
  - bloque `apns` para iOS con `aps.sound = default`
- La invalidación de tokens inválidos funciona igual para Android e iOS.

## Pruebas agregadas

### Flutter
- `test/services/notifications/fcm_service_test.dart`
- `test/services/notifications/fcm_payload_router_test.dart`

### Functions
- `functions/test/fcm_delivery.test.mjs`

## Comandos ejecutados

- `flutter analyze`
- `flutter test test/services/notifications/`
- `cd functions && npm run build`
- `cd functions && node --test test/fcm_delivery.test.mjs`

## Pendiente humano

- Apple Developer
- APNs Auth Key
- configurar APNs en Firebase
- validar `GoogleService-Info.plist`
- probar iPhone real en foreground/background/terminated
- validar tap navigation real

## Alcance

No se configuraron credenciales Apple, no se tocó Firebase real y no se desplegó nada.
