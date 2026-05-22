# Simulador IA de tratamientos dentales - Indice y estado actual

Fecha: 2026-05-22  
Proyecto Firebase objetivo: `ocg-humanbionics`  
Modelo IA unico: `gpt-image-2`  
Function principal existente: `generateSmileSimulation`

## Objetivo de esta carpeta

Dividir la evolucion del simulador en bloques ejecutables por un agente de programacion.

Cada bloque debe avanzar un paso concreto para que al final el simulador:

- diferencie visualmente brackets metalicos, brackets esteticos, alineadores, blanqueamiento, carillas, diseno de sonrisa, expansor y retenedor;
- use solo `gpt-image-2`;
- conserve el comparador antes/despues actual;
- permita al admin configurar, generar, revisar, aprobar y compartir;
- deje al paciente solo con la comparacion antes/despues compartida;
- evite generar cuando la foto no sirve;
- mantenga seguridad de Firebase y no exponga secretos.

## Estado actual encontrado en codigo

### Ya existe y se debe reutilizar

- Modelo Flutter:
  - `lib/features/simulator/data/models/simulation_model.dart`
  - Estados: `draft`, `generating`, `ready`, `shared`, `failed`, `archived`.
  - Campos actuales importantes: `originalPath`, `resultPath`, `treatmentType`, `generationProvider`, `modelUsed`, `attemptCount`, `promptUsed`, `promptVersion`, `mlKitUsed`, `detectedRegion`, `promptMetadata`, `fechaCompartida`.

- Repositorio Flutter:
  - `lib/features/simulator/data/repositories/simulation_repository.dart`
  - Crea drafts.
  - Sube original a Storage.
  - Invoca callable `generateSmileSimulation`.
  - Comparte/descomparte.
  - Archiva y elimina.

- Provider Flutter:
  - `lib/features/simulator/providers/simulation_provider.dart`
  - Maneja flujo `idle/pickingImage/draftReady/generating/ready/shared/saving/saved/error`.
  - Escucha en tiempo real el documento de simulacion.
  - Usa `ImagePickerService` y `FaceDetectionService`.

- UI admin:
  - `lib/features/simulator/presentation/simulator_screen.dart`
  - `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
  - Ya muestra foto original, resultado, estados y botones de generar/regenerar/compartir/archivar.

- UI paciente:
  - `lib/features/simulator/presentation/patient_simulations_screen.dart`
  - Consume `sharedSimulationsProvider`.
  - Usa `BeforeAfterSlider`.

- Widget antes/despues:
  - `lib/shared/widgets/before_after_slider.dart`

- Backend Functions:
  - `functions/src/simulator/generate_smile_simulation.ts`
  - `functions/src/simulator/generate_smile_simulation_core.ts`
  - `functions/src/simulator/build_smile_prompt.ts`
  - `functions/src/simulator/simulator_config.ts`
  - Ya llama OpenAI `images.edit`.
  - Ya usa `gpt-image-2`.
  - Ya guarda `simulations/{patientId}/{simulationId}/result.jpg`.

- Rutas:
  - Firestore: `patients/{patientId}/simulations/{simulationId}`
  - Storage: `simulations/{patientId}/{simulationId}/original.jpg`
  - Storage: `simulations/{patientId}/{simulationId}/result.jpg`

- Reglas:
  - `firestore.rules` protege simulaciones por admin/paciente compartido.
  - `storage.rules` permite lectura admin o paciente con simulacion `shared`.

### Validacion local corrida antes de crear estos bloques

Desde `ocg_proyect/functions`:

```bash
npm run build
```

Resultado: OK.

Desde `ocg_proyect`:

```bash
flutter test test/features/simulator
```

Resultado: OK, 16 tests pasan.

Desde `ocg_proyect`:

```bash
flutter analyze
```

Resultado: falla por 17 issues existentes fuera del simulador o no especificos del simulador. Se deben limpiar antes del cierre final si se exige `flutter analyze` limpio.

Issues observados:

- `lib/features/admin/presentation/web/components/section_panel.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/consultation/providers/consultation_provider.dart`
- `lib/features/dashboard/presentation/admin_modules_screens.dart`
- `lib/features/dashboard/presentation/patient_appointments_screen.dart`
- `lib/features/migration/legacy_migration_service.dart`
- `lib/features/migration/providers/legacy_migration_provider.dart`
- `lib/shared/widgets/ocg_adaptive_scaffold.dart`
- `test/features/migration/legacy_migration_service_test.dart`

## Lo que falta

El simulador actual sigue siendo demasiado generico porque:

- Solo manda `treatmentType` como texto.
- No existe `treatmentProfileId`.
- No existe `doctorConfig`.
- No existe formulario dinamico por tratamiento.
- No existe `photoQuality` estructurado.
- No existe validacion fuerte de compatibilidad foto/tratamiento.
- No existe subcoleccion de intentos.
- No existe aprobacion explicita del doctor.
- El paciente aun puede ver metadatos tecnicos como provider/modelo/notas.
- El prompt actual no tiene perfiles por tratamiento.
- Storage rules no cubren rutas anidadas de intentos si se agregan.

## Regla central de arquitectura

No reconstruir el simulador desde cero.

La base actual funciona y debe evolucionarse asi:

```text
Draft existente
-> agregar contrato de perfiles
-> agregar UI de configuracion
-> agregar prompt profiles
-> agregar preflight
-> agregar attempts y aprobacion
-> limpiar vista paciente y reglas
-> QA/deploy/E2E
```

## Orden de ejecucion

1. [BLOQUE_01_CONTRATO_DATOS_COMPATIBILIDAD.md](BLOQUE_01_CONTRATO_DATOS_COMPATIBILIDAD.md)
2. [BLOQUE_02_BACKEND_PROMPT_PROFILES.md](BLOQUE_02_BACKEND_PROMPT_PROFILES.md)
3. [BLOQUE_03_UI_ADMIN_CONFIGURACION_TRATAMIENTO.md](BLOQUE_03_UI_ADMIN_CONFIGURACION_TRATAMIENTO.md)
4. [BLOQUE_04_PREFLIGHT_FOTO_COMPATIBILIDAD.md](BLOQUE_04_PREFLIGHT_FOTO_COMPATIBILIDAD.md)
5. [BLOQUE_05_ATTEMPTS_REVISION_APROBACION.md](BLOQUE_05_ATTEMPTS_REVISION_APROBACION.md)
6. [BLOQUE_06_PACIENTE_COMPARTIR_SEGURIDAD.md](BLOQUE_06_PACIENTE_COMPARTIR_SEGURIDAD.md)
7. [BLOQUE_07_QA_DEPLOY_E2E.md](BLOQUE_07_QA_DEPLOY_E2E.md)

## Reglas para todos los bloques

- No leer ni imprimir `OPENAI_API_KEY`.
- No poner API keys en Flutter.
- No subir secretos al repo.
- No cambiar de modelo: siempre `gpt-image-2`.
- No agregar otro proveedor IA.
- No romper `BeforeAfterSlider`.
- No cambiar la ruta principal `patients/{patientId}/simulations/{simulationId}`.
- No mostrar intentos rechazados al paciente.
- No compartir automaticamente resultados IA.
- Mantener compatibilidad de lectura con simulaciones existentes.
- Agregar tests proporcionales al cambio.
- Si se cambia Storage o Firestore, revisar reglas y tests relacionados.

## Comandos de validacion base

Desde `ocg_proyect`:

```bash
flutter analyze
flutter test test/features/simulator
```

Desde `ocg_proyect/functions`:

```bash
npm run build
```

Para deploy al cierre, despues de validar:

```bash
firebase --project ocg-humanbionics deploy --only functions:generateSmileSimulation
```
