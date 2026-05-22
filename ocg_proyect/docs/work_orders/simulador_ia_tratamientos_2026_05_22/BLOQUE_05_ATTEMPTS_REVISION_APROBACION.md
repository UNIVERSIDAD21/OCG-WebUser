# BLOQUE 05 - Attempts, revision y aprobacion del doctor

## Objetivo

Agregar historial de intentos y aprobacion humana antes de compartir.

La IA no debe publicar directo al paciente. El doctor/admin debe aprobar el resultado.

## Estado actual

La Function:

- marca simulacion en `generating`;
- incrementa `attemptCount`;
- genera imagen;
- guarda `result.jpg`;
- marca `status = ready`;
- pone `compartidaConPaciente = false`.

Flutter:

- permite regenerar desde `ready`;
- comparte desde `ready`;
- no distingue intento aprobado/rechazado;
- no guarda resultados anteriores.

## Archivos a tocar

Flutter:

- `lib/features/simulator/data/models/simulation_model.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `test/features/simulator/*`

Functions:

- `functions/src/simulator/generate_smile_simulation_core.ts`
- `functions/src/simulator/generate_smile_simulation.ts`

Rules despues o en bloque 06:

- `firestore.rules`
- `storage.rules`

## Firestore nuevo

Mantener documento principal:

```text
patients/{patientId}/simulations/{simulationId}
```

Agregar subcoleccion:

```text
patients/{patientId}/simulations/{simulationId}/attempts/{attemptId}
```

Estructura de attempt:

```json
{
  "id": "attempt_1",
  "attemptNumber": 1,
  "status": "ready",
  "resultPath": "simulations/p1/s1/attempts/attempt_1/result.jpg",
  "treatmentProfileId": "metal_braces",
  "visualGoal": "show_appliance",
  "doctorConfig": {},
  "photoQuality": {},
  "promptVersion": "ocg-dental-treatment-v2",
  "modelUsed": "gpt-image-2",
  "generationProvider": "openai",
  "errorMessage": null,
  "reviewStatus": "pending",
  "rejectionReason": null,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Documento principal debe guardar:

```json
{
  "attemptCount": 1,
  "approvedAttemptId": null,
  "doctorReviewStatus": "pending",
  "resultPath": "simulations/p1/s1/result.jpg"
}
```

## Storage

Guardar resultado de intento en:

```text
simulations/{patientId}/{simulationId}/attempts/{attemptId}/result.jpg
```

Mantener copia activa en:

```text
simulations/{patientId}/{simulationId}/result.jpg
```

Motivo:

- `result.jpg` no rompe el comparador actual.
- `attempts/.../result.jpg` conserva historial.

## Backend

En `processGenerateSmileSimulation`:

1. Calcular `nextAttemptCount`.
2. Crear `attemptId = attempt_${nextAttemptCount}`.
3. Crear attempt con `status = generating`.
4. Marcar simulacion principal `generating`.
5. Generar con OpenAI.
6. Guardar resultado en path de attempt.
7. Copiar/guardar tambien en `result.jpg`.
8. Actualizar attempt a `ready`.
9. Actualizar simulacion principal:
   - `status = ready`
   - `doctorReviewStatus = pending`
   - `approvedAttemptId = null`
   - `resultPath = result.jpg`
   - `attemptCount = nextAttemptCount`

Si falla:

- attempt `status = failed`;
- simulacion `status = failed`;
- `errorMessage` sanitizado.

Si falla antes de llamar OpenAI por preflight:

- no incrementar intento;
- no crear attempt listo;
- devolver error controlado.

## Flutter

Agregar acciones en resultado:

- Aprobar resultado.
- Rechazar y regenerar.
- Regenerar con ajustes.
- Compartir solo si aprobado.

Estados:

```text
ready + pending: "Resultado pendiente de revision"
ready + approved: "Resultado aprobado"
ready + rejected: "Resultado rechazado"
shared + approved: visible al paciente
```

## Repository Flutter

Agregar:

```dart
Future<void> approveSimulationAttempt({
  required String patientId,
  required String simulationId,
  required String attemptId,
});

Future<void> rejectSimulationAttempt({
  required String patientId,
  required String simulationId,
  required String attemptId,
  required String reason,
});
```

Si no se implementa UI para lista de attempts en esta fase, usar `approvedAttemptId` y el ultimo attempt listo.

## Compartir

Modificar `shareSimulationWithPatient`:

- Solo permitir si `doctorReviewStatus == approved`.
- Solo permitir si `resultPath` existe.
- Si no esta aprobado, lanzar error controlado.

Esto tambien se refuerza en UI.

## Restricciones

- No mostrar attempts al paciente.
- No borrar intentos anteriores al regenerar.
- No compartir en `pending` o `rejected`.
- No cambiar `status` a `shared` desde Functions.
- No aumentar `MAX_SIMULATION_ATTEMPTS` sin decision de producto.

## Tests requeridos

Functions:

- Generacion crea attempt.
- Success actualiza attempt y doc principal.
- Failure marca attempt failed y doc principal failed.
- Preflight rejected no incrementa attempt.

Flutter:

- `ready + pending` no muestra compartir.
- Aprobar habilita compartir.
- Rechazar mantiene no compartible.
- Regenerar conserva intentos anteriores segun contrato.
- `shareSimulationWithPatient` falla si no aprobado.

## Criterios de cierre

- Cada generacion real crea un attempt.
- El resultado activo sigue visible en `result.jpg`.
- El admin debe aprobar antes de compartir.
- El paciente no ve intentos.
- `flutter test test/features/simulator` pasa.
- `npm run build` pasa.

## Resultado esperado

El simulador queda clinicamente controlado: IA genera, doctor revisa, solo lo aprobado llega al paciente.
