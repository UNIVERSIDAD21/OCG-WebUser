# OCG QA — Ejecución de Matriz

Base: `docs/qa/OCG_QA_Matriz_Pruebas_Completa.md`

## Estado general

- Inicio: 2026-04-10
- Responsable: Borlty
- Estado: En ejecución

## Convención

- Pendiente
- OK
- Falló
- Bloqueado

## Bloques de ejecución

1. Autenticación y guards
2. Admin Pacientes
3. Admin Agenda
4. Paciente Citas / Pagos / Perfil
5. Tratamiento admin/paciente
6. Simulador
7. Regresión + Responsive

## Registro de avance

| Bloque | Estado | Observaciones |
|---|---|---|
| 1. Autenticación y guards | En progreso | Inicio de ejecución |
| 2. Admin Pacientes | Pendiente |  |
| 3. Admin Agenda | Pendiente |  |
| 4. Paciente Citas/Pagos/Perfil | Pendiente |  |
| 5. Tratamiento admin/paciente | Pendiente |  |
| 6. Simulador | Pendiente |  |
| 7. Regresión + Responsive | Pendiente |  |

## Evidencia

Crear subcarpetas por bloque en `docs/qa/evidencia/`:

- `docs/qa/evidencia/01-auth/`
- `docs/qa/evidencia/02-admin-pacientes/`
- `docs/qa/evidencia/03-admin-agenda/`
- `docs/qa/evidencia/04-paciente/`
- `docs/qa/evidencia/05-tratamiento/`
- `docs/qa/evidencia/06-simulador/`
- `docs/qa/evidencia/07-regresion-responsive/`

## Notas de ejecución

- Se ejecutará primero la sección bloqueante del bloque 1.
- Cada fallo abrirá registro con: ID de prueba, pasos, esperado, obtenido y evidencia.
