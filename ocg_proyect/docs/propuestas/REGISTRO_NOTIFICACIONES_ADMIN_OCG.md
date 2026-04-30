# REGISTRO_NOTIFICACIONES_ADMIN_OCG

## 1. Alcance de la primera versión

Primera versión cerrada de notificaciones para administrador enfocada **solo en CITAS + PAGOS**.

Incluye:
- notificación interna en Firestore/colección `notifications`
- intento de push FCM Android cuando el evento es crítico
- navegación al tocar notificación hacia el detalle del paciente en el tab correcto
- contador de no leídas reutilizando la campana existente del admin

No incluye todavía:
- simulador
- tratamientos
- perfil
- campañas
- chat
- mensajes comerciales

---

## 2. Eventos de citas implementados o soportados

### Implementados
- `appointment_created`
  - cuando el paciente agenda una cita
  - admin recibe notificación interna + push
- `appointment_cancelled`
  - cuando el paciente cancela una cita
  - admin recibe notificación interna + push
- `appointment_rescheduled`
  - soporte listo para notificar si el documento llega marcado con `lastActionByRole = patient`
  - la función ya resuelve la ruta a `section=citas`

### Soportados / preparados
- `appointment_pending_confirmation`
  - soportado a nivel de tipo/routing/arquitectura
  - en esta primera versión no se emite como notificación separada para no duplicar el caso “Nueva cita agendada”

### No se generan para evitar ruido
- admin agenda una cita
- admin confirma una cita
- admin completa una cita
- admin marca no asistió
- admin cancela una cita

---

## 3. Eventos de pagos implementados o soportados

### Implementados
- `payment_reported`
  - cuando PayU reporta/aprueba pago del paciente
  - admin recibe notificación interna + push
- `payment_pending_validation`
  - cuando PayU devuelve estado pendiente de confirmación
  - admin recibe notificación interna + push
- `payment_failed`
  - cuando PayU devuelve rechazo/fallo
  - admin recibe notificación interna + push
- `payment_due_soon`
  - scheduler diario detecta pagos a 3 días de vencer
  - admin recibe notificación **interna**
- `payment_overdue`
  - scheduler diario detecta pagos vencidos
  - admin recibe notificación interna + push

### Soportados / preparados
- flujo de pago por paciente vía webhook PayU ya queda integrado al sistema de notificaciones admin
- navegación al tab Pagos del paciente lista con `section=pagos`

### No se notifican para evitar ruido
- admin registra pago manual
- admin ajusta saldo
- admin corrige cuenta financiera
- admin confirma manualmente un pago

---

## 4. Eventos que generan push

### Citas
- nueva cita agendada por paciente
- cita cancelada por paciente
- cita reprogramada por paciente (cuando el actor queda marcado como paciente)

### Pagos
- nuevo pago reportado
- pago pendiente de validación
- pago rechazado/fallido
- pago vencido

---

## 5. Eventos que quedan solo internos

- pago próximo a vencer (`payment_due_soon`)
- cualquier evento futuro que se quiera conservar en historial sin interrumpir al admin

---

## 6. Eventos que NO se implementan todavía

- simulador
- tratamientos
- perfil
- campañas/promociones
- chat
- recordatorios genéricos sin contexto clínico/financiero claro

---

## 7. Estructura de Firestore

Colección fuente de verdad:
- `notifications`

Campos persistidos/relevantes:
- `id`
- `recipientId`
- `recipientRole`
- `title`
- `body`
- `type`
- `read`
- `route`
- `targetRoute`
- `entityId`
- `entityType`
- `appointmentId`
- `paymentId`
- `treatmentId`
- `transactionId`
- `payload`
- `source`
- `sourceRole`
- `sourceUserId`
- `pushSent`
- `delivery`
- `createdAt`
- `updatedAt`

Notas:
- la notificación interna se persiste incluso si FCM no tiene tokens activos o falla el envío
- el push es complemento, no reemplazo

---

## 8. Manejo de FCM token

Estado actual reutilizado del proyecto:
- el token se guarda por usuario en `admins/{uid}` o `patients/{uid}`
- también se guarda por dispositivo en subcolección `devices`
- se sincroniza al login
- se actualiza con `onTokenRefresh`
- se desactiva al cerrar sesión o al invalidarse el token

Piezas revisadas:
- `functions/src/auth/set_fcm_token.ts`
- `lib/services/firebase/auth_service.dart`
- `lib/services/notifications/fcm_service.dart`

---

## 9. Navegación al tocar notificaciones

### Citas
Ruta objetivo:
- `/admin/patients/{patientId}?section=citas`

### Pagos
Ruta objetivo:
- `/admin/patients/{patientId}?section=pagos`

Refuerzos implementados:
- las notificaciones admin ya incluyen `targetRoute` explícita
- además `FcmPayloadRouter` ahora tiene fallback coherente para admin con `patientId`

---

## 10. Pendientes reales Android/iOS

### Android
- flujo FCM operativo y reutilizado
- permisos se solicitan desde Flutter
- canal Android de alta prioridad ya existe

### iOS
- la arquitectura de token/permisos está parcialmente preparada desde Flutter/Firebase Messaging
- **queda pendiente validar APNs, certificados/capabilities y prueba real en dispositivo iOS**
- no se marca iOS como “listo” sin esa validación

---

## 11. Plan de prueba manual

1. Iniciar sesión como admin en móvil.
2. Aceptar permisos de notificaciones.
3. Validar que el token FCM del admin se guarde o actualice.
4. Iniciar sesión como paciente.
5. Agendar una cita.
6. Confirmar que el admin recibe notificación interna.
7. Confirmar que el admin recibe push si la app está en segundo plano.
8. Tocar la notificación.
9. Validar que abre detalle del paciente en tab Citas.
10. Reportar o simular un pago como paciente, si el flujo existe.
11. Confirmar notificación interna/push de pago.
12. Tocar notificación de pago.
13. Validar que abre detalle del paciente en tab Pagos.
14. Marcar notificación como leída.
15. Confirmar que el badge baja.
16. Verificar pago próximo a vencer (scheduler) mediante documento de prueba con fecha a 3 días.
17. Verificar pago vencido con fecha pasada.

---

## 12. Implementación técnica realizada

### Flutter
- se reutiliza la campana admin existente
- se reutiliza `NotificationsRepository` / `notifications_provider.dart`
- navegación reforzada en `FcmPayloadRouter`
- se marcó actor paciente en cancelación desde `patient_appointments_screen.dart`

### Functions
- helper nuevo/rehecho de notificaciones admin en `domain_notifications.ts`
- hooks de admin para citas en `appointment_patient_notifications.ts`
- hooks de admin para pagos en `payu_webhook.ts`
- scheduler de pagos extendido en `payment_due_scheduler.ts`
- persistencia enriquecida de metadata en `notification_history.ts`

---

## 13. Idempotencia / no duplicados

Se usan IDs lógicos determinísticos por evento, por ejemplo:
- `admin_appointment_{appointmentId}_created_{adminId}`
- `admin_appointment_{appointmentId}_cancelled_{adminId}`
- `admin_payment_reported_{reference}_{adminId}`
- `admin_payment_due_soon_{paymentId}_{yyyy-mm-dd}_{adminId}`
- `admin_payment_overdue_{paymentId}_{yyyy-mm-dd}_{adminId}`

Esto evita multiplicar documentos por el mismo disparo lógico.

---

## 14. Validación de entorno

### Flutter
- Pendiente ejecutar localmente por Erik:
```bash
cd ocg_proyect
flutter analyze
```

### Functions
- Pendiente ejecutar localmente por Erik:
```bash
cd ocg_proyect/functions
npm run build
```

En esta sesión no se reporta build/analyze como exitoso porque no se ejecutó aquí.
