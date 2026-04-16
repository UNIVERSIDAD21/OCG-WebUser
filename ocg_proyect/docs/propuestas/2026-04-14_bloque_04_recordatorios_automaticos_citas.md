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
# Bloque 04 — Recordatorios automáticos de citas por WhatsApp y app

## 1) Problemática

Borlty, el Bloque 04 tampoco está cumplido. El sistema no está enviando ni gestionando correctamente los recordatorios automáticos por WhatsApp y por app.

### Hallazgos reales reportados

- Los recordatorios de WhatsApp no funcionan.
- Los recordatorios de la app tampoco funcionan.

Aunque aquí no se reportó un checklist tan detallado como en Bloques 01 y 02, eso ya basta para concluir que el bloque no puede darse por implementado, porque su objetivo completo era precisamente programar y gestionar recordatorios automáticos por ambos canales.

### Lo que este bloque debía lograr y no logró

Este bloque debía:

- programar recordatorios automáticos por dos canales,
- hacerlo en dos momentos obligatorios:
  - 1 día antes,
  - 1 hora antes,
- evitar duplicados,
- invalidar recordatorios al reprogramar,
- cancelarlos al cancelar cita,
- validar el estado actual de la cita antes de enviar,
- respetar zona horaria Colombia,
- no fingir WhatsApp como funcional si no hay proveedor real,
- dejar trazabilidad de envío y errores.

Si hoy no funcionan ni WhatsApp ni app, entonces este bloque está incumplido.

---

## 2) Análisis Problemática

### A. Se confundió “notificación” con “recordatorio programado”

No basta con crear una notificación visual o una colección genérica de mensajes. El bloque exigía una entidad programada por recordatorio, con estado, canal, momento de envío e idempotencia.

### B. No existe orquestación seria de eventos

Este bloque dependía de reaccionar correctamente a:

- crear cita,
- reprogramar,
- cancelar,
- completar,
- marcar no asistió.

Si no existe una estructura que invalide o reprograme recordatorios, cualquier intento de envío será inconsistente.

### C. Falta de backend responsable

Este bloque no puede depender solo del cliente. Un usuario no debe enviar WhatsApp directamente ni marcar recordatorios como enviados. Si no hay backend responsable, no hay seguridad ni consistencia.

### D. WhatsApp no puede “simularse” como listo

Si no hay proveedor real configurado, no puedes presentar WhatsApp como funcional. En ese caso debes dejar modelado el canal, el payload, los estados y los logs, pero no venderlo como operativo.

### E. Riesgo de duplicados y mensajes incorrectos

Sin idempotencia y sin relectura de la cita antes de enviar, puedes terminar mandando recordatorios sobre citas:

- canceladas,
- reprogramadas,
- completadas,
- o ya inválidas.

### F. Zona horaria y consentimiento no resueltos

Si no controlas `America/Bogota`, ni validas teléfono, consentimiento y canal habilitado, este bloque queda técnicamente inseguro y funcionalmente poco confiable.

---

## 3) Solución Problemática

Vas a implementar correctamente el Bloque 04 como sistema de recordatorios programados, no como notificaciones improvisadas.

### A. Crear entidad real de recordatorio programado

Debes implementar una colección global práctica como:

```txt
scheduledNotifications/{notificationId}
```

Cada documento debe tener al menos:

- `appointmentId`
- `patientId`
- `treatmentId` opcional
- `channel` (`app` / `whatsapp`)
- `kind` (`day_before` / `hour_before`)
- `scheduledFor`
- `status`
- `payloadSnapshot`
- `idempotencyKey`
- `appointmentVersion`
- `createdAt`
- `updatedAt`
- `sentAt`
- `failedAt`
- `errorMessage`

### B. Programar automáticamente al crear cita válida

Al crear una cita válida en estado permitido, el sistema debe generar:

- recordatorio T-1 día por app,
- recordatorio T-1 día por WhatsApp,
- recordatorio T-1 hora por app,
- recordatorio T-1 hora por WhatsApp,

solo si:

- el canal está habilitado,
- existen datos suficientes,
- no se trata de un recordatorio retroactivo.

### C. Validar estados de cita antes de crear y antes de enviar

Solo se deben programar o enviar recordatorios para citas en estados válidos, por ejemplo:

- `programada`
- `confirmada`

Y se deben bloquear o invalidar para:

- `cancelada`
- `noAsistio`
- `reprogramada`
- `completada`

Antes de enviar cualquier recordatorio, el backend debe volver a leer la cita y validar su estado actual.

### D. Reprogramación correcta

Si la cita se reprograma, debes:

- marcar recordatorios anteriores como `obsolete`,
- crear nuevos recordatorios para la nueva fecha,
- aumentar o registrar versión de la cita,
- evitar que recordatorios viejos se envíen.

### E. Cancelación correcta

Si la cita se cancela, debes:

- marcar pendientes como `cancelled`,
- impedir cualquier envío posterior.

### F. Manejo de completada y no asistió

Si la cita se completa o se marca no asistió, debes:

- evitar recordatorios posteriores,
- marcar pendientes como `skipped` o `cancelled`.

### G. No crear recordatorios absurdos o retroactivos

#### Si faltan menos de 24 horas al crear la cita
- no crear T-1 día,
- sí crear T-1 hora si aplica.

#### Si faltan menos de 1 hora
- no crear recordatorios retroactivos,
- no enviar mensajes tardíos absurdos.

### H. Anti-duplicado obligatorio

Cada recordatorio debe tener una llave idempotente, por ejemplo:

```txt
appointmentId_channel_kind_appointmentVersion
```

No debe existir más de un recordatorio pendiente con la misma llave.

Antes de enviar, el backend debe:

1. leer recordatorio,
2. validar que siga `pending`,
3. leer cita actual,
4. validar estado,
5. validar momento,
6. enviar,
7. marcar como `sent`.

### I. Backend recomendado

Para primera versión, implementa:

- colección `scheduledNotifications`,
- Cloud Scheduler,
- Cloud Function procesadora de pendientes,
- validación de estado y canal,
- actualización de estado del recordatorio.

Más adelante se puede evolucionar a Cloud Tasks, pero primero debes cerrar una versión simple y seria.

### J. Canal app y canal WhatsApp

#### App
Debe implementarse mediante:

- FCM push,
- y/o registro en colección `notifications`.

Idealmente:

1. crear registro,
2. enviar push si hay token activo,
3. si no hay token, dejar registro interno.

#### WhatsApp
Debes definir proveedor real:

- WhatsApp Cloud API,
- Twilio,
- u otro proveedor autorizado.

Si aún no hay proveedor, debes dejar el canal preparado pero no marcarlo como funcional. En ese caso el estado debe reflejar una realidad como `pending_provider` o equivalente en logs / capa de servicio.

### K. Consentimiento, teléfono y zona horaria

Antes de enviar WhatsApp debes validar:

- teléfono existente,
- teléfono normalizado,
- autorización para recibir mensajes,
- si el destino es paciente, acudiente o ambos.

Además, todo debe calcularse con zona horaria Colombia:

- guardar timestamps en UTC,
- mostrar y calcular con `America/Bogota`.

### L. UI mínima y logging

Como mínimo, en admin debe poder verse:

- recordatorios activos,
- canal,
- fecha programada,
- estado,
- último intento,
- error si falló,
- opción de desactivar recordatorios de esa cita.

También debes registrar:

- `lastAttemptAt`
- `attemptCount`
- `providerMessageId`
- `errorCode`
- `errorMessage`

### M. Seguridad obligatoria

- solo backend debe marcar recordatorios como enviados,
- admin puede consultar estados,
- paciente solo consulta lo propio si aplica,
- el cliente no puede falsificar `sent`,
- el cliente no puede enviar WhatsApp directamente.

### N. Entregables obligatorios

No cierres este bloque hasta entregar de verdad:

1. Modelo de recordatorio programado.
2. Creación automática al crear cita.
3. Invalidación al reprogramar.
4. Cancelación al cancelar cita.
5. Validación de estado antes de enviar.
6. Envío o preparación real del canal app.
7. Preparación realista de WhatsApp.
8. Idempotencia anti-duplicados.
9. Logs de intento y resultado.
10. UI mínima de consulta admin.
11. Seguridad para impedir envíos desde cliente.
12. Validación manual real con:
   - cita creada con más de 24h,
   - cita creada con menos de 24h,
   - cita creada con menos de 1h,
   - cita reprogramada,
   - cita cancelada,
   - cita completada,
   - duplicado bloqueado.

### O. Criterio de aceptación real

El Bloque 04 solo se considera terminado cuando:

- al crear cita válida se programan recordatorios correctos,
- al reprogramar se invalidan los anteriores y se crean nuevos,
- al cancelar no se envían pendientes,
- no se crean recordatorios retroactivos,
- no se envían duplicados,
- el backend valida el estado actual antes de enviar,
- existe trazabilidad de cada recordatorio,
- app y WhatsApp quedan modelados correctamente,
- WhatsApp no se marca como funcional sin proveedor real.

---

## 4) Regaña al desarrollador

Borlty, aquí no basta con decir “las notificaciones luego las conectamos”. Este bloque tenía un objetivo muy concreto y sensible: recordarle al paciente su cita por dos canales, en dos momentos, sin duplicados y sin errores de estado. Si hoy no funciona ni app ni WhatsApp, entonces no cumpliste nada de lo importante.

No vuelvas a vender como “recordatorios automáticos” una implementación que no tiene programación real, ni idempotencia, ni backend responsable, ni control de estados, ni proveedor serio de WhatsApp. Eso no es automatización; eso es dejar una deuda técnica peligrosa en algo que afecta directamente la experiencia del paciente.

Quiero trazabilidad real, programación real y seguridad real. Si el backend no puede demostrar cuándo creó, invalidó, envió o canceló un recordatorio, entonces este bloque sigue abierto.
