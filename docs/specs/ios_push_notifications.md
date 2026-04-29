# iOS Push Notifications — OCG Flutter

## Objetivo
Dejar el soporte de notificaciones push preparado del lado del proyecto para iOS sin romper Android, de modo que al final solo queden pendientes las configuraciones externas de Apple/Firebase y la prueba en iPhone real.

## Arquitectura
Flutter App → Firebase Messaging → FCM Token Store (Firestore) → Cloud Functions → FCM/APNs → Flutter App

## Diferencia Android vs iOS
### Android
- Puede recibir notificaciones con menos fricción de permisos.
- La experiencia suele depender más de FCM y del canal de notificación.

### iOS
- Requiere autorización explícita del usuario.
- Depende de APNs y de configuración externa en Apple Developer + Firebase.
- Debe contemplar `authorized`, `denied`, `provisional`, `notDetermined`.

## Flujo completo de recepción
1. La app inicializa Firebase.
2. Se inicializa `firebase_messaging`.
3. Se solicita permiso (iOS).
4. Se obtiene token FCM.
5. Se guarda el token por usuario/plataforma.
6. Cloud Functions envía payload compatible Android/iOS.
7. La app recibe la notificación:
   - foreground
   - background
   - terminated
8. Se persiste historial local/remoto en Firestore.
9. Si el usuario toca la notificación, se reconstruye la navegación interna desde `data`.

## Flujo de tap / navegación
El payload debe contener suficientes campos para navegar sin ambigüedad:
- `data.type`
- `data.targetId`
- `data.route`
- `data.patientId`
- `data.appointmentId`
- `data.paymentId`
- `data.treatmentId`
- `data.createdAt`

Tipos contemplados:
- `appointment_created`
- `appointment_confirmed`
- `appointment_cancelled`
- `appointment_rescheduled`
- `appointment_reminder`
- `payment_registered`
- `payment_due`
- `treatment_updated`
- `general_message`

## Estructura de tokens FCM
Colección propuesta: `fcmTokens/{token}`

Campos:
- `userId`
- `role`
- `platform` (`android` / `ios` / `web`)
- `token`
- `deviceId` (si se incorpora luego)
- `active`
- `createdAt`
- `updatedAt`
- `lastSeenAt`

## Estructura de payload recomendada
```json
{
  "notification": {
    "title": "Título visible",
    "body": "Mensaje visible"
  },
  "data": {
    "type": "appointment_reminder",
    "targetId": "abc123",
    "route": "/appointments",
    "patientId": "patient_1",
    "appointmentId": "appt_1",
    "paymentId": "",
    "treatmentId": "",
    "createdAt": "2026-04-29T00:00:00Z"
  }
}
```

## Decisiones técnicas tomadas
- Se centralizó la lógica de push en `NotificationService`.
- Se preparó un provider único para bootstrap del módulo push.
- Se maneja refresh del token FCM.
- Se marca el token como inactivo en logout.
- Se persiste historial de recepción/apertura en Firestore bajo `users/{uid}/notifications`.
- Se dejó `firebaseMessagingBackgroundHandler` preparado.
- Se activó `remote-notification` en `Info.plist`.
- Se dejó `FirebaseAppDelegateProxyEnabled=true` en `Info.plist`.

## Archivos modificados / relevantes
- `lib/features/notifications/data/notification_service.dart`
- `lib/features/notifications/data/models/notification_model.dart`
- `lib/features/notifications/providers/notification_provider.dart`
- `ios/Runner/Info.plist`

## Riesgos conocidos
- Sin APNs Auth Key y Firebase iOS app, iOS no puede probar push real.
- Falta validar en dispositivo real el comportamiento foreground/background/terminated.
- La navegación final por notificación depende de conectar el `notificationNavigationIntentsProvider` al router/app shell donde corresponda.
- Si el proyecto no tiene todavía `GoogleService-Info.plist` de iOS, la parte Flutter/iOS seguirá pendiente de configuración externa.
