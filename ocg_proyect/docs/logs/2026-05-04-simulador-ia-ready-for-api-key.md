# Simulador IA ready for API key

Fecha: 2026-05-04

## Archivos auditados

### Flutter
- `lib/features/patients/presentation/patient_detail_screen.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/simulator/presentation/patient_simulations_screen.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/features/simulator/data/models/simulation_model.dart`
- `lib/app/router/app_router.dart`
- `lib/shared/utils/ui_formatters.dart`

### Functions
- `functions/src/simulator/generate_smile_simulation.ts`
- `functions/src/simulator/generate_smile_simulation_core.ts`
- `functions/src/simulator/simulator_config.ts`
- `functions/src/simulator/build_smile_prompt.ts`

## Flujo confirmado

Flujo principal correcto:

1. Detalle del paciente → botón rápido **Tomar foto**.
2. Eso abre el flujo del tab **Simulador** y dispara cámara móvil.
3. Se sube la foto original a Storage.
4. Se crea documento de simulación en `patients/{patientId}/simulations/{simulationId}` con estado `draft`.
5. Admin puede generar con `generateSmileSimulation`.
6. Estados soportados y auditados:
   - `draft`
   - `generating`
   - `ready`
   - `failed`
   - `shared`
   - `archived`
7. Admin ve historial completo en el tab Simulador.
8. Paciente ve solo simulaciones compartidas.
9. Admin puede tomar nueva foto desde el tab Simulador.
10. Admin puede compartir o dejar sin compartir con paciente.

## Confirmación de navegación/UI

- No se encontró un tab principal viejo de **Fotos** como flujo dominante del simulador.
- El flujo visible y coherente es: **Detalle paciente → Tomar foto → Simulador**.
- El tab paciente/admin relevante es **Simulador**.

## Robustez sin API KEY real

Cuando falta configuración backend:

- falta `OPENAI_API_KEY` → mensaje claro:
  - `El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.`
- `AI_SIMULATOR_ENABLED` desactivado → mensaje claro:
  - `El simulador IA está instalado, pero está desactivado en Firebase Functions.`

Esto evita:
- loading infinito en la UI;
- error técnico críptico al admin;
- botón engañoso sin feedback.

## Pruebas agregadas

### Functions
- `functions/test/generate_smile_simulation_core.test.mjs`
  - sin API KEY → error controlado;
  - simulador deshabilitado → no llama OpenAI;
  - sin `originalPath` → falla claro;
  - intentos máximos → bloquea;
  - usuario no admin → bloquea;
  - flujo exitoso mockeado → `ready`, `resultPath`, `promptUsed`, `promptVersion`, `modelUsed`.

### Flutter
- `test/features/simulator/simulator_provider_test.dart`
  - mapea falta de API KEY a mensaje claro;
  - mapea simulador deshabilitado a mensaje claro.

## Comandos ejecutados

- `flutter analyze`
- `flutter test test/features/simulator/`
- `cd functions && npm run build`
- `cd functions && node --test test/generate_smile_simulation_core.test.mjs`

## Pendiente por intervención humana

- configurar `OPENAI_API_KEY`;
- activar `AI_SIMULATOR_ENABLED`;
- definir modelo final (`OPENAI_IMAGE_MODEL` si cambia);
- hacer prueba real con foto;
- validar webhook/flujo externo real con OpenAI ya configurado.

## Nota de alcance

No se usó OpenAI real, no se desplegó Functions y no se tocaron credenciales reales.
