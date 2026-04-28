# Registro Simulador GPT-Image-2

## Objetivo
Implementar el simulador de sonrisa usando únicamente GPT-Image-2, sin modo mock y sin modo manual_doctora.

## Arquitectura definida
Flutter → Firebase Cloud Functions → OpenAI GPT-Image-2 → Firebase Storage → Firestore → Flutter

## Accesos necesarios
- Repositorio: Disponible localmente en `/home/borlty/OCG-WebUser` y con remoto GitHub configurado.
- Firebase Project ID: Pendiente de confirmación explícita para este flujo del simulador.
- Firebase Auth: Pendiente de validar reglas, proveedores activos y permisos necesarios para el flujo.
- Firestore: Pendiente de validar estructura de colecciones/documentos del simulador y permisos.
- Firebase Storage: Pendiente de validar bucket, rutas objetivo y permisos.
- Cloud Functions: Pendiente de validar runtime, región, estructura actual y permisos de despliegue.
- Firebase CLI: Disponible en el entorno, pero pendiente validar proyecto activo para este módulo.
- Permiso para desplegar Functions: Pendiente de confirmación operativa para este flujo.
- OpenAI API Key: No entregada en esta conversación / no validada para este proyecto.
- Variables de entorno/Secret Manager: Pendiente confirmar dónde se almacenará la OpenAI API Key (Secret Manager o equivalente seguro del proyecto).
- Paciente ficticio: No entregado.
- Imagen de prueba autorizada: No entregada.

## Bloqueos
Lista exactamente qué te falta y qué debe entregarte Erik.

1. Confirmación del **Firebase Project ID exacto** donde vivirá el Simulador de Sonrisa.
2. Confirmación de que tengo **permiso real para desplegar Cloud Functions** en ese proyecto.
3. Confirmación de la **Cloud Function existente o nueva** donde se integrará GPT-Image-2.
4. Entrega o configuración segura de la **OpenAI API Key** en backend (Secret Manager / variables seguras del entorno).
5. Confirmación de la **región** y runtime que debe usar Functions para esta integración.
6. Definición de la **ruta de Storage** donde se guardarán:
   - imagen original
   - imagen procesada
   - variantes/resultados
7. Definición de la **estructura en Firestore** para registrar solicitudes, estados, errores y resultados.
8. Un **paciente ficticio autorizado** para pruebas end-to-end.
9. Al menos una **imagen de prueba autorizada** para validar el pipeline completo.
10. Confirmación de si el flujo debe exigir autenticación por rol (doctora/admin) antes de invocar el simulador.

## Checklist para desbloquear implementación real

### Firebase
- Firebase Project ID exacto:
- Confirmar si el proyecto usa Blaze o plan compatible con Cloud Functions:
- Confirmar si tengo permiso para deploy de Functions:
- Confirmar si puedo leer/escribir Firestore:
- Confirmar si puedo leer/escribir Storage:
- Confirmar si puedo usar Firebase CLI:

### OpenAI
- API Key de OpenAI:
- Método seguro donde se guardará:
 - Secret Manager
 - Firebase Functions config
 - Variable de entorno segura
- Modelo final:
 - gpt-image-2
- Confirmar si se usará:
 - AI_SIMULATOR_ENABLED=true
 - MAX_SIMULATION_ATTEMPTS=3
 - OPENAI_IMAGE_MODEL=gpt-image-2

### Pruebas
- Paciente ficticio:
- UID del paciente ficticio:
- Admin de prueba:
- Imagen de prueba autorizada:
- Tipo de simulación inicial:
 - ortodoncia
 - alineadores
 - blanqueamiento
 - diseño de sonrisa
 - otro

### Pendientes que debe entregar Erik
- Pendiente 1: Confirmar Project ID y proyecto Firebase exacto del simulador.
- Pendiente 2: Confirmar acceso real para deploy de Functions + configuración segura de OpenAI API Key.
- Pendiente 3: Entregar paciente ficticio, admin de prueba e imagen autorizada para validación end-to-end.

## Auditoría del simulador actual

### Archivos revisados
- Archivo: `lib/features/simulator/data/models/simulation_model.dart`
- Qué hace actualmente: Define el modelo de simulación con `mode`, `status`, URLs de original/resultado, flags de compartir, metadatos de detección y notas.
- Qué se puede reutilizar: La estructura base del documento, los campos de auditoría, URLs, `promptMetadata`, `detectedRegion`, `compartidaConPaciente` y timestamps.
- Qué se debe cambiar: El enum `SimulationMode` hoy solo tiene `mock` y `manualDoctora`; el enum `SimulationStatus` no tiene `generating` ni `failed`; el modelo todavía está acoplado a flujos legacy/manuales.
- Riesgo: Medio. Cambiar enums impacta Firestore, UI, provider y compatibilidad de datos existentes.

- Archivo: `lib/features/simulator/data/repositories/simulation_repository.dart`
- Qué hace actualmente: Observa simulaciones, sube original/resultado a Storage, guarda/actualiza simulaciones, elimina simulaciones y alterna compartir con paciente.
- Qué se puede reutilizar: Watchers, subida a Storage, save/update/delete, toggleShare y rutas actuales de Storage/Firestore.
- Qué se debe cambiar: Normalización de estados, contratos del modo único `openai`, soporte explícito para `generating/failed`, persistencia de intentos/error, y dejar de asumir `resultUrl` como único criterio de transición.
- Riesgo: Medio-Alto. Es la capa central de persistencia y un cambio mal hecho rompe admin/paciente.

- Archivo: `lib/features/simulator/providers/simulation_provider.dart`
- Qué hace actualmente: Orquesta el flujo UI del simulador. Usa picker, ML Kit, servicio mock, flujo manual de doctora y guardado final.
- Qué se puede reutilizar: `patientSimulationsProvider`, `sharedSimulationsProvider`, manejo de draft, carga de imagen original, detección de región, share/notas, guardado final y estructura del notifier.
- Qué se debe cambiar: Eliminar dependencia de `MockSimulationService`, eliminar `manualDoctora`, reemplazar el flujo por uno centrado en generación backend vía Functions, agregar polling/refresh de estado o stream reactivo para `generating/failed/ready`.
- Riesgo: Alto. Hoy es el archivo más acoplado al simulador legacy.

- Archivo: `lib/features/simulator/presentation/simulator_screen.dart`
- Qué hace actualmente: Pantalla admin del simulador con selector de modo, carga de original, preview, before/after, carga manual de resultado, ajuste de región y guardado.
- Qué se puede reutilizar: Disclaimer, preview, `BeforeAfterSlider`, ajuste manual de región, switch de compartir, notas, estructura general de flujo.
- Qué se debe cambiar: Quitar selector mock/manual, quitar carga manual de resultado, reemplazar mensajes/estados por `generating/failed/ready`, y adaptar CTA principal para solicitar generación real por GPT-Image-2.
- Riesgo: Medio-Alto. La UI existe y es reutilizable, pero el flujo interno está mal orientado para el target final.

- Archivo: `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- Qué hace actualmente: Lista simulaciones del paciente, permite abrir, compartir/descompartir, eliminar y lanzar `SimulatorScreen`.
- Qué se puede reutilizar: Lista admin, integración con `SimulatorScreen`, acciones CRUD básicas, apertura de simulaciones existentes.
- Qué se debe cambiar: Ajustar textos, estados visibles, compatibilidad con nuevos estados y posiblemente restricciones de compartir en `failed/generating`.
- Riesgo: Medio.

- Archivo: `lib/shared/constants/storage_paths.dart`
- Qué hace actualmente: Define rutas de Storage para original, resultado, thumbs y temporales del simulador.
- Qué se puede reutilizar: `simulationOriginal`, `simulationResult`, thumbs y `simulatorTemp`.
- Qué se debe cambiar: Posiblemente agregar rutas para variantes, máscaras o artefactos intermedios si GPT-Image-2 lo necesita, sin romper rutas existentes.
- Riesgo: Bajo.

- Archivo: `lib/shared/constants/firestore_paths.dart`
- Qué hace actualmente: Define rutas de Firestore, incluyendo `patients/{patientId}/simulations`.
- Qué se puede reutilizar: `patientSimulations(patientId)`.
- Qué se debe cambiar: No parece requerir cambio estructural grande si mantenemos la colección actual.
- Riesgo: Bajo.

- Archivo: `functions/src/index.ts`
- Qué hace actualmente: Exporta funciones de auth, notificaciones, appointments, payments y treatments.
- Qué se puede reutilizar: Estructura del entrypoint, patrón de export y bootstrap de admin SDK.
- Qué se debe cambiar: Agregar la nueva Cloud Function del simulador GPT-Image-2; hoy no existe ninguna función de simulador.
- Riesgo: Medio.

- Archivo: `firestore.rules`
- Qué hace actualmente: Tiene reglas para `patients/{patientId}/simulations`, además de una colección raíz `simulations/{simId}` heredada.
- Qué se puede reutilizar: La ruta embebida en paciente ya protege lectura admin / paciente compartido y escritura admin.
- Qué se debe cambiar: Revisar si la colección raíz `simulations/{simId}` sigue siendo necesaria; endurecer reglas según campos nuevos (`generationProvider`, `modelUsed`, errores, intentos) si hace falta validación futura.
- Riesgo: Medio. Hay duplicidad conceptual por existir colección raíz y subcolección.

- Archivo: `storage.rules`
- Qué hace actualmente: Protege lectura/escritura de archivos del simulador en `simulations/{patientId}/{simulationId}/{fileName}`.
- Qué se puede reutilizar: Ruta y protección de lectura para simulaciones compartidas.
- Qué se debe cambiar: Probablemente nada estructural inmediato; solo validar que cubra archivos nuevos del pipeline GPT-Image-2.
- Riesgo: Bajo.

### Estado actual encontrado
- ¿Existe modelo de simulación? Sí.
- ¿Existe repositorio? Sí.
- ¿Existe provider? Sí.
- ¿Existe pantalla admin? Sí.
- ¿Existe vista paciente? Sí, vía pestaña del paciente y lectura de simulaciones compartidas.
- ¿Existe comparador before/after? Sí, `BeforeAfterSlider`.
- ¿Existe subida a Storage? Sí, original y resultado.
- ¿Existen rutas de simulador? Sí, en Firestore y Storage.
- ¿Existen reglas Firestore/Storage relacionadas? Sí.
- ¿Existe Cloud Function de simulador? No.

### Decisión de cambio mínimo
El sistema ya no manejará:
- mock
- manualDoctora
- manual_doctora

El sistema debe quedar únicamente con:
- generationProvider = openai
- modelUsed = gpt-image-2

Estados finales:
- draft
- generating
- ready
- shared
- failed
- archived

### Plan técnico mínimo
Migraré el simulador actual **sin reconstruirlo desde cero** así:

1. **Mantener la misma colección y la misma UI base**
   - reutilizar `patients/{patientId}/simulations`
   - reutilizar `StoragePaths` actuales
   - reutilizar `SimulatorScreen` y `PatientSimulatorTab` como base visual

2. **Refactorizar el modelo, no reemplazarlo por otro**
   - actualizar `SimulationMode`/`SimulationStatus`
   - introducir `generationProvider`, `modelUsed`, `attemptCount`, `errorMessage` y metadata de request/response si hace falta
   - mantener compatibilidad razonable con documentos existentes durante migración

3. **Refactorizar el provider actual**
   - conservar picker, draft, detección de región y persistencia inicial
   - reemplazar mock/manual por disparo de generación backend
   - cambiar estados UI a `draft/generating/ready/failed/shared`

4. **Agregar una sola Cloud Function real**
   - entrada: simulationId + patientId + metadata necesaria
   - proceso: descargar original si aplica, llamar GPT-Image-2, subir resultado a Storage, actualizar Firestore
   - salida: documento actualizado, sin crear un simulador paralelo

5. **Mantener la UI grande casi intacta en esta fase**
   - no rediseñar toda la pantalla
   - solo cambiar controles incompatibles: selector de modo, carga manual, copy de estados y CTA

6. **Ajustar reglas solo donde sea necesario**
   - mantener acceso admin para escritura
   - mantener lectura del paciente solo si está `shared`
   - validar impacto de nuevos campos antes de endurecer reglas por schema

## Bloque 02 — Ajuste modelo/repositorio/provider

### Archivos modificados
- `lib/features/simulator/data/models/simulation_model.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/features/simulator/presentation/patient_simulations_screen.dart`
- `lib/shared/utils/ui_formatters.dart`
- `test/features/simulator/simulation_model_test.dart`
- `test/features/simulator/simulation_repository_test.dart`

### Cambios en SimulationModel
- Se eliminó el modo como concepto operativo del flujo nuevo.
- Se dejaron los campos nuevos/objetivo:
  - `id`
  - `patientId`
  - `originalPath`
  - `resultPath`
  - `compartidaConPaciente`
  - `createdAt`
  - `updatedAt`
  - `createdBy`
  - `treatmentType`
  - `status`
  - `notes`
  - `generationProvider`
  - `modelUsed`
  - `attemptCount`
  - `errorMessage`
  - `generatedAt`
  - `promptUsed`
  - `promptVersion`
- Se conservaron además:
  - `mlKitUsed`
  - `detectedRegion`
  - `promptMetadata`
  - `fechaCompartida`
- Se agregó compatibilidad temporal en lectura para:
  - `originalUrl` → `originalPath`
  - `resultUrl` → `resultPath`
  - `creadoPor` → `createdBy`
  - `mode` legacy sin romper lectura histórica
- `toJson()` ya guarda únicamente la estructura nueva.

### Cambios en SimulationRepository
- `watchSimulations(patientId)` se mantuvo.
- `watchSharedSimulations(patientId)` se mantuvo con filtro por:
  - `compartidaConPaciente == true`
  - `status == shared`
- `uploadOriginalImage()` ahora devuelve y persiste el **path de Storage**, no una URL pública.
- Se dejó de usar `uploadResultImage()` como flujo principal desde Flutter.
- Se creó `createDraftSimulation(...)` para crear borradores listos para backend.
- Se creó `updateSimulationStatus(...)` para transiciones de estado simples.
- Se creó `shareSimulationWithPatient(...)`.
- Se creó `unshareSimulationWithPatient(...)`.
- Se mantuvo `deleteSimulation(...)` con limpieza best-effort en Storage.

### Cambios en SimulationProvider
- Se eliminó del flujo principal:
  - `MockSimulationService`
  - generación mock
  - selección de modo
  - carga manual de resultado
- El flujo ahora queda así:
  1. subir foto original
  2. detectar región facial si aplica
  3. crear draft en Firestore con `status = draft`
  4. preparar acción `generateWithAi(...)`
- `generateWithAi(...)` por ahora **no conecta OpenAI** ni Functions.
- `generateWithAi(...)` deja el documento marcado en `generating` y muestra mensaje controlado indicando que la conexión real se hará en el siguiente bloque.

### Compatibilidad con datos legacy
- Los documentos antiguos con `mode = mock` o `mode = manualDoctora` siguen pudiéndose leer.
- Los documentos antiguos con `originalUrl`/`resultUrl` siguen pudiéndose leer.
- La UI y el modelo usan aliases (`originalUrl`, `resultUrl`) para no romper otras pantallas mientras se termina la migración completa.

### Cambios mínimos en UI
- Se quitó el selector visual de `Mock` / `Manual doctora`.
- Se quitó el flujo principal de subir resultado manual.
- Se actualizó el disclaimer.
- Se añadió estado visible:
  - Borrador
  - Generando
  - Lista
  - Compartida
  - Error
  - Archivada
- Se añadió botón `Generar con IA` con comportamiento controlado de preintegración.
- Se mantuvo el comparador before/after cuando exista resultado.

### Qué queda listo para el siguiente bloque
- Modelo preparado para GPT-Image-2.
- Repositorio preparado para draft/status/share.
- Provider preparado para disparar la generación backend.
- UI limpia del flujo mock/manual.
- Tests base del simulador alineados al nuevo modelo/repositorio.

### Pendientes
- Crear Cloud Function real `generateSmileSimulation`.
- Conectar OpenAI GPT-Image-2 desde backend.
- Definir prompt final y promptVersion real.
- Definir escritura del `resultPath` y transición `generating -> ready/failed` desde backend.
- Ejecutar validación real en entorno con Flutter instalado.

### Resultado de flutter analyze
- Intentado desde `/home/borlty/OCG-WebUser/ocg_proyect`.
- Resultado en esta sesión: **no ejecutable** porque `flutter` no está disponible en el PATH del entorno actual (`/bin/bash: flutter: command not found`).
- `dart test test/features/simulator/` también fue intentado y tampoco pudo ejecutarse porque `dart` no está disponible en el PATH del entorno actual (`/bin/bash: dart: command not found`).

## Cierre Bloque 02.5 — Legacy aceptado vs legacy eliminado

### Legacy aceptado temporalmente
- mode en lectura fromJson: Sí, solo para compatibilidad con documentos antiguos.
- originalUrl en lectura fromJson: Sí, solo como fallback hacia `originalPath`.
- resultUrl en lectura fromJson: Sí, solo como fallback hacia `resultPath`.
- tests de compatibilidad: Sí, se mantienen para validar lectura legacy sin romper migración.

### Legacy eliminado o marcado obsoleto
- mock_simulation_service.dart: Eliminado.
- mock_simulation_service_test.dart: Eliminado.

### Motivo
Se mantiene compatibilidad de lectura para documentos antiguos, pero el flujo principal queda exclusivamente orientado a GPT-Image-2.

### Estado
- Bloque 02.5: Cerrado.

## Comandos de validación para Erik

Desde la raíz del proyecto:

```bash
cd ocg_proyect
flutter pub get
flutter analyze
flutter test test/features/simulator/
```

Si hay errores, Erik debe pegar aquí la salida exacta antes de avanzar a backend.

## Bloque 03 — Cloud Function base generateSmileSimulation

### Archivos creados
- `ocg_proyect/functions/src/simulator/generate_smile_simulation.ts`
- `ocg_proyect/functions/src/simulator/build_smile_prompt.ts`
- `ocg_proyect/functions/src/simulator/simulator_config.ts`

### Archivos modificados
- `ocg_proyect/functions/src/index.ts`
- `docs/propuestas/REGISTRO_SIMULADOR_GPT_IMAGE_2.md`

### Validaciones implementadas
- Usuario autenticado.
- Usuario con rol admin.
- `patientId` presente.
- `simulationId` presente.
- El paciente existe en Firestore.
- La simulación existe en `patients/{patientId}/simulations/{simulationId}`.
- La simulación pertenece al paciente.
- Existe `originalPath` válido (con fallback legacy a `originalUrl` solo para lectura).
- Estado permitido para generación:
  - `draft`
  - `ready`
  - `failed`
- `attemptCount` menor que `MAX_SIMULATION_ATTEMPTS`.
- `AI_SIMULATOR_ENABLED` activo.

### Variables requeridas
- `OPENAI_API_KEY`
- `OPENAI_IMAGE_MODEL` (esperado: `gpt-image-2`)
- `AI_SIMULATOR_ENABLED`
- `MAX_SIMULATION_ATTEMPTS`

### Prompt builder creado
- Se creó `buildSmilePrompt(...)` con:
  - prompt clínico base obligatorio
  - soporte para `treatmentType`
  - soporte para `notes` como complemento
- Devuelve:
  - `promptUsed`
  - `promptVersion`
- Versión actual:
  - `ocg-smile-v1`

### Export en index.ts
- La Function quedó exportada como:
  - `generateSmileSimulation`

### Comportamiento si falta API Key
- No genera imagen.
- No modifica `resultPath`.
- No deja la simulación pegada en `generating`.
- Responde error controlado:
  - `OPENAI_API_KEY no está configurada en backend.`

### Comportamiento si IA está desactivada
- No genera imagen.
- No modifica `resultPath`.
- No deja la simulación pegada en `generating`.
- Responde error controlado:
  - `La generación con IA no está habilitada.`

### Resultado npm run build
- Ejecutado desde: `ocg_proyect/functions`
- Comandos corridos:
  - `npm install`
  - `npm run build`
- Resultado:
  - compilación TypeScript exitosa
- Observación:
  - hubo warning de engine porque el entorno actual corre Node `v22.22.2` y el package declara Node `20`, pero **no bloqueó la compilación**.

### Bloqueos actuales
- Falta `OPENAI_API_KEY` segura para conectar GPT-Image-2 real.
- Falta confirmación operativa de variables reales en backend.
- Falta implementar la llamada real a OpenAI y escritura del resultado en Storage.

### Estado del bloque
- Bloque 03: Listo como base backend segura y compilando.

## Bloque 04 — Conexión real GPT-Image-2

### Archivos modificados
- `ocg_proyect/functions/src/simulator/generate_smile_simulation.ts`
- `ocg_proyect/functions/src/simulator/simulator_config.ts`
- `ocg_proyect/functions/package.json`
- `ocg_proyect/functions/package-lock.json`
- `docs/propuestas/REGISTRO_SIMULADOR_GPT_IMAGE_2.md`

### SDK/OpenAI usado
- SDK oficial `openai` para Node.js en Firebase Functions.
- Integración implementada usando `OpenAI` + `toFile(...)` para enviar la imagen original descargada desde Storage a `gpt-image-2`.

### Variables configuradas o pendientes
- Requeridas:
  - `OPENAI_API_KEY`
  - `OPENAI_IMAGE_MODEL` (default operativo: `gpt-image-2`)
  - `AI_SIMULATOR_ENABLED`
  - `MAX_SIMULATION_ATTEMPTS`
- Opcionales con defaults conservadores:
  - `OPENAI_IMAGE_QUALITY` (default: `medium`)
  - `OPENAI_IMAGE_SIZE` (default: `1024x1024`)

### Flujo implementado
1. Valida auth.
2. Valida admin.
3. Valida `patientId` y `simulationId`.
4. Busca paciente y simulación en Firestore.
5. Valida pertenencia de la simulación al paciente.
6. Valida `originalPath`.
7. Valida estado permitido (`draft`, `ready`, `failed`).
8. Valida límite de intentos.
9. Valida `AI_SIMULATOR_ENABLED`.
10. Valida `OPENAI_API_KEY`.
11. Marca simulación en `generating` y aumenta `attemptCount`.
12. Descarga la imagen original desde Firebase Storage.
13. Construye prompt clínico con `buildSmilePrompt(...)`.
14. Llama a OpenAI `gpt-image-2` con edición de imagen.
15. Decodifica la imagen generada.
16. Guarda `result.jpg` en Storage en:
   - `simulations/{patientId}/{simulationId}/result.jpg`
17. Actualiza Firestore a:
   - `status = ready`
   - `resultPath`
   - `generatedAt`
   - `promptUsed`
   - `promptVersion`
   - `modelUsed`
   - `generationProvider = openai`
   - `errorMessage = null`
   - `compartidaConPaciente = false`

### Prompt usado
- Se usa el prompt builder existente.
- Prompt base clínico intacto.
- `notes` solo complementa, no reemplaza el prompt base.
- `promptVersion` actual:
  - `ocg-smile-v1`

### Configuración de calidad/tamaño
- Configuración inicial conservadora:
  - `quality = medium`
  - `size = 1024x1024`
- Ambas pueden ajustarse por variable de entorno sin tocar código.

### Manejo de errores
- Si falla cualquier paso después de `generating`, Firestore se actualiza a:
  - `status = failed`
  - `errorMessage = mensaje controlado`
  - `updatedAt = serverTimestamp()`
- No se guardan payloads sensibles ni errores largos sin sanitizar.
- Si falta API Key:
  - error controlado: `OPENAI_API_KEY no está configurada en backend.`
- Si IA está deshabilitada:
  - error controlado: `La generación con IA no está habilitada.`

### Resultado npm run build
- Ejecutado desde `ocg_proyect/functions`.
- `npm install` ejecutado correctamente.
- `npm run build` compiló correctamente después de ajustar tipos del SDK para `size`.
- Warning observado:
  - `EBADENGINE` por correr con Node `v22` en entorno actual mientras `package.json` declara Node `20`.
  - No bloqueó instalación ni compilación.

### Prueba con API Key
- No se pudo ejecutar prueba real contra OpenAI porque en esta sesión no se confirmó ni expuso una `OPENAI_API_KEY` válida de backend para pruebas.
- El código quedó compilando y listo para prueba real cuando la key segura esté configurada.

### Bloqueos actuales
- Falta `OPENAI_API_KEY` real y segura en backend para prueba end-to-end.
- Falta confirmación/validación del paciente ficticio e imagen autorizada para prueba real.
- Falta conectar Flutter al botón `Generar con IA` invocando esta callable.

### Estado del bloque
- Bloque 04: Implementado a nivel backend y compilando.
- Prueba real contra OpenAI: bloqueada por falta de API Key confirmada para esta sesión.

## Bloque 05 — Conexión Flutter con generateSmileSimulation

### Archivos modificados
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/simulator/presentation/patient_simulations_screen.dart`
- `docs/propuestas/REGISTRO_SIMULADOR_GPT_IMAGE_2.md`

### Dependencia cloud_functions
- Ya existía en `pubspec.yaml`:
  - `cloud_functions: ^6.0.0`
- No fue necesario agregar una nueva dependencia.

### Método repository creado
- Se creó `generateWithAi({...})` en `SimulationRepository`.
- Invoca la callable:
  - `generateSmileSimulation`
- Payload enviado:
  - `patientId`
  - `simulationId`
  - `treatmentType`
  - `notes`
- No se envía API Key, base64 ni credenciales desde Flutter.

### Cambios en provider
- `simulation_provider.dart` ahora:
  - valida `patientId`
  - valida `simulationId`
  - valida `originalPath`
  - solo permite generar desde `draft`, `ready` o `failed`
  - bloquea doble generación cuando el estado está en `generating`
  - llama a `repository.generateWithAi(...)`
  - ya no marca `ready` desde Flutter
- Se añadió escucha en tiempo real del documento de simulación desde Firestore para reflejar estados reales del backend.

### Cambios en UI admin
- El botón `Generar con IA` quedó conectado a la callable.
- Estado `generating` muestra loading real:
  - `Generando simulación con IA...`
- Estado `ready` muestra comparador before/after si existe `resultPath`.
- Estado `failed` muestra `errorMessage` controlado y ofrece reintento.
- Estado `shared` muestra que ya fue compartida.
- Estado `archived` bloquea nuevas acciones.
- Se añadieron acciones de:
  - compartir con paciente
  - regenerar
  - archivar

### Cambios en vista paciente
- La vista paciente sigue consumiendo `watchSharedSimulations(...)`.
- Solo muestra simulaciones con:
  - `status == shared`
  - `compartidaConPaciente == true`
- El paciente no tiene botones para:
  - generar
  - regenerar
  - editar
  - archivar
  - compartir

### Manejo de estados
- Estados manejados en Flutter:
  - `draft`
  - `generating`
  - `ready`
  - `failed`
  - `shared`
  - `archived`
- La fuente de verdad del estado final es Firestore/backend.
- Flutter ya no simula resultado ni transiciones finales.

### Manejo de errores
- Si backend devuelve:
  - `OPENAI_API_KEY no está configurada en backend.`
  - la UI muestra: `La generación con IA aún no está configurada en el backend.`
- Si backend devuelve:
  - `La generación con IA no está habilitada.`
  - la UI muestra: `La generación con IA está temporalmente desactivada.`
- Si backend devuelve límite de intentos:
  - la UI muestra un mensaje amigable indicando que ya alcanzó el máximo permitido.

### Resultado flutter analyze
- No ejecutable en esta sesión porque `flutter` no está disponible en el PATH del entorno actual.

### Resultado flutter test
- No ejecutable en esta sesión porque `flutter`/`dart` no están disponibles en el PATH del entorno actual.

### Bloqueos actuales
- Falta ejecutar localmente:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test test/features/simulator/`
- Falta prueba end-to-end real con API Key activa y paciente/imagen autorizados.

### Estado del bloque
- Bloque 05: Implementado a nivel Flutter para invocar `generateSmileSimulation` y escuchar estados reales desde Firestore.
- Validación local Flutter: pendiente por limitación del entorno actual.

## Bloque 05.5 — Corrección de validación local

### Resultado validación Erik
- Functions npm install: previamente ejecutado correctamente.
- Functions npm run build: previamente compilando correctamente.
- Simulator tests: pendientes de reejecución local por Erik.
- Flutter analyze: pendiente de reejecución local por Erik.

### Correcciones realizadas
- Simulator unused import: eliminado `../../../shared/utils/ui_formatters.dart` de `patient_simulations_screen.dart` porque ya no se usaba.
- Treatment dialog test: se actualizó `manage_patient_treatment_dialog_test.dart` para enviar `patientName`, requerido por la firma actual de `ManagePatientTreatmentDialog`.
- Treatment catalog repository tests: se actualizaron los tests para usar el API actual (`createCatalogItem` y `watchCatalog`) en vez de métodos antiguos (`ensureCustomTreatmentExists`, `watchActiveCatalog`).
- Warnings menores: se eliminó `_isSameCalendarDay` no referenciado en `appointments_business_rules.dart`.

### Comandos para que Erik vuelva a ejecutar
```bash
cd ocg_proyect
flutter analyze
flutter test test/features/simulator/

cd functions
npm run build
```

### Estado
Pendiente hasta que Erik confirme flutter analyze sin errores.

## Reglas
- No pongas API Keys en Flutter.
- No subas claves al repositorio.
- No inventes credenciales.
- Si falta algo, me lo pides claro.
- Al final dime si puedes continuar o si estás bloqueado.

## Estado actual
Estoy **bloqueado parcialmente**.

Borlty, del simulador como flujo base ya no quiero que agregues más funcionalidades nuevas por ahora.

El simulador queda en este estado:
- Modelo preparado para GPT-Image-2.
- Mock eliminado.
- Manual doctora eliminado.
- Cloud Function base creada.
- GPT-Image-2 conectado desde backend.
- Flutter conectado a generateSmileSimulation.
- Tests del simulador pendientes de revalidación local.
- Functions build pasando después de npm install.

Ahora NO debo avanzar más funcionalidades del simulador.

Lo único pendiente antes de prueba real es:
1. Corregir los errores de `flutter analyze`.
2. Dejar registrado que Functions ya compila.
3. Esperar que Erik configure la API Key segura en backend.
4. Hacer prueba end-to-end con paciente ficticio e imagen autorizada.

No conectar pacientes reales todavía.
No hacer más rediseños.
No meter API Key en Flutter.
No cambiar arquitectura.
No agregar modos nuevos.

Después de eso quedamos a la espera de:
- `OPENAI_API_KEY` configurada en backend.
- `OPENAI_IMAGE_MODEL=gpt-image-2`.
- `AI_SIMULATOR_ENABLED=true`.
- Paciente ficticio.
- Imagen autorizada de prueba.
