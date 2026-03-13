# Estrategia de Testing – Módulo de Agenda (OCG)

## 1) Mapa de riesgos (prioridad)

### P0 (crítico negocio)
- Doble reserva bajo concurrencia.
- Solapes inválidos por buffer/duración.
- Reprogramación deja cita vieja visible en agenda operativa.
- Cancelación no libera disponibilidad correctamente.
- Estado inválido (transiciones no permitidas).

### P1 (alto)
- Horario laboral mal aplicado.
- Tipo de cita no permitido para paciente.
- Próxima cita del paciente desincronizada.
- Recordatorios duplicados o enviados a citas canceladas.

### P2 (medio)
- Mensajes UX inconsistentes en errores de reserva.
- Filtros de tabs con mezclas entre operativo/histórico.

## 2) Estrategia por capas

## Unit tests (Dart)
Objetivo: reglas de dominio puras.
- `appointments_business_rules_test.dart`
  - horario laboral
  - conflictos con buffer
  - estados operativos vs históricos
  - slots diarios

## Integración (Repository + Firestore emulator)
Objetivo: consultas y persistencia coherente.
- `AppointmentsRepository.watchAppointmentsByDate` excluye históricos.
- `rescheduleAppointment` marca original y crea nueva.
- `_updatePatientNextAppointment` actualizado en create/cancel/reprogramar.

## Widget tests (Flutter)
Objetivo: flujos críticos visibles.
- paciente agendar cita muestra solo disponibilidad agregada.
- conflicto de slot devuelve feedback claro.
- cancelación <24h abre flujo WhatsApp (éxito y fallback).

## Backend tests (Functions)
Objetivo: atomicidad/seguridad de servidor.
- `reserveAppointment` rechaza tipo no permitido paciente.
- rechaza fuera de horario.
- detecta conflictos bajo concurrencia.
- trigger `onAppointmentWrite` reconstruye availability del día.

## 3) Casos priorizados

### P0
1. 20 requests concurrentes al mismo slot => 1 éxito, 19 rechazo.
2. Cita 8:00 (30 + buffer 10) bloquea 8:30 y libera 8:40.
3. Reprogramar: original pasa a `reprogramada` y desaparece de agenda operativa.
4. Cancelar: ya no aparece en agenda operativa.

### P1
5. Paciente intenta tipo `urgencia` => backend denied.
6. Reserva a 17:10 => rejected.
7. Cita del paciente actualiza `proximaCita` en su documento.

## 4) Mocks/Fakes recomendados
- `fake_cloud_firestore` para integración de repositorios.
- wrapper de `FirebaseFunctions` mockeable para llamadas callable.
- fakes de tiempo (`DateTime` inyectable) para horarios/recordatorios.

## 5) Criterios de aceptación mínimos (go-live)
- 100% de pruebas P0 en verde.
- 0 test flaky en 10 corridas consecutivas CI.
- cobertura de dominio agenda >= 80% en reglas puras.
- suite backend de reservas y conflictos en verde en emulator.

## 6) Errores críticos que podrían escaparse sin esta suite
- doble booking silencioso.
- agenda operativa mostrando citas históricas.
- reprogramaciones dejando huérfanos de disponibilidad.
- WhatsApp fallback roto sin feedback al paciente.
- próxima cita inconsistente entre admin/paciente.
