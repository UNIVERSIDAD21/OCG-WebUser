# BLOQUE 01 - Contrato de datos y compatibilidad

## Objetivo

Extender el contrato de simulaciones sin romper lo que ya existe.

Este bloque prepara Flutter, Firestore y Storage para tratamientos diferenciados, pero no debe implementar todavia la UI completa ni la generacion avanzada.

## Estado actual

`SimulationModel` ya existe y funciona con:

- `treatmentType` basado en `TreatmentType` de paciente.
- `promptMetadata` como mapa generico.
- `attemptCount`.
- `status`.
- `generationProvider`.
- `modelUsed`.

Faltan campos explicitos para:

- perfil dental elegido;
- objetivo visual;
- configuracion del doctor;
- calidad de foto;
- aprobacion del doctor;
- intento aprobado.

## Archivos a tocar

- `lib/features/simulator/data/models/simulation_model.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/shared/constants/storage_paths.dart`
- `test/features/simulator/simulation_model_test.dart`
- `test/features/simulator/simulation_repository_test.dart`
- `test/features/simulator/simulator_provider_test.dart`

## Campos nuevos recomendados

Agregar a `SimulationModel`:

```dart
final String? treatmentProfileId;
final String? visualGoal;
final Map<String, dynamic>? doctorConfig;
final Map<String, dynamic>? photoQuality;
final String doctorReviewStatus; // pending | approved | rejected
final String? approvedAttemptId;
```

Defaults:

```text
treatmentProfileId = null
visualGoal = null
doctorConfig = null
photoQuality = null
doctorReviewStatus = pending
approvedAttemptId = null
```

## Compatibilidad obligatoria

La lectura de documentos viejos debe seguir funcionando.

Reglas:

- Si no existe `doctorReviewStatus`, usar `pending`.
- Si no existe `treatmentProfileId`, inferir desde `treatmentType` solo como fallback visual, no como dato canonico.
- No eliminar `treatmentType`; aun se usa para compatibilidad con paciente/tratamiento.
- No eliminar `promptMetadata`; puede seguir guardando metadata adicional.
- `toJson()` debe escribir los campos nuevos cuando existan.

## StoragePaths nuevos

Agregar helpers:

```dart
static String simulationAttemptResult(
  String patientId,
  String simulationId,
  String attemptId,
) => 'simulations/$patientId/$simulationId/attempts/$attemptId/result.jpg';

static String simulationArtifact(
  String patientId,
  String simulationId,
  String name,
) => 'simulations/$patientId/$simulationId/artifacts/$name';
```

No reemplazar:

- `simulationOriginal`
- `simulationResult`
- `simulationThumbOriginal`
- `simulationThumbResult`

## Repository

Extender `createDraftSimulation` con parametros opcionales:

```dart
String? treatmentProfileId,
String? visualGoal,
Map<String, dynamic>? doctorConfig,
Map<String, dynamic>? photoQuality,
String doctorReviewStatus = 'pending',
String? approvedAttemptId,
```

Extender `updateSimulation` con los mismos campos y clear flags donde aplique.

Extender `generateWithAi` para aceptar:

```dart
String? treatmentProfileId,
String? visualGoal,
Map<String, dynamic>? doctorConfig,
Map<String, dynamic>? photoQuality,
```

Payload hacia callable:

```dart
{
  'patientId': patientId,
  'simulationId': simulationId,
  'treatmentType': treatmentType, // compatibilidad
  'treatmentProfileId': treatmentProfileId,
  'visualGoal': visualGoal,
  'doctorConfig': doctorConfig,
  'photoQuality': photoQuality,
  'notes': notes,
}
```

## Provider

Agregar a `SimulatorFlowState`:

```dart
final String? treatmentProfileId;
final String? visualGoal;
final Map<String, dynamic>? doctorConfig;
final Map<String, dynamic>? photoQuality;
final String doctorReviewStatus;
final String? approvedAttemptId;
```

Actualizar:

- constructor;
- `copyWith`;
- `_applySimulation`;
- `generateWithAi`;
- tests fake.

## Restricciones

- No implementar aun formulario dinamico.
- No implementar aun prompt profiles.
- No implementar aun attempts.
- No cambiar flujo visual del paciente.
- No cambiar reglas en este bloque salvo que sea estrictamente necesario.

## Tests requeridos

Actualizar `simulation_model_test.dart`:

- serializa/deserializa campos nuevos;
- documento legacy sin campos nuevos usa defaults;
- `doctorConfig` y `photoQuality` aceptan mapas.

Actualizar `simulation_repository_test.dart`:

- `createDraftSimulation` guarda campos nuevos si se entregan;
- `updateSimulation` actualiza `doctorReviewStatus`;
- `generateWithAi` envia payload nuevo en fake/mock si el test lo permite.

Actualizar `simulator_provider_test.dart`:

- `_applySimulation` propaga `treatmentProfileId`, `doctorConfig`, `photoQuality`.

## Criterios de cierre

- `flutter test test/features/simulator` pasa.
- El modelo sigue leyendo documentos legacy.
- El flujo actual de generar con IA sigue funcionando aunque no se envie `treatmentProfileId`.
- `npm run build` no debe romperse si en este bloque no se toca Functions.

## Resultado esperado

El proyecto queda listo para que los siguientes bloques usen configuracion dental estructurada sin rehacer el modelo otra vez.
