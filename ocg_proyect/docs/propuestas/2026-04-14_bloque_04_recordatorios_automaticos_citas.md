# Bloque 04 — Recordatorios automáticos de citas por WhatsApp y app

## Objetivo

Enviar recordatorios automáticos de citas por dos canales:

- WhatsApp
- aplicación

Momentos obligatorios:

- 1 día antes de la cita
- 1 hora antes de la cita

Este bloque debe evitar duplicados, respetar cambios de estado de la cita y validar siempre la información actual antes de enviar.

---

## Qué entendemos del negocio

Los recordatorios no serán manuales. Deben programarse y enviarse automáticamente cuando exista una cita válida.

El sistema debe reaccionar a eventos como:

- crear cita,
- reprogramar cita,
- cancelar cita,
- marcar no asistió,
- completar cita.

---

## Dependencias del bloque

Este bloque depende de tener estable:

- módulo de citas,
- datos confiables del paciente,
- teléfono del paciente o acudiente,
- zona horaria Colombia,
- canal push app,
- proveedor real de WhatsApp,
- estados de cita bien definidos,
- opcionalmente `treatmentId` si la cita se asocia a un tratamiento.

---

## Estados de cita que permiten recordatorios

Solo deben generarse o enviarse recordatorios para citas en estados válidos.

Estados permitidos recomendados:

- `programada`
- `confirmada`

Estados que deben bloquear recordatorios:

- `cancelada`
- `noAsistio`
- `reprogramada`
- `completada`

Antes de enviar cualquier recordatorio, el backend debe volver a leer la cita y validar su estado actual.

---

## Regla central del bloque

No basta con crear una notificación visual.

Debe existir una entidad programada que represente cada recordatorio.

Estructura recomendada:

```txt
scheduledNotifications/{notificationId}
```

o, si se quiere organizar por cita:

```txt
appointments/{appointmentId}/scheduledNotifications/{notificationId}
```

Recomendación práctica: colección global `scheduledNotifications` para facilitar búsquedas por fecha.

---

## Modelo sugerido de recordatorio

```json
{
  "id": "notificationId",
  "appointmentId": "appointmentId",
  "patientId": "patientId",
  "treatmentId": "treatmentId",
  "channel": "whatsapp",
  "kind": "day_before",
  "scheduledFor": "timestamp",
  "status": "pending",
  "payloadSnapshot": {
    "patientName": "Nombre paciente",
    "appointmentDate": "2026-04-20",
    "appointmentTime": "08:00",
    "phone": "573001112233",
    "message": "Hola..."
  },
  "idempotencyKey": "appointmentId_whatsapp_day_before_v1",
  "appointmentVersion": 1,
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "sentAt": null,
  "failedAt": null,
  "errorMessage": null
}
```

---

## Estados del recordatorio

Estados recomendados:

- `pending`
- `sent`
- `cancelled`
- `obsolete`
- `failed`
- `skipped`

### Significado

- `pending`: pendiente por enviar.
- `sent`: enviado correctamente.
- `cancelled`: cancelado porque la cita fue cancelada.
- `obsolete`: quedó viejo por reprogramación.
- `failed`: hubo error técnico de envío.
- `skipped`: no se envió porque ya no aplicaba.

---

## Canales

### App

El canal app puede implementarse mediante:

- FCM push notification,
- documento en colección `notifications`,
- ambas opciones.

Recomendación:

1. Crear registro en `notifications`.
2. Enviar push si el paciente tiene token FCM activo.
3. Si no hay token, dejar registro interno.

### WhatsApp

Debe definirse proveedor.

Opciones comunes:

- WhatsApp Cloud API de Meta,
- Twilio WhatsApp,
- proveedor local autorizado.

El sistema no debe simular que WhatsApp está listo si no hay proveedor configurado.

Primera implementación aceptable:

- dejar modelo,
- payload,
- estados,
- interfaz de servicio,
- logs,
- y marcar WhatsApp como `pending_provider` si aún no hay proveedor.

---

## Consentimiento y teléfono destino

Antes de enviar WhatsApp se debe validar:

- que el paciente tenga teléfono,
- que el teléfono esté normalizado,
- que exista autorización o consentimiento para recibir mensajes,
- si el mensaje va al paciente, acudiente o ambos.

Campo sugerido en paciente:

```json
{
  "contactPreferences": {
    "allowWhatsappReminders": true,
    "allowPushReminders": true,
    "preferredReminderPhone": "patient",
    "guardianPhone": null
  }
}
```

---

## Zona horaria

Todo cálculo debe manejar correctamente Colombia.

Regla recomendada:

- guardar timestamps en UTC,
- mostrar horas en zona Colombia,
- calcular recordatorios según `America/Bogota`.

Esto evita errores de recordatorios una hora antes o después.

---

## Reglas funcionales

### 1. Al crear una cita

El sistema debe programar:

- recordatorio T-24h por app,
- recordatorio T-24h por WhatsApp,
- recordatorio T-1h por app,
- recordatorio T-1h por WhatsApp.

Solo si el canal está habilitado y hay datos suficientes.

---

### 2. Si la cita se reprograma

El sistema debe:

- marcar recordatorios anteriores como `obsolete`,
- crear nuevos recordatorios para la nueva fecha,
- aumentar o registrar una versión de la cita,
- evitar que recordatorios viejos se envíen.

---

### 3. Si la cita se cancela

El sistema debe:

- marcar recordatorios pendientes como `cancelled`,
- impedir cualquier envío posterior.

---

### 4. Si la cita se completa

El sistema debe:

- no enviar recordatorios posteriores,
- marcar pendientes como `skipped` o `cancelled`.

---

### 5. Si se marca no asistió

El sistema debe:

- no enviar recordatorios posteriores,
- marcar pendientes como `cancelled` o `skipped`.

---

### 6. Si faltan menos de 24 horas al crear la cita

- No crear recordatorio T-24h.
- Sí crear T-1h si todavía aplica.

---

### 7. Si faltan menos de 1 hora al crear la cita

- No crear recordatorio T-1h.
- No crear recordatorios retroactivos.
- Evitar mensajes absurdos o tardíos.

---

## Reglas anti-duplicado

Cada recordatorio debe tener una llave idempotente.

Ejemplo:

```txt
appointmentId_channel_kind_appointmentVersion
```

No debe existir más de un recordatorio pendiente con la misma llave.

Antes de enviar:

1. leer recordatorio,
2. validar que esté `pending`,
3. leer cita actual,
4. validar estado de cita,
5. validar fecha actual,
6. enviar,
7. marcar como `sent`.

---

## Arquitectura recomendada

### Opción recomendada para primera versión

Usar colección `scheduledNotifications` + Cloud Scheduler + Cloud Function.

Flujo:

1. Al crear/reprogramar cita, se crean documentos `scheduledNotifications`.
2. Cloud Scheduler ejecuta una función cada pocos minutos.
3. La función busca recordatorios pendientes con `scheduledFor <= now`.
4. Valida cita y canal.
5. Envía app/WhatsApp.
6. Actualiza estado.

Esta opción es simple y suficiente para empezar.

---

## Alternativa avanzada

Usar Cloud Tasks para programar cada recordatorio individual.

Ventaja:

- más preciso,
- mejor para alto volumen.

Desventaja:

- más configuración,
- más complejidad,
- más riesgo para primera versión.

Recomendación: iniciar con Cloud Scheduler + Firestore y dejar Cloud Tasks como mejora futura.

---

## Mensajes sugeridos

### 1 día antes

```txt
Hola, {nombrePaciente}. Te recordamos tu cita en OCG Clínica mañana a las {hora}. Si necesitas reprogramar, contáctanos a tiempo.
```

### 1 hora antes

```txt
Hola, {nombrePaciente}. Tu cita en OCG Clínica es en 1 hora, a las {hora}. Te esperamos.
```

Si la cita tiene tratamiento asociado, más adelante puede incluirse:

```txt
para tu tratamiento de {nombreTratamiento}
```

No incluir información clínica sensible en WhatsApp sin validarlo con la doctora.

---

## UI admin sugerida

No hace falta una pantalla compleja al inicio.

Pero en la cita sería útil mostrar:

- recordatorios activos,
- canal,
- fecha programada,
- estado,
- último intento,
- error si falló,
- opción para desactivar recordatorios de esa cita.

---

## Opción para desactivar por cita

Debe existir un campo opcional:

```json
{
  "remindersEnabled": true
}
```

Si el admin lo desactiva:

- no crear nuevos recordatorios,
- cancelar pendientes existentes.

---

## Logging

Cada intento de envío debe dejar registro.

Campos recomendados:

```txt
lastAttemptAt
attemptCount
providerMessageId
errorCode
errorMessage
```

Esto ayuda a saber si falló WhatsApp, FCM o los datos del paciente.

---

## Seguridad y permisos

Reglas mínimas:

- Solo backend debe marcar recordatorios como enviados.
- Admin puede consultar estados.
- Paciente puede consultar notificaciones propias si aplica.
- Cliente no debe poder falsificar `sent`.
- Cliente no debe poder enviar WhatsApp directamente.
- Las Cloud Functions deben validar permisos y estado.

---

## Providers / servicios sugeridos

Borlty debe implementar o preparar:

- `ScheduledNotificationModel`
- `ScheduledNotificationsRepository`
- `ReminderSchedulerService`
- `PushNotificationService`
- `WhatsappNotificationService`
- Cloud Function para crear recordatorios al crear cita
- Cloud Function para invalidar al reprogramar/cancelar
- Cloud Scheduler Function para procesar pendientes
- validaciones de zona horaria

---

## Entregables de implementación

Borlty debe entregar:

1. Modelo de recordatorio programado.
2. Creación automática de recordatorios al crear cita.
3. Invalidación al reprogramar cita.
4. Cancelación al cancelar cita.
5. Validación de estados antes de enviar.
6. Envío o preparación de canal app.
7. Preparación realista de canal WhatsApp.
8. Llave idempotente anti-duplicados.
9. Logs de intento y resultado.
10. UI mínima para ver estado de recordatorios.
11. Seguridad para impedir envíos desde cliente.
12. Validación manual con mínimo:
    - cita creada con más de 24h,
    - cita creada con menos de 24h,
    - cita creada con menos de 1h,
    - cita reprogramada,
    - cita cancelada,
    - cita completada,
    - recordatorio duplicado bloqueado.

---

## Riesgos

- Duplicados si no hay idempotencia.
- Mensajes enviados sobre citas canceladas.
- Fallos por zona horaria.
- WhatsApp bloqueado si no hay proveedor real.
- Notificaciones a números incorrectos.
- Exposición de información sensible en mensajes.
- Tokens FCM vencidos o inexistentes.
- Recordatorios viejos enviados después de reprogramar.

---

## Decisiones para validar con Jefe/doctora

- Proveedor oficial de WhatsApp.
- Si el número destino será paciente, acudiente o ambos.
- Si el admin podrá desactivar recordatorios por cita.
- Si habrá plantillas editables o textos fijos inicialmente.
- Si el paciente debe aceptar recibir WhatsApp.
- Si los mensajes pueden mencionar el tipo de tratamiento.
- Cada cuánto correrá el procesador de recordatorios.

---

## Criterio de aceptación del Bloque 04

El bloque se considera terminado cuando:

- Al crear cita válida se programan recordatorios correctos.
- Al reprogramar se invalidan los anteriores y se crean nuevos.
- Al cancelar no se envían recordatorios pendientes.
- No se crean recordatorios retroactivos.
- No se envían duplicados.
- El backend valida estado actual antes de enviar.
- Existe registro de estado por recordatorio.
- App y WhatsApp quedan modelados correctamente.
- WhatsApp no se marca como funcional sin proveedor real.
