# Bloque 04 — Recordatorios automáticos de citas por WhatsApp y app

## Objetivo

Enviar recordatorios automáticos de citas por dos canales:

- WhatsApp
- aplicación

Momentos obligatorios:
- 1 día antes de la cita
- 1 hora antes de la cita

## Qué entendemos del negocio

Los recordatorios no serán manuales. Deben programarse y enviarse automáticamente cuando exista una cita válida.

## Eventos de negocio que afectan recordatorios

- crear cita
- reprogramar cita
- cancelar cita
- marcar no asistió
- completar cita

## Reglas funcionales

### 1. Al crear una cita
El sistema debe dejar programados dos recordatorios:
- recordatorio T-24h
- recordatorio T-1h

### 2. Si la cita se reprograma
- los recordatorios anteriores deben invalidarse o marcarse como obsoletos
- deben programarse nuevos recordatorios según la nueva fecha

### 3. Si la cita se cancela
- no debe enviarse ningún recordatorio posterior

### 4. Si faltan menos de 24 horas al crear la cita
- ya no aplica el recordatorio de 1 día antes
- sí puede aplicar el de 1 hora antes si aún está a tiempo

### 5. Si faltan menos de 1 hora al crear la cita
- no programar recordatorio tardío
- evitar notificaciones absurdas o retroactivas

## Canales

### App
Esto encaja con push notification o notificación local/remota según la arquitectura actual.

### WhatsApp
Aquí hace falta un integrador/servicio definido. El sistema debe dejar listo el payload del mensaje y un mecanismo backend para enviarlo.

## Mensajes sugeridos

### 1 día antes
"Hola, {nombrePaciente}. Te recordamos tu cita en OCG Clínica mañana a las {hora}. Si necesitas reprogramar, contáctanos a tiempo."

### 1 hora antes
"Hola, {nombrePaciente}. Tu cita en OCG Clínica es en 1 hora, a las {hora}. Te esperamos."

## Arquitectura sugerida

### Opción recomendada
Programar recordatorios desde backend al momento de crear/reprogramar la cita.

Se puede manejar con una colección tipo `scheduled_notifications` o equivalente, con workers/Cloud Functions que:
- registran el evento
- validan estado de la cita antes de enviar
- evitan duplicados

## Datos sugeridos para cada recordatorio

- `appointmentId`
- `patientId`
- `channel` (`whatsapp`, `push`)
- `kind` (`day_before`, `hour_before`)
- `scheduledFor`
- `status` (`pending`, `sent`, `cancelled`, `failed`, `obsolete`)
- `payloadSnapshot`
- `createdAt`
- `updatedAt`

## Reglas anti-duplicado

- no reenviar el mismo recordatorio más de una vez por canal y tipo
- validar estado actual de la cita antes de enviar
- si la cita ya fue cancelada/reprogramada/completada, abortar envío

## Dependencias funcionales

Este bloque depende de tener estable:
- módulo de citas
- datos confiables de paciente y teléfono
- canal de push app
- integración real para WhatsApp

## UI admin sugerida

No hace falta una pantalla compleja al inicio, pero sí sería útil mostrar:
- si la cita tiene recordatorios automáticos activos
- último intento de envío
- estado del recordatorio

## Riesgos

- duplicados si no se modela bien reprogramación
- mensajes enviados sobre citas canceladas
- dependencia externa del proveedor de WhatsApp
- problemas de zona horaria si no se normaliza correctamente

## Entregables sugeridos

- diseño técnico del scheduler de recordatorios
- modelo de recordatorio programado
- disparo al crear/reprogramar/cancelar cita
- integración push app
- integración WhatsApp
- logging y estados de entrega

## Decisiones para validar

- proveedor oficial de WhatsApp a usar
- si el número destino será el del paciente o acudiente configurable
- si el admin podrá desactivar recordatorios por cita excepcionalmente
- si habrá plantillas editables o textos fijos inicialmente
