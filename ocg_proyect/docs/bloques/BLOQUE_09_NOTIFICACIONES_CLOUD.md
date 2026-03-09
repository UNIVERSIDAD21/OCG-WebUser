# BLOQUE_09 — Notificaciones FCM + Cloud Functions

> **Stack:** Flutter + Firebase Cloud Messaging + Cloud Functions (TypeScript)
> **Prioridad:** MEDIA-ALTA — Operación real depende de recordatorios automáticos
> **Depende de:** Bloque 05 (citas) ✅, Bloque 06 (tratamiento) ✅, Bloque 07 (pagos) ✅

---

## Objetivo del bloque

Completar el sistema de notificaciones push: pantalla de historial de notificaciones, manejo de tap en notificación (deep link), y despliegue de las Cloud Functions que envían recordatorios automáticos de citas (24h y 2h antes) y notificaciones por cambio de etapa.

---

## Lo que debes entregar al cerrar este bloque

- [ ] `NotificationsScreen` para el paciente (historial de notificaciones)
- [ ] Manejo de tap en notificación → deep link a la pantalla correcta
- [ ] `NotificationModel` + `NotificationRepository` + `notifications_provider`
- [ ] `NotificationBadge` en la AppBar del paciente
- [ ] Cloud Function: `scheduledAppointmentReminders` (recordatorios 24h y 2h)
- [ ] Cloud Function: `onStageChanged` (trigger Firestore al cambiar etapa)
- [ ] Cloud Function: `onPaymentDue` (recordatorio próximo pago)
- [ ] Índices Firestore necesarios (`firestore.indexes.json`)
- [ ] `flutter analyze` ✅ y `flutter test` ✅

---

## Estado actual del FCM en el proyecto

Ya implementado en `main.dart`:
- `Firebase.initializeApp()`
- `FirebaseMessaging.instance.requestPermission()`
- `FirebaseMessaging.onBackgroundMessage(_bgMessageHandler)`

**Lo que falta:**
- Manejar el tap cuando la app está en foreground
- Manejar el tap cuando la app está en background (notification tap → deep link)
- La pantalla de historial de notificaciones
- Las Cloud Functions que realmente envían las notificaciones

---

## Archivos a crear

### 1. `lib/features/notifications/data/models/notification_model.dart`

```dart
class NotificationModel {
  final String id;
  final String recipientId;      // uid del paciente
  final String titulo;
  final String cuerpo;
  final NotificationType tipo;   // Enum tipado
  final bool leida;
  final Map<String, dynamic>? data;  // Payload adicional (appointmentId, etc.)
  final DateTime createdAt;
}

enum NotificationType {
  recordatorioCita24h,
  recordatorioCita2h,
  citaConfirmada,
  citaCancelada,
  citaReprogramada,
  cambioEtapa,
  pagoRegistrado,
  pagoProximo,
  general,
}
```

---

### 2. `lib/features/notifications/data/repositories/notification_repository.dart`

```dart
class NotificationRepository {
  // Stream de notificaciones del usuario autenticado — ordenadas por fecha desc
  Stream<List<NotificationModel>> watchNotifications(String userId);
  
  // Marcar como leída
  Future<void> markAsRead(String notificationId);
  
  // Marcar todas como leídas
  Future<void> markAllAsRead(String userId);
  
  // Contar no leídas (para el badge)
  Stream<int> watchUnreadCount(String userId);
}
```

---

### 3. `lib/features/notifications/providers/notifications_provider.dart`

```dart
final notificationRepositoryProvider = Provider<NotificationRepository>(...);

final notificationsProvider = StreamProvider.family<List<NotificationModel>, String>(
  (ref, userId) => ref.watch(notificationRepositoryProvider).watchNotifications(userId),
);

final unreadCountProvider = StreamProvider.family<int, String>(
  (ref, userId) => ref.watch(notificationRepositoryProvider).watchUnreadCount(userId),
);
```

---

### 4. `lib/features/notifications/presentation/notifications_screen.dart`

Pantalla de historial de notificaciones para el paciente:

```
AppBar: "Notificaciones" + botón "Marcar todas como leídas"

Lista de notificaciones:
  Cada ítem:
    - Ícono según tipo (cita → calendar, etapa → timeline, pago → payment)
    - Título en bold si no leída, normal si leída
    - Cuerpo (2 líneas máx, expandible)
    - Fecha relativa ("Hace 2 horas", "Ayer")
    - Fondo: ligeramente diferente si no leída (OcgColors.mist) vs leída (blanco)
    - Tap → marcar como leída + navegar a la sección correspondiente

Si vacía: OcgEmptyState con "No tienes notificaciones aún."
```

---

### 5. `lib/features/notifications/presentation/widgets/notification_badge.dart`

Badge rojo con número en la AppBar del paciente:

```dart
class NotificationBadge extends ConsumerWidget {
  // Muestra el ícono de campana + Badge rojo con el conteo si > 0
  // Al tocar: navega a NotificationsScreen
  // Si count > 99: muestra "99+"
}
```

Agregar `NotificationBadge` en la AppBar de `PatientHomeScreen`.

---

### 6. `lib/services/notifications/fcm_service.dart` — Completar

```dart
class FcmService {
  // Ya parcialmente setup en main.dart
  // Completar:
  
  // Inicializar listeners de FCM
  void initialize(BuildContext context, GoRouter router) {
    // Foreground: mostrar SnackBar o Banner con la notificación
    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundNotification(context, message);
    });
    
    // Background tap: redirigir según tipo
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message, router);
    });
    
    // Terminated → opened: verificar getInitialMessage
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationTap(message, router);
    });
  }
  
  void _handleNotificationTap(RemoteMessage message, GoRouter router) {
    final type = message.data['type'];
    switch (type) {
      case 'appointment':
      case 'appointment_cancelled':
        router.push(RouteNames.patientAppointments);
      case 'treatment_stage':
        router.push(RouteNames.patientHome); // Muestra el timeline
      case 'payment_due':
      case 'payment_received':
        router.push(RouteNames.patientPayments);
      default:
        router.push(RouteNames.patientNotifications);
    }
  }
}
```

Llamar a `FcmService().initialize(context, router)` en `OcgApp` o en el `PatientHomeScreen`.

---

## Cloud Functions a implementar

### Función 1: `scheduledAppointmentReminders`

```typescript
// Ejecutar cada hora — Colombia timezone
export const scheduledAppointmentReminders = functions
  .pubsub.schedule('every 60 minutes')
  .timeZone('America/Bogota')
  .onRun(async () => {
    const now = new Date();
    
    // — Recordatorio 24h —
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in23h = new Date(now.getTime() + 23 * 60 * 60 * 1000);
    
    const citas24h = await admin.firestore()
      .collection('appointments')
      .where('fechaHora', '>=', Timestamp.fromDate(in23h))
      .where('fechaHora', '<=', Timestamp.fromDate(in24h))
      .where('estado', 'in', ['programada', 'confirmada'])
      .where('recordatorio24hEnviado', '==', false)
      .get();
    
    for (const doc of citas24h.docs) {
      await sendAppointmentReminder(doc, '24h');
      await doc.ref.update({ recordatorio24hEnviado: true });
    }
    
    // — Recordatorio 2h —
    const in2h = new Date(now.getTime() + 2 * 60 * 60 * 1000);
    const in1h = new Date(now.getTime() + 1 * 60 * 60 * 1000);
    
    const citas2h = await admin.firestore()
      .collection('appointments')
      .where('fechaHora', '>=', Timestamp.fromDate(in1h))
      .where('fechaHora', '<=', Timestamp.fromDate(in2h))
      .where('estado', 'in', ['programada', 'confirmada'])
      .where('recordatorio2hEnviado', '==', false)
      .get();
    
    for (const doc of citas2h.docs) {
      await sendAppointmentReminder(doc, '2h');
      await doc.ref.update({ recordatorio2hEnviado: true });
    }
  });

async function sendAppointmentReminder(doc: any, type: '24h' | '2h') {
  const appt = doc.data();
  const patient = await admin.firestore().collection('patients').doc(appt.patientId).get();
  const fcmToken = patient.data()?.fcmToken;
  if (!fcmToken) return;
  
  const timeLabel = type === '24h' ? 'mañana' : 'en 2 horas';
  const hora = formatTime(appt.fechaHora.toDate()); // HH:mm
  
  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: 'Recordatorio de cita — OCG Clínica',
      body: `Tienes una cita ${timeLabel} a las ${hora}`,
    },
    data: {
      type: 'appointment',
      appointmentId: doc.id,
    },
  });
  
  // Guardar en notifications/
  await admin.firestore().collection('notifications').add({
    recipientId: appt.patientId,
    titulo: 'Recordatorio de cita',
    cuerpo: `Cita ${timeLabel} a las ${hora}`,
    tipo: type === '24h' ? 'recordatorioCita24h' : 'recordatorioCita2h',
    leida: false,
    data: { appointmentId: doc.id },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function formatTime(date: Date): string {
  return date.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', hour12: false });
}
```

---

### Función 2: `onPatientStageChanged` (trigger Firestore)

```typescript
export const onPatientStageChanged = functions.firestore
  .document('patients/{patientId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Solo actuar si cambió la etapa
    if (before.etapaActual === after.etapaActual) return;
    
    const patientId = context.params.patientId;
    const fcmToken = after.fcmToken;
    if (!fcmToken) return;
    
    const etapaLabel: Record<string, string> = {
      diagnostico: 'Diagnóstico',
      planificacion: 'Planificación',
      instalacion: 'Instalación',
      seguimientoActivo: 'Seguimiento activo',
      ajusteFinal: 'Ajuste final',
      retencion: 'Retención',
      alta: '¡Alta! 🎉',
    };
    
    const nuevaEtapa = etapaLabel[after.etapaActual] ?? after.etapaActual;
    
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: 'Tu tratamiento avanzó — OCG Clínica',
        body: `Nueva etapa: ${nuevaEtapa}`,
      },
      data: {
        type: 'treatment_stage',
        etapa: after.etapaActual,
      },
    });
    
    await admin.firestore().collection('notifications').add({
      recipientId: patientId,
      titulo: 'Tu tratamiento avanzó',
      cuerpo: `Nueva etapa: ${nuevaEtapa}`,
      tipo: 'cambioEtapa',
      leida: false,
      data: { etapa: after.etapaActual },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
```

---

### Función 3: `scheduledPaymentReminders`

```typescript
// Ejecutar diario a las 9am Colombia
export const scheduledPaymentReminders = functions
  .pubsub.schedule('0 9 * * *')
  .timeZone('America/Bogota')
  .onRun(async () => {
    const now = new Date();
    const in7days = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    
    // Pacientes con próximo pago en los próximos 7 días
    const payments = await admin.firestore()
      .collection('payments')
      .where('fechaProximoPago', '>=', Timestamp.fromDate(now))
      .where('fechaProximoPago', '<=', Timestamp.fromDate(in7days))
      .where('estado', '!=', 'pagadoTotal')
      .get();
    
    for (const doc of payments.docs) {
      const payment = doc.data();
      const patient = await admin.firestore().collection('patients').doc(doc.id).get();
      const fcmToken = patient.data()?.fcmToken;
      if (!fcmToken) continue;
      
      const fechaStr = formatDate(payment.fechaProximoPago.toDate());
      
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'Recordatorio de pago — OCG Clínica',
          body: `Tu próximo pago vence el ${fechaStr}. Saldo: $${payment.saldoPendiente.toLocaleString('es-CO')}`,
        },
        data: { type: 'payment_due' },
      });
    }
  });
```

---

## Índices Firestore requeridos — `firestore.indexes.json`

```json
{
  "indexes": [
    {
      "collectionGroup": "appointments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "fechaHora", "order": "ASCENDING" },
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "recordatorio24hEnviado", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "appointments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "fechaHora", "order": "ASCENDING" },
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "recordatorio2hEnviado", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "appointments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "patientId", "order": "ASCENDING" },
        { "fieldPath": "fechaHora", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "payments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "fechaProximoPago", "order": "ASCENDING" },
        { "fieldPath": "estado", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "recipientId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## Ruta nueva a agregar en `route_names.dart`

```dart
static const String patientNotifications = '/patient/notifications';
```

Y en `app_router.dart`:
```dart
GoRoute(
  path: RouteNames.patientNotifications,
  builder: (context, state) => const NotificationsScreen(),
),
```

---

## Configuración iOS (recordatorio)

Para FCM en iOS: el archivo `.p8` de APNs debe estar subido en Firebase Console → Proyecto → Cloud Messaging → Configuración de la app iOS. Sin esto las notificaciones en iOS no funcionarán.

---

## Criterios de cierre del bloque

- [ ] `NotificationsScreen` muestra el historial real del paciente
- [ ] El badge de notificaciones en la AppBar muestra el conteo correcto
- [ ] Tap en notificación navega a la sección correcta (deep link)
- [ ] Cloud Function `scheduledAppointmentReminders` desplegada y probada
- [ ] Cloud Function `onPatientStageChanged` desplegada y probada
- [ ] Cloud Function `scheduledPaymentReminders` desplegada y probada
- [ ] `firestore.indexes.json` con todos los índices compuestos
- [ ] Notificaciones funcionando en Android físico
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅

---

## Orden recomendado de ejecución

1. `NotificationModel` + serialización + tests
2. `NotificationRepository` + `notifications_provider`
3. `NotificationsScreen`
4. `NotificationBadge` + integrar en AppBar del paciente
5. `FcmService` completo con deep links
6. Cloud Function `scheduledAppointmentReminders`
7. Cloud Function `onPatientStageChanged`
8. Cloud Function `scheduledPaymentReminders`
9. `firestore.indexes.json`
10. Ruta nueva + tests + analyze
