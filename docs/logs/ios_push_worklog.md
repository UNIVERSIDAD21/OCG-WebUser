# iOS Push Worklog

## 2026-04-29
### Qué revisé
- Estado actual del módulo de notificaciones Flutter.
- Base de Firebase Messaging / recepción.
- Proyecto iOS (`Info.plist`, `AppDelegate.swift`, Podfile, archivos del runner).
- Presencia de handlers foreground/background/terminated.
- Estado general de Cloud Functions y payloads relacionados.

### Qué cambié
- Se reescribió la capa base de notificaciones en Flutter con un servicio central.
- Se añadieron modelos de permiso, tipos de mensaje, intentos de navegación y registro de token.
- Se añadió provider de bootstrap del módulo push.
- Se preparó `firebaseMessagingBackgroundHandler`.
- Se dejó `Info.plist` preparado con `FirebaseAppDelegateProxyEnabled=true` y `UIBackgroundModes` incluyendo `remote-notification`.

### Archivos tocados
- `lib/features/notifications/data/models/notification_model.dart`
- `lib/features/notifications/data/notification_service.dart`
- `lib/features/notifications/providers/notification_provider.dart`
- `ios/Runner/Info.plist`
- `docs/specs/ios_push_notifications.md`
- `docs/checklists/ios_push_setup_checklist.md`
- `docs/logs/ios_push_worklog.md`
- `docs/testing/ios_push_test_plan.md`

### Decisiones tomadas
- No esperar llaves de Apple para avanzar el trabajo del proyecto.
- Dejar la persistencia del token en `fcmTokens/{token}`.
- Guardar historial de recepción/apertura en `users/{uid}/notifications`.
- Mantener Android operativo y no tocar secretos.
- Dejar documentado lo que queda 100% externo a Apple/Firebase.

### Qué quedó listo
- Capa Flutter base para token, permisos y recepción.
- Preparación iOS del lado proyecto hasta donde no exige Apple Developer.
- Documentación técnica, checklist y plan de pruebas.

### Qué quedó pendiente de Erik
- Apple Developer Account.
- Bundle ID definitivo.
- Team ID.
- APNs Key ID.
- APNs `.p8`.
- Registro app iOS en Firebase.
- `GoogleService-Info.plist` si falta.
- iPhone real.
- Validación final de payloads end-to-end con backend activo.

### Qué no se pudo probar todavía y por qué
- Push real en iOS: depende de APNs/Firebase iOS externos.
- Permisos reales en iPhone: requiere dispositivo físico.
- Navegación real desde tap: requiere notificación real entrante.
