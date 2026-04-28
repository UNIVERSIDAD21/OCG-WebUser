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

## Reglas
- No pongas API Keys en Flutter.
- No subas claves al repositorio.
- No inventes credenciales.
- Si falta algo, me lo pides claro.
- Al final dime si puedes continuar o si estás bloqueado.

## Estado actual
Estoy **bloqueado parcialmente**.

Puedo continuar con la fase de revisión y diseño técnico del módulo, y también con el **ajuste del modelo/repositorio/provider**, pero **no puedo implementar de forma real y desplegable** el simulador con GPT-Image-2 hasta que Erik entregue o confirme los accesos y datos faltantes indicados arriba, especialmente:
- Firebase Project ID correcto
- permiso de despliegue de Functions
- OpenAI API Key segura en backend
- paciente ficticio e imagen autorizada de prueba
