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

## 2026-04-29 — Validación técnica final solicitada por Jefe
### Comandos ejecutados
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build ios --debug --no-codesign` (solo si había Xcode)

### Resultado real
- En este entorno todos los comandos Flutter devolvieron `127` porque `flutter` no está disponible en PATH.
- `flutter build ios --debug --no-codesign` quedó bloqueado además por ausencia de `xcodebuild`/entorno macOS.

### Hallazgos técnicos importantes
- El commit `4a98e1b` existe y corresponde a `Preparar soporte técnico de notificaciones push para iOS`.
- La parte de proyecto dejó base Flutter/iOS/documentación, pero **no cerró validación fuerte de compilación**.
- No se tocaron Cloud Functions/backend en ese commit de iOS push.
- Por tanto, el estado no puede declararse A todavía.

### Estado honesto
- Estado B — Preparado parcialmente.

### Qué falta antes de pasar a Apple/Firebase
- Ejecutar validación real de Flutter en un entorno con SDK Flutter disponible.
- Revisar/cerrar el wiring real del módulo push en el arranque de la app.
- Revisar/cerrar backend y payloads FCM compatibles con iOS/Android.
- Verificar alineación entre storage de tokens y consultas de backend.
