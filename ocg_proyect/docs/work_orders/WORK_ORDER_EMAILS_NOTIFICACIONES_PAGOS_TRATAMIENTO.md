# WORK ORDER - Emails para notificaciones de pagos y tratamiento

> Fecha: 2026-05-14  
> Repo: `ocg_proyect`  
> Alcance: extender el sistema actual de notificaciones para enviar tambien emails transaccionales a los correos registrados de cada usuario.  
> Prioridad: alta para pagos y estados de tratamiento; media-alta para cubrir el resto de notificaciones moviles.

---

## 1. Objetivo

Hacer que toda notificacion que hoy se entrega por movil via FCM tambien pueda entregarse por correo electronico al email registrado del usuario correspondiente.

El primer foco funcional es:

1. pagos: pago recibido, pago proximo a vencer, pago vencido, pago fallido o pendiente;
2. tratamiento: cambio de etapa o avance del tratamiento;
3. continuidad: citas y demas notificaciones moviles ya existentes.

El resultado esperado es un sistema multicanal donde el evento de negocio se define una sola vez y luego se entrega por los canales configurados: app/push y email.

---

## 2. Principios de implementacion

1. El envio de emails debe vivir en Cloud Functions, no en Flutter.
2. Flutter no debe saber si un email fue enviado para poder completar una accion critica.
3. La misma notificacion debe conservar un contrato comun: `recipientId`, `recipientRole`, `title`, `body`, `type`, `targetRoute`, `entityId`, `entityType`, `data`.
4. No se deben duplicar mensajes manualmente por cada canal; se debe reutilizar el payload actual y renderizar una version email desde plantillas.
5. Los emails deben ser transaccionales, no marketing.
6. El contenido debe minimizar datos clinicos sensibles. El email puede decir que el tratamiento avanzo, pero el detalle completo debe consultarse dentro del portal autenticado.
7. El sistema debe registrar estado de entrega por canal para auditoria y soporte.
8. La falta de token FCM no debe impedir email, y la falta de email valido no debe impedir push.
9. La entrega por email debe poder apagarse por configuracion sin tocar codigo.
10. Cada bloque debe cerrar con pruebas automatizadas y una validacion manual documentada.

---

## 3. Estado actual relevante detectado

### Backend

Ya existe una base solida para notificaciones en Functions:

- `functions/src/notifications/fcm_delivery.ts`
- `functions/src/notifications/android_notification_service.ts`
- `functions/src/notifications/notification_history.ts`
- `functions/src/notifications/domain_notifications.ts`
- `functions/src/appointments/reminder_scheduler.ts`
- `functions/src/appointments/appointment_patient_notifications.ts`
- `functions/src/payments/payment_due_scheduler.ts`
- `functions/src/payments/payu_webhook_core.ts`
- `functions/src/treatments/on_stage_history_create.ts`

Aunque algunos nombres conservan `Android`, el servicio ya entrega FCM a Android e iOS mediante `sendFcmNotification()`.

### Historial

El historial vive en:

```text
notifications/{notificationId}
```

Campos actuales importantes:

```text
recipientId
recipientRole
title
body
type
channel
read
targetRoute
entityId
entityType
appointmentId
treatmentId
paymentId
payload
source
pushSent
delivery
createdAt
updatedAt
```

### Correos fuente

La fuente principal debe ser:

```text
patients/{patientId}.email
admins/{adminId}.email
```

Se debe contemplar fallback defensivo para campos legacy ya observados en pagos:

```text
correo
patientEmail
```

---

## 4. Arquitectura objetivo

La arquitectura objetivo es:

```text
Evento de negocio
  -> domain_notifications.ts
  -> deliverNotification()
       -> FCM delivery
       -> Email delivery
       -> persist/update notification history
```

El contrato compartido debe seguir siendo `NotificationPayload`.

La entrega por email debe agregarse como canal paralelo, no como logica aparte dentro de pagos, tratamiento o citas.

---

## 5. Modelo de datos propuesto

No romper el modelo actual. Agregar campos nuevos al documento `notifications/{notificationId}`:

```text
channels: ['app', 'email']
emailSent: boolean
emailStatus: 'sent' | 'failed' | 'skipped_no_email' | 'skipped_disabled' | 'skipped_unverified' | 'pending'
emailTo: string | null
emailProvider: string | null
emailProviderMessageId: string | null
emailAttemptedAt: timestamp | null
emailError: {
  code: string
  message: string
} | null
```

Mantener estos campos sin cambios para no romper la app:

```text
channel
pushSent
delivery
read
payload
targetRoute
```

Regla de compatibilidad:

- `delivery` sigue representando FCM/push.
- Los datos de email viven en campos `email*`.
- Si en el futuro se quiere un modelo mas elegante, se puede migrar a `deliveryByChannel`, pero no en este primer bloque.

---

## 6. Proveedor de email

Antes de implementar se debe elegir un proveedor transaccional.

Opciones tecnicas aceptables:

- Brevo
- SendGrid
- Mailgun
- Resend

Decision recomendada:

- usar un adapter propio `email_delivery.ts`;
- ocultar el proveedor detras de una interfaz interna;
- guardar credenciales en Firebase Functions secrets/config, nunca en codigo;
- permitir `EMAIL_ENABLED=false` para ambientes sin envio real.
- usar Brevo como primer proveedor real porque permite arrancar con remitente verificado por correo, sin DNS ni dominio propio en esta fase.

Variables/secrets necesarios:

```text
EMAIL_ENABLED
EMAIL_PROVIDER
BREVO_API_KEY
EMAIL_FROM
EMAIL_REPLY_TO
EMAIL_APP_BASE_URL
```

Ejemplo de `EMAIL_APP_BASE_URL`:

```text
https://app.ocgclinica.com
```

Ese valor se usa para construir links hacia el portal, por ejemplo:

```text
/patient/payments
/patient
/patient/appointments
```

---

## 7. Plan por bloques

# BLOQUE 00 - Auditoria y decisiones previas

## Objetivo

Confirmar exactamente que notificaciones moviles existen hoy y que correos deben recibirlas.

## Tareas

- Inventariar todos los `type` enviados desde `domain_notifications.ts`.
- Confirmar eventos emitidos desde:
  - `payu_webhook_core.ts`
  - `payment_due_scheduler.ts`
  - `on_stage_history_create.ts`
  - `reminder_scheduler.ts`
  - `appointment_patient_notifications.ts`
- Confirmar campos reales de email en `patients` y `admins`.
- Definir proveedor de email.
- Definir dominio remitente y remitente visible.
- Definir si admins reciben emails tambien o si el primer alcance es paciente.

## Entregable

Tabla de tipos de notificacion con:

```text
type
destinatario
push actual
email requerido
template
link destino
prioridad
```

## Resultado de auditoria - 2026-05-14

Estado del Bloque 00:

- Inventario de `type` actuales: cerrado.
- Campos fuente de email: cerrados para implementacion inicial.
- Alcance admin: incluido. Los admins tambien deben recibir email en eventos que hoy generan notificacion admin, especialmente pagos.
- Proveedor de email: pendiente de decision humana. El repo no tiene dependencia, secrets ni variables `EMAIL_*`.
- Dominio/base URL: pendiente de decision humana. Como referencia tecnica de staging existe Firebase Hosting `https://ocg-humanbionics.web.app`; produccion debe quedar en `EMAIL_APP_BASE_URL`.

## Campos fuente de email confirmados

| Rol | Coleccion | Campo principal | Fallbacks aceptados | Evidencia |
|---|---|---|---|---|
| Paciente | `patients/{patientId}` | `email` | `correo`, `patientEmail` | `create_patient_account.ts`, `register_patient_self.ts`, `payu_shared.ts` |
| Admin | `admins/{adminId}` | `email` | ninguno por ahora | `set_admin_role.ts`, `admin_role_management.ts` |

Notas:

- `PatientModel` lee `email` como campo principal.
- `payu_shared.ts` ya contempla `email`, `correo` y `patientEmail`; conviene reutilizar esa tolerancia en el resolver de email.
- No hay preferencia `emailEnabled` ni verificacion local de email en Firestore todavia. Eso queda para Bloque 07.

## Matriz de notificaciones actuales

| Type | Trigger actual | Destinatario | Push/historial actual | Email requerido | Template | Link destino | Prioridad | Observaciones |
|---|---|---|---|---|---|---|---|---|
| `payment_received` | `payu_webhook_core.ts` cuando PayU aprueba | Paciente | Push FCM + historial | Si | `payment_received` | `/patient/payments` | Alta | Debe ser idempotente por `payment_received_{reference}`. |
| `payment_reported` | `payu_webhook_core.ts` despues de pago aprobado | Admin | Push FCM + historial | Si | `payment_reported` | `/admin/patients/{patientId}?section=pagos` | Alta | Se envia a todos los docs de `admins`. |
| `payment_failed` | `payu_webhook_core.ts` con `statePol=6` | Admin | Push FCM + historial | Si | `payment_failed` | `/admin/patients/{patientId}?section=pagos` | Alta | Actualmente no se envia al paciente. No agregar paciente sin decision de producto. |
| `payment_pending_validation` | `payu_webhook_core.ts` con `statePol=7` | Admin | Push FCM + historial | Si | `payment_pending_validation` | `/admin/patients/{patientId}?section=pagos` | Alta | Operativo para seguimiento manual. |
| `payment_due` | `payment_due_scheduler.ts`, 3 dias antes | Paciente | Push FCM + historial | Si | `payment_due` | `/patient/payments` | Alta | Usa `payment_due_{paymentId}_{yyyy-mm-dd}`. |
| `payment_due_soon` | `payment_due_scheduler.ts`, 3 dias antes | Admin | Historial solamente (`sendPush=false`) | Si | `payment_due_soon` | `/admin/patients/{patientId}?section=pagos` | Alta | Aunque hoy no manda push, entra por foco de pagos y soporte admin. |
| `payment_overdue` | `payment_due_scheduler.ts`, pago vencido | Admin | Push FCM + historial | Si | `payment_overdue` | `/admin/patients/{patientId}?section=pagos` | Alta | Usa key diaria para evitar duplicados por fecha. |
| `treatment_stage_updated` | `on_stage_history_create.ts` | Paciente | Push FCM + historial | Si | `treatment_stage_updated` | `/patient` | Alta | `on_patient_stage_change_write.ts` puede crear el historial que dispara este evento. |
| `appointment_created` | `appointment_patient_notifications.ts` al crear cita | Paciente | Push FCM + historial | Si | `appointment_created` | `/patient/appointments` | Media | Siempre notifica al paciente. |
| `appointment_created` | `appointment_patient_notifications.ts` si el paciente creo la cita | Admin | Push FCM + historial | Si | `appointment_created_admin` | `/admin/patients/{patientId}?section=citas` | Media | Solo si `createdByPatient=true`. |
| `appointment_cancelled` | `appointment_patient_notifications.ts` al cancelar | Paciente | Push FCM + historial | Si | `appointment_cancelled` | `/patient/appointments` | Media | Usa cita anterior cuando existe. |
| `appointment_cancelled` | `appointment_patient_notifications.ts` si el paciente cancelo | Admin | Push FCM + historial | Si | `appointment_cancelled_admin` | `/admin/patients/{patientId}?section=citas` | Media | Solo si el actor fue paciente. |
| `appointment_confirmed` | `appointment_patient_notifications.ts` al confirmar | Paciente | Push FCM + historial | Si | `appointment_confirmed` | `/patient/appointments` | Media | No hay notificacion admin actual para confirmacion. |
| `appointment_rescheduled` | `appointment_patient_notifications.ts` por cambio de fecha o estado reprogramada | Paciente | Push FCM + historial | Si | `appointment_rescheduled` | `/patient/appointments` | Media | `notificationId` incluye timestamp nuevo. |
| `appointment_rescheduled` | `appointment_patient_notifications.ts` si el paciente reprogramo | Admin | Push FCM + historial | Si | `appointment_rescheduled_admin` | `/admin/patients/{patientId}?section=citas` | Media | Solo si el actor fue paciente. |
| `appointment_reminder` | `reminder_scheduler.ts`, canal `app` | Paciente | Push FCM + historial | Si | `appointment_reminder` | `/patient/appointments` | Media | Hoy se envia 24h antes (`day_before`) y 1h antes (`hour_before`). |
| `appointment_pending_confirmation` | Definido en `domain_notifications.ts` | Paciente/Admin futuro | No se encontro emision actual | No todavia | `appointment_pending_confirmation` | Segun rol | Baja | Mantener template fallback para cuando aparezca el trigger. |
| Type manual/arbitrario | Callable `sendAndroidNotification` | Paciente/Admin | Push FCM + historial | Condicional | `generic` | `targetRoute` del payload | Baja | Requiere politica `allowEmail` o lista de tipos permitidos para evitar spam manual. |

## Fuera de alcance directo del email app

- `scheduledNotifications` canal `whatsapp` ya existe como canal separado en `reminder_scheduler.ts`.
- Email no debe reemplazar WhatsApp; debe ser un canal adicional del mismo evento cuando el canal app/push se procese.

## Decisiones pendientes antes de Bloque 01

1. Crear/verificar sender en Brevo.
2. Guardar `BREVO_API_KEY` como secret de Firebase.
3. Confirmar `EMAIL_APP_BASE_URL` de produccion.
4. Confirmar si los emails admin se activan desde el primer despliegue o solo despues de pagos/tratamiento paciente.

Decision tecnica para avanzar sin bloquear:

- Crear adapter Brevo con fallback `mock`.
- Mantener `EMAIL_ENABLED=false` por defecto.
- No usar SMTP, DNS ni dominio propio en esta fase.

## Criterio de cierre

- No queda ningun `type` movil sin clasificar.
- Se conoce el proveedor de email.
- Se conocen los campos fuente de email.

---

# BLOQUE 01 - Contrato multicanal y configuracion segura

## Objetivo

Preparar el backend para saber cuando puede enviar email y como debe registrar el resultado.

## Archivos a tocar

```text
functions/package.json
functions/src/notifications/fcm_delivery.ts
functions/src/notifications/notification_history.ts
functions/src/notifications/domain_notifications.ts
functions/src/index.ts
```

## Archivos nuevos sugeridos

```text
functions/src/notifications/email_delivery.ts
functions/src/notifications/email_types.ts
functions/src/notifications/email_config.ts
```

## Tareas

- Agregar dependencia del proveedor elegido en `functions/package.json`.
- Crear tipos internos:
  - `EmailDeliveryStatus`
  - `EmailDeliveryResult`
  - `EmailRecipient`
  - `EmailNotificationPayload`
- Crear resolver de email:
  - role `patient` -> `patients/{uid}`
  - role `admin` -> `admins/{uid}`
  - fallback a `email`, `correo`, `patientEmail`
- Crear validacion basica de email.
- Crear lectura de configuracion:
  - `EMAIL_ENABLED`
  - `EMAIL_PROVIDER`
  - `EMAIL_FROM`
  - `EMAIL_REPLY_TO`
  - `EMAIL_APP_BASE_URL`
- Extender `persistNotificationHistory()` para aceptar campos `email*` sin alterar `delivery`.

## Criterio de cierre

- `npm run build` compila.
- Hay pruebas unitarias del resolver de email.
- El historial acepta resultado de email sin romper los modelos Flutter actuales.

## Avance de implementacion - 2026-05-14

Estado: iniciado y con contrato base implementado.

Archivos creados:

```text
functions/src/notifications/email_types.ts
functions/src/notifications/email_config.ts
functions/src/notifications/email_delivery.ts
functions/test/email_delivery.test.mjs
```

Archivo modificado:

```text
functions/src/notifications/notification_history.ts
```

Quedo implementado:

- Tipos internos `EmailProvider`, `EmailDeliveryStatus`, `EmailRecipient`, `EmailDeliveryResult`.
- Lectura segura de configuracion runtime:
  - `EMAIL_ENABLED`
  - `EMAIL_PROVIDER`
  - `EMAIL_FROM`
  - `EMAIL_REPLY_TO`
  - `EMAIL_APP_BASE_URL`
- Helper `isEmailRuntimeReady()` para no intentar enviar si faltan piezas criticas.
- Helper `buildEmailAppLink()` para construir links solo desde rutas locales.
- Resolver de email por rol:
  - paciente: `email`, `correo`, `patientEmail`;
  - admin: `email`.
- Validacion basica de email.
- Snapshots de delivery email para estados `pending`, `skipped_disabled`, `skipped_no_email`, `skipped_unverified`.
- `persistNotificationHistory()` ahora soporta:
  - `channels`
  - `emailSent`
  - `emailStatus`
  - `emailTo`
  - `emailProvider`
  - `emailProviderMessageId`
  - `emailAttemptedAt`
  - `emailError`

Proveedor decidido para Bloque 02:

- `brevo`, por plan gratis de 300 emails/dia y porque permite arrancar con remitente verificado por correo, sin SMTP, DNS ni dominio propio en esta fase.
- Remitente funcional recomendado: `OCG Clinica <correo-verificado-en-Brevo>`.
- Reply-to recomendado: correo real de la clinica.
- `BREVO_API_KEY` debe guardarse como secret de Firebase y exponerse solo a las Functions que envien email.

Pendiente humano antes de envio real:

- Crear cuenta del proveedor.
- Verificar sender en Brevo con el link enviado al correo remitente.
- Crear API key con permisos de envio.
- Cargar secrets/config en Firebase.

Comandos ejecutados:

```bash
cd ocg_proyect/functions
npm run build
node --test test/email_delivery.test.mjs
node --test test/fcm_delivery.test.mjs
```

Resultado:

- `npm run build`: OK.
- `email_delivery.test.mjs`: 10 tests OK.
- `fcm_delivery.test.mjs`: 9 tests OK.

---

# BLOQUE 02 - Servicio de email y plantillas base

## Objetivo

Construir el servicio que transforma una notificacion existente en un email profesional, claro y seguro.

## Archivos nuevos sugeridos

```text
functions/src/notifications/email_templates.ts
functions/src/notifications/email_delivery.ts
functions/src/notifications/email_renderer.ts
functions/test/email_delivery.test.mjs
functions/test/email_templates.test.mjs
```

## Reglas de contenido

Cada email debe incluir:

- asunto claro;
- saludo sobrio;
- mismo mensaje principal que la notificacion movil;
- boton/link al portal;
- firma de OCG Clinica;
- texto de seguridad: si no reconoces esta actividad, contacta a la clinica;
- cero datos innecesarios.

No incluir:

- informacion clinica profunda;
- fotos;
- datos de terceros;
- valores sensibles que no sean necesarios para el evento;
- links externos no controlados.

## Templates minimos

```text
payment_received
payment_due
payment_due_soon
payment_overdue
payment_failed
payment_pending_validation
treatment_stage_updated
appointment_created
appointment_confirmed
appointment_cancelled
appointment_rescheduled
appointment_reminder
appointment_pending_confirmation
generic
```

## Criterio de cierre

- Cada `type` tiene subject y cuerpo HTML/text.
- Las plantillas tienen fallback `generic`.
- Los links se construyen desde `EMAIL_APP_BASE_URL`.
- Las pruebas verifican que ningun template critico queda vacio.

## Avance de implementacion - 2026-05-14

Estado: adapter Brevo y templates base implementados.

Archivos creados:

```text
functions/src/notifications/email_templates.ts
functions/test/email_templates.test.mjs
```

Archivos modificados:

```text
functions/src/notifications/email_types.ts
functions/src/notifications/email_config.ts
functions/src/notifications/email_delivery.ts
functions/test/email_delivery.test.mjs
docs/work_orders/WORK_ORDER_EMAILS_NOTIFICACIONES_PAGOS_TRATAMIENTO.md
```

Quedo implementado:

- Provider `brevo`.
- Provider `mock` para pruebas locales sin envio real.
- Lectura de `BREVO_API_KEY` desde entorno/secret, sin valor hardcodeado.
- Envio real por `POST https://api.brevo.com/v3/smtp/email`.
- Headers Brevo:
  - `api-key`
  - `accept: application/json`
  - `content-type: application/json`
- Payload Brevo:
  - `sender`
  - `to`
  - `replyTo`
  - `subject`
  - `htmlContent`
  - `textContent`
  - `tags`
  - headers internos `X-OCG-Notification-*`
- Templates HTML/text para:
  - pagos;
  - tratamiento;
  - citas;
  - fallback generico.
- Construccion segura del link al portal desde `EMAIL_APP_BASE_URL` y rutas locales.
- Escapado HTML de `title` y `body`.
- Resultado de delivery con:
  - `emailStatus=sent` si Brevo responde OK;
  - `emailProviderMessageId` desde `messageId`;
  - `emailStatus=failed` y `emailError` si Brevo rechaza o falla;
  - `skipped_disabled` si falta configuracion o secret;
  - `skipped_no_email` si el usuario no tiene correo valido.

Configuracion esperada:

```text
EMAIL_ENABLED=true
EMAIL_PROVIDER=brevo
BREVO_API_KEY=<Firebase secret>
EMAIL_FROM="OCG Clinica <correo-verificado-en-Brevo>"
EMAIL_REPLY_TO=correo-real-clinica
EMAIL_APP_BASE_URL=https://ocg-humanbionics.web.app
```

Nota de seguridad:

`BREVO_API_KEY` no debe escribirse en el codigo ni en el documento. Debe cargarse con Firebase secrets y luego exponerse en las opciones de las Functions que llamen al adapter.

Comandos ejecutados:

```bash
cd ocg_proyect/functions
npm run build
node --test test/email_delivery.test.mjs
node --test test/email_templates.test.mjs
node --test test/fcm_delivery.test.mjs
```

Resultado:

- `npm run build`: OK.
- `email_delivery.test.mjs`: 14 tests OK.
- `email_templates.test.mjs`: 4 tests OK.
- `fcm_delivery.test.mjs`: 9 tests OK.

---

# BLOQUE 03 - Orquestador de entrega multicanal

## Objetivo

Crear una funcion unica que envie por FCM y email sin duplicar logica por dominio.

## Archivo nuevo sugerido

```text
functions/src/notifications/notification_delivery_service.ts
```

## Tareas

- Crear `deliverNotification(db, input)`.
- Internamente ejecutar:
  - `sendFcmNotification()`
  - `sendEmailNotification()`
  - `persistNotificationHistory()` o update del doc final con ambos resultados.
- Manejar fallos parciales:
  - FCM falla, email enviado: estado valido.
  - Email falla, FCM enviado: estado valido.
  - ambos fallan: registrar error, no ocultarlo.
- Mantener compatible `deliverAndroidNotification()` como wrapper temporal.
- Evitar doble escritura conflictiva del mismo `notificationId`.

## Riesgo

El archivo `android_notification_service.ts` ya persiste historial despues de FCM. Si se agrega email alli sin cuidado se puede duplicar escritura o sobreescribir campos.

## Decision recomendada

Crear `deliverNotification()` nuevo, migrar los llamados de `domain_notifications.ts` por etapas y dejar `deliverAndroidNotification()` como wrapper compatible durante la transicion.

## Criterio de cierre

- Los tests de FCM existentes siguen pasando.
- El nuevo orquestador prueba entregas:
  - push + email ok;
  - push sin token + email ok;
  - push ok + email sin correo;
  - proveedor email falla.

## Avance de implementacion - 2026-05-14

Estado: orquestador multicanal implementado y probado.

Archivos creados:

```text
functions/src/notifications/notification_delivery_service.ts
functions/test/notification_delivery_service.test.mjs
```

Archivos modificados:

```text
functions/src/notifications/android_notification_service.ts
docs/work_orders/WORK_ORDER_EMAILS_NOTIFICACIONES_PAGOS_TRATAMIENTO.md
```

Quedo implementado:

- `deliverNotification(db, input, options)` como entrada unica para entrega multicanal.
- Canales configurables por llamada:
  - `channels.app`
  - `channels.email`
- Ejecucion paralela de:
  - `sendFcmNotification()`
  - `sendEmailNotification()`
- Persistencia unica en `notifications/{notificationId}` con:
  - resultado FCM en `delivery`;
  - resultado email en `emailStatus`, `emailProvider`, `emailProviderMessageId`, `emailError`;
  - `channels: ['app', 'email']` cuando ambos canales participan.
- Compatibilidad preservada:
  - `deliverFcmNotification()` y `deliverAndroidNotification()` siguen funcionando como app/push-only.
  - No se activan emails accidentalmente en llamadas legacy.
- Soporte de pruebas con:
  - `messagingOverride`;
  - `emailOptions.env`;
  - `emailOptions.fetchImpl`.

Casos probados:

- push OK + email mock OK;
- push sin token + email OK;
- push OK + usuario sin email valido;
- Brevo falla + push OK;
- canal app-only mantiene compatibilidad sin email.

Comandos ejecutados:

```bash
cd ocg_proyect/functions
npm run build
node --test test/notification_delivery_service.test.mjs
node --test test/email_delivery.test.mjs
node --test test/email_templates.test.mjs
node --test test/fcm_delivery.test.mjs
```

Resultado:

- `npm run build`: OK.
- `notification_delivery_service.test.mjs`: 5 tests OK.
- `email_delivery.test.mjs`: 14 tests OK.
- `email_templates.test.mjs`: 4 tests OK.
- `fcm_delivery.test.mjs`: 9 tests OK.

Intervencion humana Brevo pendiente:

- Crear sender verificado en Brevo.
- Crear API key.
- Guardar `BREVO_API_KEY` como secret en Firebase.
- Definir `EMAIL_FROM`, `EMAIL_REPLY_TO`, `EMAIL_APP_BASE_URL`.

---

# BLOQUE 04 - Integracion de emails en pagos

## Objetivo

Enviar email para cada notificacion de pagos que ya se envia o registra en movil.

## Archivos a tocar

```text
functions/src/notifications/domain_notifications.ts
functions/src/payments/payu_webhook_core.ts
functions/src/payments/payment_due_scheduler.ts
functions/test/payu_webhook_core.test.mjs
```

## Eventos cubiertos

Paciente:

```text
payment_received
payment_due
payment_failed
payment_pending_validation
```

Admin:

```text
payment_reported
payment_due_soon
payment_overdue
payment_failed
payment_pending_validation
```

## Tareas

- Cambiar `notifyPatientPaymentEvent()` para usar el orquestador multicanal.
- Cambiar `notifyAdminPaymentEvent()` para poder enviar email incluso cuando `sendPush=false`.
- Asegurar que `amount`, `dueDate`, `reference`, `paymentId`, `treatmentId` lleguen al template.
- Revisar que no se envie dos veces el mismo email cuando PayU reintenta webhooks.
- Usar `notificationId` estable para deduplicar:
  - `payment_received_{reference}`
  - `payment_due_{paymentId}_{yyyy-mm-dd}`
  - `admin_payment_overdue_{paymentId}_{yyyy-mm-dd}`

## Criterio de cierre

- Pago recibido por PayU genera notificacion app y email al paciente.
- Pago proximo a vencer genera email al paciente.
- Pago vencido genera email/admin segun decision de alcance.
- Webhook repetido no duplica emails para el mismo `notificationId`.
- Tests de PayU siguen pasando.

## Avance de implementacion - 2026-05-14

Estado: pagos integrados al orquestador multicanal.

Archivos modificados:

```text
functions/src/notifications/domain_notifications.ts
docs/work_orders/WORK_ORDER_EMAILS_NOTIFICACIONES_PAGOS_TRATAMIENTO.md
```

Archivos creados:

```text
functions/test/domain_notifications_payment.test.mjs
```

Quedo implementado:

- `notifyPatientPaymentEvent()` ahora usa `deliverNotification()` con:
  - `channels.app=true`
  - `channels.email=true`
- `notifyAdminPaymentEvent()` ahora envia email para eventos admin de pagos.
- `sendPush=false` en admin se respeta:
  - no intenta push;
  - si email esta habilitado, persiste `channels=['email']`;
  - conserva historial con `delivery.status='internal_only'`.
- `deliverAdminNotification()` conserva compatibilidad:
  - citas/admin y otros dominios no reciben email accidentalmente;
  - email admin se activa solo cuando el caller lo pide con `sendEmail=true`.

Eventos de pago cubiertos:

```text
payment_received
payment_due
payment_reported
payment_pending_validation
payment_failed
payment_overdue
payment_due_soon
```

Validaciones agregadas:

- Pago paciente con email y sin token FCM:
  - push queda `skipped_no_active_tokens`;
  - email queda `sent`;
  - historial incluye `channels=['app','email']`.
- Pago admin con `sendPush=false`:
  - no intenta push;
  - email queda `sent`;
  - historial incluye `channels=['email']`.

Comandos ejecutados:

```bash
cd ocg_proyect/functions
npm run build
node --test test/domain_notifications_payment.test.mjs
node --test test/payu_webhook_core.test.mjs
node --test test/notification_delivery_service.test.mjs
node --test test/email_delivery.test.mjs
node --test test/email_templates.test.mjs
node --test test/fcm_delivery.test.mjs
```

Resultado:

- `npm run build`: OK.
- `domain_notifications_payment.test.mjs`: 2 tests OK.
- `payu_webhook_core.test.mjs`: 14 tests OK.
- `notification_delivery_service.test.mjs`: 5 tests OK.
- `email_delivery.test.mjs`: 14 tests OK.
- `email_templates.test.mjs`: 4 tests OK.
- `fcm_delivery.test.mjs`: 9 tests OK.

Intervencion humana Brevo pendiente:

- Verificar sender en Brevo.
- Cargar `BREVO_API_KEY` como secret.
- Confirmar `EMAIL_FROM` con el correo verificado.
- Confirmar `EMAIL_REPLY_TO` y `EMAIL_APP_BASE_URL`.

---

# BLOQUE 05 - Integracion de emails en estados de tratamiento

## Objetivo

Enviar email al paciente cuando su tratamiento avanza de etapa.

## Archivos a tocar

```text
functions/src/notifications/domain_notifications.ts
functions/src/treatments/on_stage_history_create.ts
functions/src/treatments/on_patient_stage_change_write.ts
```

## Evento cubierto

```text
treatment_stage_updated
```

## Tareas

- Cambiar `notifyPatientTreatmentStageEvent()` para usar el orquestador multicanal.
- Asegurar que el template recibe:
  - `patientId`
  - `treatmentId`
  - `stageHistoryId`
  - `previousStage`
  - `newStage`
- Mantener el copy sobrio:
  - asunto: "Tu tratamiento avanzo de etapa"
  - cuerpo: "Tu tratamiento esta ahora en [etapa]. Puedes ver el detalle en tu portal."
- Evitar exponer notas clinicas internas en email.

## Criterio de cierre

- Crear un `stageHistory` dispara push y email.
- Si el paciente no tiene email, el push sigue funcionando.
- Si el paciente no tiene token FCM, el email sigue funcionando.
- El historial `notifications` deja registrado `emailStatus`.

## Avance de implementacion - 2026-05-14

Estado: avance de tratamiento integrado al orquestador multicanal.

Archivos modificados:

```text
functions/src/notifications/domain_notifications.ts
docs/work_orders/WORK_ORDER_EMAILS_NOTIFICACIONES_PAGOS_TRATAMIENTO.md
```

Archivos creados:

```text
functions/test/domain_notifications_treatment.test.mjs
```

Quedo implementado:

- `notifyPatientTreatmentStageEvent()` ahora usa `deliverNotification()` con:
  - `channels.app=true`
  - `channels.email=true`
- `onPatientStageHistoryCreate` conserva su trigger actual:
  - `patients/{patientId}/stageHistory/{historyId}`.
- El email usa el `title` y `body` ya sanitizados por el flujo de dominio.
- El payload mantiene solo campos necesarios:
  - `patientId`
  - `treatmentId`
  - `stageHistoryId`
  - `previousStage`
  - `newStage`
- No se agregan notas clinicas, diagnosticos breves ni planes internos al payload de notificacion.

Validacion agregada:

- Evento `treatment_stage_updated` con paciente sin token FCM:
  - push queda `skipped_no_active_tokens`;
  - email queda `sent` en modo `mock`;
  - historial incluye `channels=['app','email']`;
  - payload no contiene `notas` ni `diagnosticoBreve`.

Comandos ejecutados:

```bash
cd ocg_proyect/functions
npm run build
node --test test/domain_notifications_treatment.test.mjs
node --test test/domain_notifications_payment.test.mjs
node --test test/notification_delivery_service.test.mjs
node --test test/payu_webhook_core.test.mjs
node --test test/email_delivery.test.mjs
node --test test/email_templates.test.mjs
node --test test/fcm_delivery.test.mjs
```

Resultado:

- `npm run build`: OK.
- `domain_notifications_treatment.test.mjs`: 1 test OK.
- `domain_notifications_payment.test.mjs`: 2 tests OK.
- `notification_delivery_service.test.mjs`: 5 tests OK.
- `payu_webhook_core.test.mjs`: 14 tests OK.
- `email_delivery.test.mjs`: 14 tests OK.
- `email_templates.test.mjs`: 4 tests OK.
- `fcm_delivery.test.mjs`: 9 tests OK.

---

# BLOQUE 06 - Integracion de emails en citas y resto de notificaciones moviles

## Objetivo

Cumplir la regla de "todas las notificaciones que actualmente ya funcionan en moviles".

## Archivos a tocar

```text
functions/src/appointments/reminder_scheduler.ts
functions/src/appointments/appointment_patient_notifications.ts
functions/src/appointments/on_appointment_write.ts
functions/src/notifications/domain_notifications.ts
```

## Eventos cubiertos

```text
appointment_created
appointment_confirmed
appointment_cancelled
appointment_rescheduled
appointment_reminder
appointment_pending_confirmation
```

## Tareas

- Usar el mismo orquestador multicanal en `notifyPatientAppointmentEvent()`.
- Decidir si recordatorios de 24h/2h se envian por email siempre o solo ciertos tipos.
- Evitar spam:
  - no enviar email para cada ajuste interno no visible al paciente;
  - no duplicar email si una cita se reprograma varias veces en segundos;
  - usar `notificationId` estable y especifico.
- Asegurar links:
  - paciente -> `/patient/appointments`
  - admin -> `/admin/patients/{patientId}?section=citas`

## Criterio de cierre

- Cita creada, confirmada, cancelada, reprogramada y recordatorio tienen email cuando aplica.
- No hay duplicados por scheduler.
- Los docs `scheduledNotifications` no se rompen.

## Avance de implementacion - 2026-05-14

Estado: citas y recordatorios integrados al orquestador multicanal.

Archivos modificados:

```text
functions/src/notifications/domain_notifications.ts
functions/src/appointments/reminder_scheduler.ts
docs/work_orders/WORK_ORDER_EMAILS_NOTIFICACIONES_PAGOS_TRATAMIENTO.md
```

Archivos creados:

```text
functions/test/domain_notifications_appointment.test.mjs
```

Quedo implementado:

- `notifyPatientAppointmentEvent()` ahora usa `deliverNotification()` con:
  - `channels.app=true`
  - `channels.email=true`
- `notifyAdminAppointmentEvent()` ahora envia email a admins para las notificaciones de citas que ya existian por app/push.
- Los links quedan alineados por rol:
  - paciente -> `/patient/appointments`
  - admin -> `/admin/patients/{patientId}?section=citas`
- `reminder_scheduler.ts` ahora envia recordatorios `appointment_reminder` por app/push y email desde el mismo `notificationId`.
- El scheduler conserva idempotencia porque mantiene los mismos documentos `scheduledNotifications`:
  - `{appointmentId}_app_day_before`
  - `{appointmentId}_app_hour_before`
- Un recordatorio se marca como enviado si al menos un canal operativo salio bien:
  - push enviado;
  - o email enviado;
  - si ambos fallan/se omiten, queda `failed`.
- El resultado detallado por canal queda en `notifications/{notificationId}` con `delivery` para push y `email*` para email.

Eventos de cita cubiertos:

```text
appointment_created
appointment_confirmed
appointment_cancelled
appointment_rescheduled
appointment_reminder
```

Nota:

- `appointment_pending_confirmation` sigue sin trigger actual encontrado. El template/fallback queda disponible si se activa ese flujo en una tarea posterior.

Validaciones agregadas:

- Cita paciente sin token FCM y con email:
  - push queda `skipped_no_active_tokens`;
  - email queda `sent`;
  - historial incluye `channels=['app','email']`.
- Cita admin sin token FCM y con email:
  - push queda `skipped_no_active_tokens`;
  - email queda `sent`;
  - historial incluye `channels=['app','email']`.

Comandos ejecutados:

```bash
cd ocg_proyect/functions
npm run build
node --test test/domain_notifications_appointment.test.mjs
node --test test/domain_notifications_payment.test.mjs
node --test test/domain_notifications_treatment.test.mjs
node --test test/notification_delivery_service.test.mjs
node --test test/payu_webhook_core.test.mjs
node --test test/email_delivery.test.mjs
node --test test/email_templates.test.mjs
node --test test/fcm_delivery.test.mjs
```

Resultado:

- `npm run build`: OK.
- `domain_notifications_appointment.test.mjs`: 2 tests OK.
- `domain_notifications_payment.test.mjs`: 2 tests OK.
- `domain_notifications_treatment.test.mjs`: 1 test OK.
- `notification_delivery_service.test.mjs`: 5 tests OK.
- `payu_webhook_core.test.mjs`: 14 tests OK.
- `email_delivery.test.mjs`: 14 tests OK.
- `email_templates.test.mjs`: 4 tests OK.
- `fcm_delivery.test.mjs`: 9 tests OK.

---

# BLOQUE 07 - Preferencias, cumplimiento y seguridad

## Objetivo

Dar control operativo y reducir riesgo de privacidad.

## Campos sugeridos por usuario

```text
notificationPreferences: {
  emailEnabled: true,
  paymentEmailsEnabled: true,
  treatmentEmailsEnabled: true,
  appointmentEmailsEnabled: true
}
```

## Decision recomendada

Para esta primera version:

- `emailEnabled` default `true` para notificaciones transaccionales;
- no exponer aun una pantalla completa de preferencias si no esta en alcance;
- permitir que soporte/admin desactive email en Firestore si un paciente lo solicita;
- nunca enviar marketing desde este sistema.

## Seguridad

- No guardar API keys en repo.
- No imprimir emails completos en logs salvo que sea estrictamente necesario.
- Registrar previews o hashes cuando se pueda.
- No incluir datos clinicos sensibles en asunto.
- No incluir adjuntos por defecto.
- No enviar recibos PDF hasta que exista decision explicita sobre archivos adjuntos.

## Criterio de cierre

- El sistema respeta `emailEnabled=false`.
- Los logs no exponen informacion sensible innecesaria.
- La configuracion permite apagar todo email sin redeploy.

---

# BLOQUE 08 - Observabilidad y soporte

## Objetivo

Poder saber si un email salio, fallo o fue omitido.

## Campos de auditoria

```text
emailSent
emailStatus
emailTo
emailProvider
emailProviderMessageId
emailAttemptedAt
emailError
```

## Logs esperados

```text
EMAIL_DELIVERY_START
EMAIL_DELIVERY_RESULT
EMAIL_DELIVERY_SKIPPED
EMAIL_DELIVERY_FAILED
```

## Herramientas opcionales

- Callable admin para reenviar email de una notificacion especifica.
- Vista admin futura con filtro por `emailStatus=failed`.
- Tarea programada futura para reintentos si el proveedor falla temporalmente.

## Criterio de cierre

- Un fallo de email es visible en Firestore y logs.
- Soporte puede distinguir:
  - no habia email;
  - email desactivado;
  - proveedor fallo;
  - enviado correctamente.

---

# BLOQUE 09 - Pruebas y validacion

## Pruebas unitarias Functions

Agregar o extender:

```text
functions/test/email_delivery.test.mjs
functions/test/email_templates.test.mjs
functions/test/fcm_delivery.test.mjs
functions/test/payu_webhook_core.test.mjs
```

Casos minimos:

- resolver email paciente desde `email`;
- resolver email paciente desde `correo`;
- resolver email admin;
- omitir email si `EMAIL_ENABLED=false`;
- omitir email si no hay correo valido;
- plantilla de pago recibido;
- plantilla de pago proximo;
- plantilla de avance de tratamiento;
- delivery multicanal con push ok y email ok;
- delivery multicanal con push sin token y email ok;
- delivery multicanal con email fallido y push ok;
- webhook PayU repetido no duplica email.

## Pruebas manuales

Ambiente de staging o emulador:

1. Crear paciente con email valido.
2. Registrar token FCM si se valida movil.
3. Generar pago recibido.
4. Verificar:
   - notificacion en app;
   - documento `notifications`;
   - email recibido;
   - link abre portal correcto.
5. Crear cambio de etapa.
6. Verificar:
   - push;
   - email;
   - `emailStatus=sent`.
7. Crear paciente sin email.
8. Verificar:
   - push funciona;
   - `emailStatus=skipped_no_email`.
9. Apagar `EMAIL_ENABLED`.
10. Verificar:
   - push funciona;
   - `emailStatus=skipped_disabled`.

## Comandos de cierre

```bash
cd ocg_proyect/functions
npm run build
node --test test/email_delivery.test.mjs
node --test test/email_templates.test.mjs
node --test test/fcm_delivery.test.mjs
node --test test/payu_webhook_core.test.mjs
```

Si se toca Flutter:

```bash
cd ocg_proyect
flutter analyze
flutter test
```

---

# BLOQUE 10 - Despliegue gradual

## Objetivo

Activar emails sin poner en riesgo notificaciones existentes.

## Orden recomendado

1. Deploy con `EMAIL_ENABLED=false`.
2. Validar que push e historial siguen funcionando.
3. Activar email solo para staging o usuarios de prueba.
4. Probar pagos.
5. Probar cambios de etapa.
6. Probar citas.
7. Activar produccion para pacientes.
8. Activar produccion para admins si aplica.

## Criterio de cierre

- No se rompio ningun flujo movil.
- Emails de pago llegan.
- Emails de tratamiento llegan.
- El resto de notificaciones moviles queda cubierto o documentado como excepcion aceptada.
- Se deja log de validacion en `docs/logs/`.

---

## 8. Mapa de archivos esperado

### Nuevos

```text
functions/src/notifications/email_config.ts
functions/src/notifications/email_delivery.ts
functions/src/notifications/email_renderer.ts
functions/src/notifications/email_templates.ts
functions/src/notifications/email_types.ts
functions/src/notifications/notification_delivery_service.ts
functions/test/email_delivery.test.mjs
functions/test/email_templates.test.mjs
```

### A modificar

```text
functions/package.json
functions/src/notifications/domain_notifications.ts
functions/src/notifications/notification_history.ts
functions/src/notifications/android_notification_service.ts
functions/src/payments/payu_webhook_core.ts
functions/src/payments/payment_due_scheduler.ts
functions/src/treatments/on_stage_history_create.ts
functions/src/appointments/reminder_scheduler.ts
functions/src/appointments/appointment_patient_notifications.ts
functions/src/index.ts
```

### Flutter

No deberia ser necesario tocar Flutter para la primera version, salvo que se quiera mostrar estado de email en admin o preferencias al usuario.

Posibles archivos futuros:

```text
lib/features/notifications/data/models/app_notification_model.dart
lib/features/notifications/presentation/patient_notifications_screen.dart
lib/features/dashboard/presentation/admin_notifications_screen.dart
lib/features/auth/providers/auth_providers.dart
```

---

## 9. Definicion de terminado general

El trabajo se considera terminado cuando:

- todos los eventos moviles relevantes tienen canal email;
- pagos y tratamiento estan probados de punta a punta;
- el email se registra en `notifications`;
- errores de email son visibles;
- el sistema no duplica correos en webhooks o schedulers;
- el envio puede apagarse por configuracion;
- no se exponen datos sensibles innecesarios;
- `npm run build` pasa;
- tests de Functions pasan;
- se deja documento de validacion en `docs/logs/`.

---

## 10. Riesgos principales

## Riesgo 1 - Duplicados por webhooks o schedulers

Mitigacion:

- usar `notificationId` estable;
- hacer escritura idempotente;
- no enviar email si el doc ya tiene `emailStatus=sent` para el mismo evento.

## Riesgo 2 - Mezclar historial app con email sin compatibilidad

Mitigacion:

- no cambiar significado de `delivery`;
- agregar campos `email*` como extension;
- mantener `channel` actual.

## Riesgo 3 - Datos sensibles en correo

Mitigacion:

- asunto generico;
- cuerpo resumido;
- detalle completo solo dentro del portal autenticado.

## Riesgo 4 - Proveedor de email bloqueado o mal configurado

Mitigacion:

- `EMAIL_ENABLED=false` por defecto en despliegue inicial;
- logs claros;
- estado `emailStatus=failed`;
- no bloquear push si email falla.

## Riesgo 5 - Correos inexistentes o mal escritos

Mitigacion:

- validacion basica;
- `skipped_no_email`;
- reporte admin futuro de usuarios sin email valido.

---

## 11. Orden ejecutivo recomendado

1. Bloque 00 - Auditoria y proveedor.
2. Bloque 01 - Configuracion y contrato.
3. Bloque 02 - Servicio y plantillas.
4. Bloque 03 - Orquestador multicanal.
5. Bloque 04 - Pagos.
6. Bloque 05 - Tratamiento.
7. Bloque 06 - Citas y resto.
8. Bloque 07 - Preferencias y seguridad.
9. Bloque 08 - Observabilidad.
10. Bloque 09 - Pruebas.
11. Bloque 10 - Despliegue gradual.

Este orden evita tocar todos los triggers a la vez y permite validar valor real desde pagos y tratamiento antes de extender el canal email a todo el sistema.
