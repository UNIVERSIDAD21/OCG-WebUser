# 09 — Notificaciones Push (FCM)

> **Tu objetivo:** sistema de notificaciones push que funciona en Android e iOS para recordatorios de citas, actualizaciones de etapa, avisos de pago y el resumen diario del admin.

---

## Lo que debes entregar al terminar este bloque

- [ ] fcm_service.dart configurado correctamente en Flutter
- [ ] Permisos de notificación solicitados en el primer inicio
- [ ] Manejo de notificaciones en foreground, background y terminated
- [ ] Tap en notificación navega a la pantalla correcta
- [ ] Cloud Functions para cada tipo de notificación automática
- [ ] NotificationsScreen con el historial de notificaciones del usuario
- [ ] Configuración APNs para iOS (requiere Apple Developer Account)

---

## Tipos de notificaciones y sus triggers

| Tipo | Destinatario | Cuándo | Cloud Function trigger |
|---|---|---|---|
| Recordatorio 24h antes | Paciente | 24h antes de la cita | Cron scheduler |
| Recordatorio 2h antes | Paciente | 2h antes de la cita | Cron scheduler |
| Nueva cita agendada | Paciente | Al crear la cita | Firestore onCreate |
| Cita cancelada | Paciente | Al cancelar la cita | Firestore onUpdate |
| Cita reprogramada | Paciente | Al reprogramar | Lógica en reschedule |
| Etapa actualizada | Paciente | Al cambiar la etapa | Firestore onUpdate |
| Pago próximo a vencer | Paciente | 3 días antes | Cron scheduler |
| Pago recibido | Paciente | Al confirmar pago | Firestore onCreate (transaction) |
| Resumen diario | Admin | Cada mañana 7am | Cron scheduler |

---

## fcm_service.dart

```dart
// lib/services/notifications/fcm_service.dart
class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Configurar notificaciones locales (para foreground)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Manejar mensajes en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
      // También actualizar el badge/contador en NotificationsScreen
    });

    // Manejar tap en notificación cuando la app estaba en background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message.data);
    });

    // Manejar tap cuando la app estaba completamente cerrada
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // El payload de cada notificación incluye el tipo y el ID relevante
    // ej: { "type": "appointment", "appointmentId": "abc123" }
    // ej: { "type": "treatment_stage", "patientId": "xyz789" }
    // Usa GoRouter para navegar a la pantalla correcta
    final type = data['type'] as String?;
    final router = GetIt.instance<GoRouter>(); // O usa ref.read si tienes acceso a Riverpod

    switch (type) {
      case 'appointment':
      case 'appointment_cancelled':
      case 'appointment_rescheduled':
        router.push('/patient/appointments');
      case 'treatment_stage':
        router.push('/patient/treatment');
      case 'payment_due':
      case 'payment_received':
        router.push('/patient/payments');
      default:
        router.push('/patient/notifications');
    }
  }
}
```

---

## Cloud Functions — Recordatorios de citas (Cron)

```typescript
// Ejecuta cada hora — evalúa citas que necesitan recordatorio
export const scheduledAppointmentReminders = functions
  .pubsub.schedule('every 60 minutes')
  .timeZone('America/Bogota')
  .onRun(async () => {
    const now = new Date();

    // Citas en las próximas 24h sin recordatorio enviado
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in23h = new Date(now.getTime() + 23 * 60 * 60 * 1000);

    const appointments24h = await admin.firestore()
      .collection('appointments')
      .where('fechaHora', '>=', Timestamp.fromDate(in23h))
      .where('fechaHora', '<=', Timestamp.fromDate(in24h))
      .where('estado', 'in', ['programada', 'confirmada'])
      .where('recordatorio24hEnviado', '==', false)
      .get();

    for (const doc of appointments24h.docs) {
      const appt = doc.data();
      const patient = await admin.firestore()
        .collection('patients').doc(appt.patientId).get();
      const fcmToken = patient.data()?.fcmToken;
      if (!fcmToken) continue;

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'Recordatorio de cita — OCG Clínica',
          body: `Tienes una cita mañana a las ${formatTime(appt.fechaHora.toDate())}`,
        },
        data: { type: 'appointment', appointmentId: doc.id },
      });

      // Marcar recordatorio como enviado
      await doc.ref.update({ recordatorio24hEnviado: true });

      // Guardar en colección notifications para el historial
      await admin.firestore().collection('notifications').add({
        recipientId: appt.patientId,
        titulo: 'Recordatorio de cita',
        cuerpo: `Cita mañana a las ${formatTime(appt.fechaHora.toDate())}`,
        tipo: 'recordatorioCita24h',
        leida: false,
        data: { appointmentId: doc.id },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Repetir lógica para recordatorios de 2h...
  });
```

---

## Configuración iOS — No te olvides de esto

Para que las notificaciones funcionen en iOS DEBES:

1. Tener una cuenta activa de Apple Developer Program ($99/año)
2. En Xcode: habilitar la capability "Push Notifications" en el target de la app
3. Generar un APNs Authentication Key (.p8) en Apple Developer Console
4. Subir el archivo .p8 a Firebase Console → Proyecto → App iOS → Cloud Messaging
5. En el AppDelegate.swift asegurarte de que estás registrando para notificaciones remotas

Si no haces esto, las notificaciones van a funcionar en Android y van a fallar silenciosamente en iOS.

---

## NotificationsScreen

Lista de las últimas 50 notificaciones del usuario, ordenadas por fecha descendente.
- Notificaciones no leídas: fondo ligeramente sand con punto bronze a la izquierda
- Notificaciones leídas: fondo white, texto más tenue
- Al tocar una notificación: marca como leída + navega a la pantalla relevante
- Botón "Marcar todas como leídas" en el AppBar

Usar un StreamProvider que escucha la colección notifications filtrando por recipientId.
