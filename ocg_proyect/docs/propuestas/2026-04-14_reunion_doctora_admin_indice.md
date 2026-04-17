# Bloque 04 — Recordatorios automáticos de citas por app + alertas internas para admin

## Objetivo

Implementar un sistema de recordatorios automáticos de citas usando únicamente la app y el dashboard administrativo.

El bloque debe cubrir dos necesidades al mismo tiempo:

- recordar al paciente sus citas desde la app,
- alertar al admin dentro del dashboard cuando existan citas aún sin confirmar.

Esto debe funcionar sin duplicados, respetando el estado real de la cita, reaccionando a reprogramaciones o cancelaciones y validando siempre la información actual antes de crear o enviar cualquier notificación.

---

## Qué entendemos del negocio

Ya no se usará WhatsApp como canal de recordatorio de citas.

Toda la estrategia de recordatorios y avisos operativos debe vivir dentro del ecosistema del producto:

- notificaciones internas en la app,
- push por FCM cuando exista token activo,
- alertas visibles dentro del dashboard del admin.

La lógica no puede ser manual. El sistema debe reaccionar automáticamente cuando una cita:

- se crea,
- queda pendiente de confirmación,
- se confirma,
- se reprograma,
- se cancela,
- se marca como no asistió,
- se completa.

---

## Cambio funcional clave del bloque

Este bloque deja de ser “recordatorios por WhatsApp y app” y pasa a ser:

**recordatorios automáticos por app + alertas operativas para admin dentro del dashboard**.

Eso significa:

- el paciente recibe recordatorios y novedades en la app,
- el admin ve dentro del dashboard qué citas siguen sin confirmar,
- cuando el admin confirma la cita, la alerta desaparece o se marca como resuelta,
- opcionalmente el paciente recibe una notificación interna informando que su cita ya fue confirmada.

Ese último punto es muy importante porque refuerza tranquilidad y confianza del paciente.

---

## Dependencias del bloque

Este bloque depende de tener estable:

- módulo de citas,
- estados de cita bien definidos,
- pacientes correctamente identificados,
- admins correctamente identificados,
- tokens FCM actualizados cuando existan,
- zona horaria Colombia,
- colección de notificaciones internas,
- dashboard admin con capacidad de mostrar alertas operativas,
- backend con Cloud Functions y procesador programado.

---

## Estados de cita que permiten recordatorios del paciente

Solo deben generarse o enviarse recordatorios para citas en estados válidos.

Estados permitidos recomendados:

- `programada`
- `confirmada`

Estados que deben bloquear recordatorios al paciente:

- `cancelada`
- `noAsistio`
- `reprogramada`
- `completada`

Antes de enviar cualquier recordatorio, el backend debe volver a leer la cita y validar su estado actual.

---

## Estados que deben generar alerta para admin

La alerta para admin no tiene la misma lógica que el recordatorio del paciente.

La alerta administrativa existe para decir:

**“hay una cita que sigue pendiente de confirmación y el admin debe revisarla”**.

Estado principal que debe generar alerta:

- `programada`

Estado que debe resolver o cerrar la alerta:

- `confirmada`
- `cancelada`
- `reprogramada`
- `noAsistio`
- `completada`

En otras palabras:

- si la cita sigue `programada`, la alerta sigue viva,
- si la cita cambia a `confirmada`, la alerta ya no tiene sentido,
- si la cita cambia a otro estado final o inválido para confirmación, también debe cerrarse.

---

## Regla central del bloque

No basta con mostrar una campanita o un mensaje visual.

Debe existir una entidad persistente que represente cada recordatorio y cada alerta operativa.

Estructura recomendada:

```txt
scheduledNotifications/{notificationId}
```

Recomendación práctica: usar colección global `scheduledNotifications` para facilitar:

- búsquedas por fecha,
- reprocesos,
- control de estados,
- trazabilidad,
- dashboards operativos.

---

## Modelo unificado sugerido

```json
{
  "id": "notificationId",
  "appointmentId": "appointmentId",
  "patientId": "patientId",
  "adminTarget": "global_admin_dashboard",
  "audience": "patient",
  "channel": "app",
  "kind": "appointment_day_before",
  "scheduledFor": "timestamp",
  "status": "pending",
  "payloadSnapshot": {
    "patientName": "Nombre paciente",
    "appointmentDate": "2026-04-20",
    "appointmentTime": "08:00",
    "title": "Recordatorio de cita",
    "body": "Tienes una cita mañana a las 8:00 a. m."
  },
  "idempotencyKey": "appointmentId_patient_app_day_before_v1",
  "appointmentVersion": 1,
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "sentAt": null,
  "failedAt": null,
  "resolvedAt": null,
  "errorMessage": null
}
```

---

## Campos clave adicionales para soportar alertas admin

Para alertas administrativas conviene soportar también:

```json
{
  "audience": "admin",
  "channel": "dashboard",
  "kind": "appointment_pending_confirmation",
  "priority": "high",
  "isActionable": true,
  "actionRoute": "/admin/appointments/:id",
  "resolutionReason": null
}
```

Esto permite que el dashboard no solo muestre un aviso, sino una alerta operativa real con contexto y acción.

---

## Tipos de notificación de este bloque

### Para paciente

- `appointment_day_before`
- `appointment_hour_before`
- `appointment_confirmed` 

### Para admin

- `appointment_pending_confirmation`
- `appointment_pending_confirmation_urgent` 

La versión `urgent` puede activarse si la cita sigue sin confirmar cuando entra a una ventana crítica, por ejemplo 24 horas antes.

---

## Estados de la notificación

Estados recomendados:

- `pending`
- `sent`
- `read`
- `resolved`
- `cancelled`
- `obsolete`
- `failed`
- `skipped`

### Significado

- `pending`: pendiente por procesar o mostrar.
- `sent`: ya fue enviada o creada en el destino correcto.
- `read`: el usuario la abrió o visualizó.
- `resolved`: una alerta operativa quedó atendida.
- `cancelled`: se canceló porque ya no aplica.
- `obsolete`: quedó vieja por cambio de versión o reprogramación.
- `failed`: hubo error técnico.
- `skipped`: no se envió porque al validar ya no aplicaba.

---

## Canales de este bloque

### Canal paciente: app

El canal del paciente puede implementarse con:

- documento en colección `notifications`,
- push por FCM si existe token,
- ambas opciones al mismo tiempo.

Recomendación:

1. Crear registro persistente en `notifications`.
2. Enviar push si el paciente tiene token FCM activo.
3. Si no hay token, conservar la notificación interna para que la vea al entrar.

### Canal admin: dashboard

El admin no necesita WhatsApp ni necesariamente push para este caso.

Lo correcto aquí es una alerta interna visible dentro del dashboard.

Opciones válidas:

- tarjeta resumen en panel principal,
- badge con contador de citas sin confirmar,
- lista priorizada de citas pendientes,
- campana de notificaciones internas,
- combinación de todas las anteriores.

Recomendación mínima obligatoria:

- contador visible en dashboard,
- listado de citas pendientes por confirmar,
- acceso directo a la cita para confirmarla.

---

## Zona horaria

Todo cálculo debe manejar correctamente Colombia.

Regla recomendada:

- guardar timestamps en UTC,
- mostrar horas en `America/Bogota`,
- calcular recordatorios con base en `America/Bogota`.

Esto evita errores en los recordatorios del paciente y también en la prioridad de alertas del admin.

---

## Reglas funcionales

### 1. Al crear una cita

Si la cita nace en estado `programada`, el sistema debe:

- crear recordatorio T-24h para el paciente,
- crear recordatorio T-1h para el paciente,
- crear alerta interna para admin indicando que la cita está pendiente de confirmación.

Si la cita nace ya `confirmada`, el sistema debe:

- crear recordatorio T-24h para el paciente,
- crear recordatorio T-1h para el paciente,
- no crear alerta pendiente para admin.

---

### 2. Si la cita sigue sin confirmar

Mientras la cita permanezca en `programada`, el admin debe seguir viendo la alerta en el dashboard.

Además, el sistema puede elevar prioridad cuando se acerque la fecha.

Ejemplo recomendado:

- más de 24h: `appointment_pending_confirmation`
- 24h o menos: `appointment_pending_confirmation_urgent`

---

### 3. Cuando el admin confirma la cita

El sistema debe:

- marcar la alerta administrativa como `resolved`,
- guardar `resolvedAt`,
- opcionalmente registrar qué admin la resolvió,
- opcionalmente enviar al paciente una notificación interna tipo `appointment_confirmed`.

Este punto ayuda directamente a que el paciente se sienta más tranquilo.

---

### 4. Si la cita se reprograma

El sistema debe:

- marcar recordatorios anteriores del paciente como `obsolete`,
- marcar alerta admin anterior como `obsolete` o `resolved`,
- crear nuevos recordatorios para la nueva fecha,
- crear nueva alerta admin si la nueva cita queda `programada`,
- aumentar o registrar una nueva versión de la cita,
- evitar que recordatorios viejos o alertas viejas sigan activas.

---

### 5. Si la cita se cancela

El sistema debe:

- marcar recordatorios pendientes del paciente como `cancelled`,
- cerrar la alerta administrativa,
- impedir cualquier envío posterior relacionado con esa versión de la cita.

---

### 6. Si la cita se completa

El sistema debe:

- no enviar recordatorios posteriores,
- marcar pendientes como `skipped` o `cancelled`,
- cerrar cualquier alerta admin abierta.

---

### 7. Si se marca no asistió

El sistema debe:

- no enviar recordatorios posteriores,
- cerrar cualquier alerta administrativa pendiente,
- dejar trazabilidad del cierre por cambio de estado.

---

### 8. Si faltan menos de 24 horas al crear la cita

- No crear recordatorio T-24h.
- Sí crear T-1h si todavía aplica.
- Sí crear alerta admin si la cita está `programada`.

---

### 9. Si faltan menos de 1 hora al crear la cita

- No crear recordatorio T-1h.
- No crear recordatorios retroactivos.
- Sí crear alerta admin si la cita está `programada` y todavía requiere confirmación.
- Evitar comportamientos absurdos o tardíos.

---

## Reglas anti-duplicado

Cada notificación debe tener una llave idempotente.

Ejemplos:

```txt
appointmentId_patient_app_day_before_appointmentVersion
appointmentId_patient_app_hour_before_appointmentVersion
appointmentId_admin_dashboard_pending_confirmation_appointmentVersion
```

No debe existir más de una notificación activa de la misma clase para la misma versión de cita.

Antes de enviar o mostrar como activa:

1. leer notificación,
2. validar que siga `pending`,
3. leer cita actual,
4. validar estado de cita,
5. validar versión de la cita,
6. validar fecha actual,
7. enviar o materializar,
8. actualizar estado.

---

## Arquitectura recomendada

### Opción recomendada para primera versión

Usar colección `scheduledNotifications` + Cloud Scheduler + Cloud Function.

Flujo:

1. Al crear o actualizar cita, backend sincroniza notificaciones requeridas.
2. Cloud Scheduler ejecuta una función cada pocos minutos.
3. La función busca notificaciones pendientes con `scheduledFor <= now`.
4. Valida estado real de la cita.
5. Crea la notificación interna en `notifications` y envía FCM si aplica.
6. Actualiza estado.

Para alertas de admin, no siempre hace falta esperar al Scheduler. Muchas pueden generarse inmediatamente al crear o modificar la cita y mantenerse activas por consulta del dashboard.

---

## Alternativa avanzada

Usar Cloud Tasks para programar recordatorios puntuales del paciente y mantener alertas admin por consulta viva.

Ventaja:

- mayor precisión temporal,
- mejor escalabilidad.

Desventaja:

- más complejidad,
- más configuración,
- más riesgo para una primera versión.

Recomendación: iniciar con Cloud Scheduler + Firestore.

---

## Mensajes sugeridos para paciente

### 1 día antes

```txt
Hola, {nombrePaciente}. Te recordamos tu cita en OCG Clínica mañana a las {hora}.
```

### 1 hora antes

```txt
Hola, {nombrePaciente}. Tu cita en OCG Clínica es en 1 hora, a las {hora}. Te esperamos.
```

### Cuando el admin confirma la cita

```txt
Tu cita en OCG Clínica ya fue confirmada. Puedes verla en la app.
```

No incluir información clínica sensible innecesaria en las notificaciones.

---

## Qué debe ver el admin dentro del dashboard

Este punto ya no es opcional: debe existir una alerta operativa visible.

Mínimo esperado:

- contador de citas sin confirmar,
- tarjeta o widget destacado en el dashboard,
- listado de citas pendientes,
- nombre del paciente,
- fecha y hora de la cita,
- tiempo restante,
- prioridad visual,
- botón o acceso directo para revisar y confirmar.

Recomendación de UX:

- si una cita está próxima y sigue sin confirmar, debe verse más destacada,
- no esconder estas alertas en una sección secundaria,
- el admin debe verlas apenas entra al panel.

---

## UI admin sugerida

### Widget resumen en dashboard

Ejemplo de bloques:

- `Citas pendientes de confirmación: 6`
- `Citas próximas sin confirmar: 2`
- `Citas para hoy sin confirmar: 1`

### Lista priorizada

Cada fila debería mostrar:

- paciente,
- fecha,
- hora,
- estado,
- prioridad,
- tiempo restante,
- acción `Ver cita` o `Confirmar`.

### Estado visual recomendado

- normal: cita programada con margen suficiente,
- alta prioridad: cita dentro de 24h sin confirmar,
- crítica: cita muy próxima y aún sin confirmar.

---

## Opción para desactivar recordatorios por cita

Debe existir un campo opcional:

```json
{
  "remindersEnabled": true
}
```

Si el admin lo desactiva:

- no crear nuevos recordatorios del paciente,
- cancelar pendientes existentes.

La alerta administrativa por falta de confirmación se puede manejar aparte.

Recomendación:

- `remindersEnabled` controla recordatorios del paciente,
- la alerta admin depende del estado operativo real de la cita.

---

## Logging y trazabilidad

Cada intento o transición debe dejar registro.

Campos recomendados:

```txt
lastAttemptAt
attemptCount
providerMessageId
errorCode
errorMessage
readAt
resolvedAt
resolvedBy
resolutionReason
```

Esto ayuda a auditar:

- si se creó o no el recordatorio,
- si el paciente tenía token FCM,
- si el admin vio la alerta,
- quién confirmó la cita,
- cuándo se cerró la alerta.

---

## Seguridad y permisos

Reglas mínimas:

- Solo backend debe marcar recordatorios como enviados.
- Solo backend debe resolver automáticamente alertas por cambio de estado.
- Admin puede consultar alertas operativas.
- Admin puede resolver manualmente solo cuando corresponda según flujo.
- Paciente solo puede consultar sus propias notificaciones.
- Cliente no debe poder falsificar estados como `sent`, `resolved` o `cancelled`.
- Las Cloud Functions deben validar permisos, estado actual y versión de cita.

---

## Servicios sugeridos

Borlty debe implementar o preparar:

- `ScheduledNotificationModel`
- `ScheduledNotificationsRepository`
- `ReminderSchedulerService`
- `PatientNotificationService`
- `AdminDashboardAlertService`
- Cloud Function para sincronizar notificaciones al crear cita
- Cloud Function para resincronizar al reprogramar o cambiar estado
- Cloud Scheduler Function para procesar pendientes
- validaciones de zona horaria
- lógica de resolución de alerta al confirmar cita

---

## Entregables de implementación

Borlty debe entregar:

1. Modelo de notificación programada.
2. Creación automática de recordatorios al crear cita.
3. Creación automática de alerta admin si la cita queda sin confirmar.
4. Resolución automática de la alerta admin al confirmar cita.
5. Invalidación al reprogramar cita.
6. Cancelación al cancelar cita.
7. Validación de estados antes de enviar o activar.
8. Canal app funcional para paciente.
9. Dashboard con alerta visible para admin.
10. Llave idempotente anti-duplicados.
11. Logs de intento, lectura y resolución.
12. Seguridad para impedir manipulación desde cliente.
13. Validación manual con mínimo:
    - cita creada con más de 24h,
    - cita creada con menos de 24h,
    - cita creada con menos de 1h,
    - cita creada en estado confirmada,
    - cita creada en estado programada,
    - cita confirmada por admin,
    - cita reprogramada,
    - cita cancelada,
    - cita completada,
    - cita no asistida,
    - recordatorio duplicado bloqueado,
    - alerta admin duplicada bloqueada.

---

## Riesgos

- Duplicados si no hay idempotencia.
- Recordatorios enviados sobre citas canceladas o reprogramadas.
- Alertas admin que no se cierran al confirmar.
- Alertas admin invisibles o mal ubicadas en el dashboard.
- Fallos por zona horaria.
- Tokens FCM vencidos o inexistentes.
- Notificaciones viejas activas por mala sincronización.
- Confirmaciones hechas sin dejar trazabilidad.

---

## Decisiones para validar con la doctora / jefe

- Si la confirmación de cita la hace solo admin o también paciente.
- Si el paciente debe recibir aviso cuando la cita quede confirmada.
- Cuándo una alerta admin pasa a urgente.
- Si habrá campana de notificaciones además del widget en dashboard.
- Si el dashboard mostrará solo pendientes o también historial resuelto.
- Si las alertas admin podrán posponerse o solo resolverse.
- Cada cuánto correrá el procesador de recordatorios.

---

## Criterio de aceptación del Bloque 04

El bloque se considera terminado cuando:

- Al crear una cita válida se programan correctamente los recordatorios del paciente.
- Si la cita queda `programada`, el admin ve una alerta dentro del dashboard.
- Si el admin confirma la cita, la alerta desaparece o queda resuelta.
- El paciente puede recibir la confirmación de la cita dentro de la app.
- Al reprogramar se invalidan las notificaciones anteriores y se crean nuevas.
- Al cancelar no se envían recordatorios pendientes.
- No se crean recordatorios retroactivos.
- No se generan duplicados.
- El backend valida estado actual antes de enviar o mantener una alerta activa.
- Existe trazabilidad completa por recordatorio y por alerta administrativa.
- Todo el bloque funciona sin depender de WhatsApp.
