# BLOQUE 06 - Vista paciente, compartir y seguridad

## Objetivo

Dejar la experiencia del paciente simple y segura: solo comparacion antes/despues compartida.

Tambien ajustar Firestore/Storage rules para los nuevos fields y rutas de attempts.

## Estado actual

Vista paciente:

- `lib/features/simulator/presentation/patient_simulations_screen.dart`
- Muestra comparador antes/despues.
- Tambien muestra `status`, `generationProvider`, `modelUsed` y notas.

Reglas actuales:

- Firestore permite al paciente leer simulacion si `compartidaConPaciente == true` y `status == shared`.
- Storage permite leer `simulations/{patientId}/{simulationId}/{fileName}` si simulacion esta compartida.

Falta:

- ocultar metadatos tecnicos al paciente;
- exigir aprobacion antes de compartir;
- cubrir Storage paths anidados `attempts/...`;
- asegurar que paciente no lea attempts directamente si no hace falta.

## Archivos a tocar

- `lib/features/simulator/presentation/patient_simulations_screen.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `firestore.rules`
- `storage.rules`
- `test/features/simulator/simulator_mobile_flow_test.dart`
- tests de rules si existen o validacion manual documentada.

## Vista paciente objetivo

El paciente debe ver:

- titulo simple: `Simulacion de sonrisa`;
- fecha;
- comparador antes/despues;
- disclaimer orientativo.

El paciente no debe ver:

- `generationProvider`;
- `modelUsed`;
- `promptVersion`;
- `promptUsed`;
- `doctorConfig`;
- `photoQuality`;
- `attemptCount`;
- `errorMessage`;
- notas internas del doctor si se consideran clinicas;
- intents rechazados o pendientes;
- botones de generar/regenerar/aprobar/archivar.

## Admin: compartir

En admin, el boton compartir debe estar disponible solo si:

```text
status == ready
doctorReviewStatus == approved
resultPath existe
compartidaConPaciente == false
```

Si no esta aprobado, mostrar accion:

```text
Aprobar resultado antes de compartir
```

No permitir compartir desde cards del historial si falta aprobacion.

## Firestore rules

Mantener:

```rules
match /patients/{patientId}/simulations/{simulationId} {
  allow read: if isAdmin() ||
    (
      isOwnPatient(patientId) &&
      resource.data.compartidaConPaciente == true &&
      resource.data.status == 'shared'
    );
  allow create, update, delete: if isAdmin();
}
```

Agregar subcoleccion attempts:

```rules
match /patients/{patientId}/simulations/{simulationId}/attempts/{attemptId} {
  allow read: if isAdmin();
  allow create, update, delete: if isAdmin();
}
```

Decision: el paciente no necesita leer attempts. Lee solo el `resultPath` aprobado del doc principal.

## Storage rules

Regla actual solo cubre:

```text
simulations/{patientId}/{simulationId}/{fileName}
```

Agregar ruta anidada:

```rules
match /simulations/{patientId}/{simulationId}/{allPaths=**} {
  allow read: if isAdmin() || canReadSharedSimulation(patientId, simulationId);
  allow write: if isAdmin();
}
```

Si se reemplaza la regla anterior, asegurar que no abre acceso a otros pacientes.

Nota: aunque attempts queden bajo `allPaths`, el paciente solo tendra URL si el cliente se la pide. La UI paciente debe resolver solo `originalPath` y `resultPath` del doc principal compartido.

## Repositorio

`watchSharedSimulations` debe seguir filtrando:

```dart
.where('compartidaConPaciente', isEqualTo: true)
.where('status', isEqualTo: SimulationStatus.shared.name)
```

Opcional despues de bloque 05:

- tambien validar `doctorReviewStatus == approved` si hay indice disponible.

Si se agrega filtro nuevo, revisar Firestore index.

## Restricciones

- No mostrar prompts ni metadata al paciente.
- No permitir paciente escribir simulaciones.
- No permitir paciente leer attempts.
- No descompartir borrando imagen; solo cambiar metadata.
- No eliminar simulaciones por defecto; archivar es preferible.

## Tests requeridos

Flutter:

- Paciente no ve `openai`, `gpt-image-2`, `promptVersion` ni notas internas.
- Paciente ve `BeforeAfterSlider` cuando hay `shared`.
- Paciente no ve simulaciones `ready` no compartidas.
- Admin no puede compartir si `doctorReviewStatus != approved`.

Rules/manual:

- Paciente puede leer doc shared propio.
- Paciente no puede leer doc ready propio no shared.
- Paciente no puede leer doc de otro paciente.
- Admin puede leer/escribir.
- Paciente no puede leer attempts.
- Storage permite leer `original.jpg` y `result.jpg` solo si doc shared.

## Criterios de cierre

- Vista paciente queda limpia y solo con antes/despues.
- Compartir exige aprobacion.
- Rules cubren attempts y rutas anidadas sin abrir datos.
- `flutter test test/features/simulator` pasa.

## Resultado esperado

La experiencia paciente queda como se definio: simple, controlada y sin informacion interna del proceso IA.
