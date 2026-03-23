# BLOQUE_08 — Simulador de Sonrisa (v2.1 — Ejecución profesional por fases)

> **Stack inicial:** Flutter + Firebase Storage + Firestore + Riverpod + ML Kit  
> **Stack futuro opcional:** Cloud Functions + API de generación de imágenes  
> **Prioridad:** ALTA — diferenciador comercial y apoyo visual en consulta  
> **Estado:** ⬅️ EMPIEZA AQUÍ  
> **Dependencias:**  
> - Bloque 01 (arquitectura, rutas, widgets base) ✅  
> - Bloque 04 (pacientes) ✅  
> - Bloque 05 (agenda/citas) ✅  
> - StoragePaths y estructura Firebase operativa ✅

---

## Ajustes v2.1 (obligatorios para ejecución sin fricción)

### 1) Vertical slice más pequeño (primero valor real)

**Fase 1 (obligatoria primero):**
- `SimulationModel`
- `SimulationRepository`
- guardado `draft`
- carga de imagen original
- carga manual de imagen resultado
- guardar simulación
- compartir/descompartir
- vista paciente (solo compartidas)

**Fase 2 (después):**
- mock interno
- ML Kit
- refinamientos de UX

> Motivo: el modo manual entrega valor clínico/comercial real desde el día 1 y reduce riesgo técnico temprano.

### 2) No atar arquitectura a bytes en memoria

- `beforeBytes/afterBytes` se usan solo para preview temporal.
- Persistencia y lectura deben basarse en `storagePath`/referencias estables.
- Historial debe consumir miniaturas (thumbnails), no imágenes completas.

### 3) Estado draft real (no simular completitud)

Toda simulación debe tener estado explícito:
- `draft`
- `ready`
- `shared`
- `archived`

Regla crítica:
- Si no existe imagen resultado, la simulación **permanece en `draft`**.

### 4) Seguridad: Storage + Firestore + reglas

No depender de URL suelta como control de acceso.
Control real:
- Firestore (`compartidaConPaciente`, `estado`, ownership)
- Security Rules de Firestore y Storage
- persistencia por rutas/referencias, no por links pegados en múltiples lugares

---

## Objetivo real de este bloque

Implementar un **Simulador de Sonrisa funcional y usable desde ya**, pero **sin depender todavía de una API de generación automática**.

La primera versión NO generará la imagen “después” dentro de la app mediante IA externa.  
En su lugar, funcionará en dos modos:

### Modo 1 — Mock interno
La app toma la foto original y genera una **vista orientativa visual** dentro de la propia aplicación, sin IA generativa real.  
Esto sirve para validar la experiencia, la interfaz, el historial y el flujo completo.

### Modo 2 — Manual asistido por la doctora
La doctora toma la imagen original, genera por fuera una imagen “después” usando su herramienta externa, y luego sube esa imagen manualmente al sistema.  
La app se encarga de:
- guardar ambas imágenes,
- compararlas,
- mostrarlas con un `BeforeAfterSlider`,
- almacenarlas en el historial del paciente,
- y controlar si se comparten o no con el paciente.

---

## Enfoque estratégico del bloque

Este bloque NO debe construirse como una “integración temprana con IA costosa”.  
Debe construirse como un **producto interno sólido**, de manera que más adelante solo haya que **reemplazar el origen de la imagen de salida**.

### Arquitectura mental correcta

```text
Imagen original -> proceso de simulación -> imagen resultado -> comparación -> guardado -> historial -> compartir
```

### En la versión inicial
- **Imagen original:** la sube el usuario o la doctora
- **Proceso de simulación:** mock interno o generación manual externa
- **Imagen resultado:** la produce el mock o la sube la doctora
- **Comparación / guardado / historial / compartir:** lo hace la app

### En la versión futura
- **Imagen original:** igual
- **Proceso de simulación:** Cloud Function + motor de generación API
- **Imagen resultado:** la devuelve la Function
- **Comparación / guardado / historial / compartir:** exactamente igual

---

## Qué se busca cerrar en esta versión

Esta primera versión debe cerrar el simulador como **módulo funcional**, aunque todavía no tenga generación automática real.

Eso significa que al cerrar este bloque debe existir:
- pantalla completa del simulador,
- carga de imagen original,
- modo mock funcional,
- modo manual funcional,
- comparación antes/después,
- historial de simulaciones por paciente,
- almacenamiento de imágenes en Storage,
- metadatos en Firestore,
- control de visibilidad para paciente,
- integración en el flujo del admin y del paciente,
- base técnica lista para conectar un motor real más adelante.

---

# Alcance de esta versión

## Lo que SÍ entra en este bloque

- Cargar imagen desde cámara o galería
- Detectar rostro / apoyar visualmente con ML Kit
- Reencuadrar o sugerir zona de sonrisa
- Generar un resultado mock interno
- Permitir subir manualmente la imagen “después”
- Mostrar comparación visual
- Guardar ambas imágenes
- Registrar simulación en Firestore
- Ver historial por paciente
- Compartir / descompartir con paciente
- Preparar estructura para futuro motor real

## Lo que NO entra todavía

- Inpainting real por API
- Cloud Function de generación automática
- Prompting automatizado contra un motor externo
- Máscara perfecta para edición real
- Automatización n8n / proveedor externo
- Costo por generación de imágenes
- Flujo de producción con IA real

---

# Flujo funcional del simulador — versión inicial

## Flujo A — Mock interno

```text
1. Admin abre Simulador desde el paciente
2. Sube foto original
3. ML Kit detecta rostro / ayuda a centrar
4. Usuario confirma o ajusta la zona de sonrisa
5. App genera una simulación orientativa interna (mock)
6. Se muestra comparación Before / After
7. Admin guarda la simulación
8. Se almacenan original + mock + metadatos
9. Puede marcar si se comparte con el paciente
```

## Flujo B — Manual con imagen “después” subida por la doctora

```text
1. Admin abre Simulador desde el paciente
2. Sube foto original
3. ML Kit detecta rostro / ayuda visual
4. La doctora genera por fuera una imagen orientativa “después”
5. La doctora sube esa imagen resultado manualmente
6. La app muestra comparación Before / After
7. Se guarda la simulación
8. Se decide si se comparte con el paciente
```

## Flujo C — Paciente

```text
1. Paciente abre su módulo de simulaciones
2. Solo ve simulaciones marcadas como compartidas
3. Puede abrir cada simulación
4. Puede deslizar el comparador Before / After
5. Puede ver fecha, notas y contexto orientativo
```

---

# Principios funcionales y clínicos

## Regla 1 — Simulación orientativa, no promesa clínica
En toda la UI debe quedar claro que la imagen “después” es una:
- simulación visual orientativa,
- referencia preliminar,
- apoyo para explicación comercial/clínica,
- no garantía exacta de resultado final.

## Regla 2 — La imagen del “después” puede venir de dos orígenes
Cada simulación debe registrar su origen:
- `mock`
- `manual_doctora`

Más adelante se podrá agregar:
- `api`
- `ml_pipeline`
- `n8n_external`

## Regla 3 — El paciente solo ve lo que el admin comparte
Toda simulación debe tener control de visibilidad.

## Regla 4 — La estructura debe quedar preparada para evolución futura
No se debe hardcodear el módulo como “manual para siempre”.  
Debe quedar listo para que luego el origen del “después” sea automático.

---

# Diseño funcional detallado

## Pantalla principal del simulador

Archivo esperado:

```text
lib/features/simulator/presentation/simulator_screen.dart
```

### Estados visuales esperados

#### Estado `idle`
- Botón `Subir foto`
- Botón `Usar cámara`
- Texto breve explicando que la simulación es orientativa
- Si admin: opción de elegir modo `Mock` o `Manual`

#### Estado `pickingImage`
- Loading sutil
- Texto: `Cargando imagen...`

#### Estado `detectingFace`
- Barra de progreso
- Texto: `Analizando rostro...`

#### Estado `editingRegion`
- Vista previa de la imagen
- Sugerencia de zona de sonrisa detectada por ML Kit
- Opción de ajustar manualmente el encuadre
- Botón `Confirmar zona`

#### Estado `mockReady`
- Imagen before/after con mock generado
- Opción `Guardar simulación`
- Opción `Volver a intentar`

#### Estado `waitingManualResult`
- Se muestra la imagen original ya subida
- Botón `Subir imagen resultado`
- Texto: `La imagen resultado puede ser cargada manualmente por la doctora`

#### Estado `manualReady`
- BeforeAfterSlider activo con original + resultado manual
- Opción `Guardar simulación`
- Opción `Reemplazar imagen resultado`

#### Estado `saved`
- Confirmación
- Opción `Compartir con paciente`
- Opción `Ver historial`

#### Estado `error`
- `OcgEmptyState`
- Mensaje claro
- Botón `Intentar de nuevo`

---

# ML Kit en esta versión

## Objetivo de ML Kit en fase inicial

ML Kit NO se usará todavía para generar una máscara de inpainting real.  
Se usará para:
- detectar si hay rostro,
- mejorar encuadre,
- sugerir zona facial/bucal,
- dar soporte visual al mock interno,
- preparar la app para el futuro motor de IA.

## Qué debe hacer realmente

Archivo esperado:

```text
lib/services/firebase/face_detection_service.dart
```

### Funciones mínimas esperadas

- Detectar si la imagen contiene al menos un rostro
- Obtener puntos o regiones útiles del rostro
- Sugerir una región de interés centrada en la boca/sonrisa
- Devolver una estructura usable por UI para dibujar el recuadro sugerido

### Qué NO debe hacer todavía

- Máscara compleja final para API externa
- Segmentación perfecta de dientes
- Automatización completa del resultado

## Comportamiento si ML Kit falla
Si no detecta bien la zona:
- no se rompe el flujo,
- se deja ajuste manual,
- el usuario puede continuar.

---

# Mock interno — definición exacta

## Qué es el mock
Es una **simulación visual interna** generada por la app, sin usar una API externa.

## Qué debe lograr
No debe intentar “inventar dientes nuevos”.  
Debe producir una versión visualmente más limpia y orientativa de la sonrisa.

## Opciones válidas de mock
Puede usar una o varias:
- recorte/reencuadre centrado en sonrisa,
- leve mejora de brillo,
- reducción de tono amarillento,
- contraste controlado,
- nitidez suave,
- resaltado visual de la zona dental,
- overlay clínico opcional,
- guía de arco o línea media opcional.

## Qué NO debe hacer el mock
- deformar rostro
- cambiar identidad del paciente
- cambiar labios o piel agresivamente
- parecer una promesa de resultado real
- verse caricaturesco o artificial

## Archivo esperado

```text
lib/services/simulator/mock_simulation_service.dart
```

### Responsabilidades
- recibir bytes originales
- recibir región sugerida
- producir bytes “resultado mock”
- permitir cambiar la intensidad del mock si hace falta
- ser reemplazable más adelante por un motor real

---

# Modo manual — definición exacta

## Qué es
La doctora genera la imagen “después” usando una herramienta externa y luego la carga al sistema manualmente.

## Qué debe soportar la app
- cargar imagen original
- dejar simulación pendiente
- permitir cargar imagen resultado después
- reemplazar resultado si fue incorrecto
- guardar versión final
- registrar que el origen fue manual

## Cuándo conviene usarlo
- consultas importantes
- casos donde el mock no es suficiente
- pruebas tempranas de valor comercial
- validación de prompts externos antes de automatizar

---

# Modelo de datos

## Archivo esperado

```text
lib/features/simulator/data/models/simulation_model.dart
```

## Estructura recomendada

```dart
class SimulationModel {
  final String id;
  final String patientId;
  final String originalUrl;
  final String? resultUrl;
  final String mode; // mock | manual_doctora | api_futuro
  final bool compartidaConPaciente;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String creadoPor;
  final String? treatmentType;
  final String status; // draft | ready | shared | archived
  final String? notes;
  final bool mlKitUsed;
  final Map<String, dynamic>? detectedRegion;
  final Map<String, dynamic>? promptMetadata;
}
```

## Campos obligatorios mínimos
- `id`
- `patientId`
- `originalUrl`
- `mode`
- `compartidaConPaciente`
- `createdAt`
- `creadoPor`
- `status`

## Campos estratégicos para el futuro
- `treatmentType`
- `mlKitUsed`
- `detectedRegion`
- `promptMetadata`

Estos campos deben existir aunque inicialmente algunos vayan nulos.

---

# Firestore — estructura recomendada

## Colección sugerida

```text
patients/{patientId}/simulations/{simulationId}
```

## Ejemplo conceptual de documento

```json
{
  "id": "sim_001",
  "patientId": "patient_123",
  "originalUrl": "storage://...",
  "resultUrl": "storage://...",
  "mode": "manual_doctora",
  "compartidaConPaciente": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "creadoPor": "admin_001",
  "treatmentType": "alineadores",
  "status": "ready",
  "notes": "Simulación orientativa para explicación comercial",
  "mlKitUsed": true,
  "detectedRegion": {
    "x": 0.31,
    "y": 0.54,
    "width": 0.36,
    "height": 0.18
  },
  "promptMetadata": {
    "templateId": null,
    "source": "manual_externo"
  }
}
```

## Reglas funcionales Firestore
- No borrar simulaciones por defecto; preferir archivado si luego se implementa
- Timestamps siempre consistentes
- Registrar origen del resultado
- Permitir listar por paciente ordenado por fecha

---

# Storage — estructura recomendada

## Rutas sugeridas

```text
simulations/{patientId}/{simulationId}/original.jpg
simulations/{patientId}/{simulationId}/result.jpg
simulations/{patientId}/{simulationId}/thumb_before.jpg
simulations/{patientId}/{simulationId}/thumb_after.jpg
```

## Qué debe guardarse
- original
- resultado
- opcionalmente miniaturas para historial rápido

## Qué no debe hacerse
- URLs públicas permanentes abiertas
- nombres ambiguos
- imágenes sueltas fuera de la ruta del paciente/simulación

---

# Repository

## Archivo esperado

```text
lib/features/simulator/data/repositories/simulation_repository.dart
```

## Responsabilidades mínimas
- subir imagen original
- subir imagen resultado
- guardar documento de simulación
- listar simulaciones del paciente
- actualizar visibilidad compartida
- actualizar una simulación pendiente/manual
- borrar o archivar si luego se requiere

## Métodos mínimos sugeridos

```dart
Stream<List<SimulationModel>> watchSimulations(String patientId);

Future<String> uploadOriginalImage(String patientId, String simulationId, Uint8List bytes);

Future<String> uploadResultImage(String patientId, String simulationId, Uint8List bytes);

Future<void> saveSimulation(SimulationModel simulation);

Future<void> updateSimulation(String patientId, String simulationId, Map<String, dynamic> data);

Future<void> toggleShare(String patientId, String simulationId, bool compartir);
```

---

# Provider / estado del módulo

## Archivo esperado

```text
lib/features/simulator/providers/simulation_provider.dart
```

## Enum de estados recomendado

```dart
enum SimulatorStep {
  idle,
  pickingImage,
  detectingFace,
  editingRegion,
  generatingMock,
  waitingManualResult,
  previewReady,
  saving,
  saved,
  error,
}
```

## State recomendado
Debe incluir como mínimo:
- `step`
- `originalBytes`
- `resultBytes`
- `errorMessage`
- `mode`
- `detectedRegion`
- `selectedTreatmentType`
- `notes`

## Notifier recomendado
Debe permitir:
- seleccionar imagen
- correr ML Kit
- ajustar zona
- generar mock
- cargar resultado manual
- guardar simulación
- resetear flujo

---

# BeforeAfterSlider

## Archivo esperado

```text
lib/shared/widgets/before_after_slider.dart
```

## Responsabilidades
- recibir `beforeBytes`
- recibir `afterBytes`
- mostrar comparador fluido
- permitir drag horizontal
- verse bien tanto en admin como en paciente

## Requisitos UX
- divisor visible
- handle claro
- transición suave
- fallback si una imagen falta
- responsive

---

# Historial de simulaciones

## Admin
Debe poder:
- ver todas las simulaciones del paciente
- abrir una simulación
- ver origen (`mock` o `manual_doctora`)
- compartir / descompartir
- ver fecha y notas
- crear nueva simulación

## Paciente
Debe poder:
- ver solo simulaciones compartidas
- abrir comparación before/after
- no editar
- no subir resultados

---

# Integración en pacientes

## Tab de simulador
Archivo esperado:

```text
lib/features/patients/presentation/tabs/patient_simulator_tab.dart
```

## Contenido esperado
- listado de simulaciones
- botón `Nueva simulación` para admin
- estado vacío elegante
- acceso a detalle

---

# Rutas

## route_names.dart
Agregar al menos:

```dart
static const String adminPatientSimulator = '/admin/patients/:patientId/simulator';
static const String patientSimulator = '/patient/simulator';
```

## app_router.dart
Agregar rutas correspondientes.

---

# Prompts — preparación para el futuro

## Importante
En esta fase NO se generarán prompts automáticos contra una API.  
Pero la estructura debe quedar preparada para eso.

## Estrategia futura recomendada
Guardar metadatos de prompt, aunque todavía no se consuman automáticamente.

### Estructura conceptual
- `promptBase`
- `promptTreatmentType`
- `extraInstructions`
- `templateId`

## Tratamientos sugeridos para futuras plantillas
- ortodoncia convencional
- alineadores
- blanqueamiento
- diseño de sonrisa
- finalización / retención

## Por qué dejar esto desde ahora
Porque más adelante podrás conectar el motor sin rediseñar toda la BD.

---

# Validaciones y reglas

## Validaciones mínimas
- no continuar sin imagen original
- no guardar simulación manual sin imagen resultado
- si ML Kit falla, permitir ajuste manual
- si no hay rostro detectable, mostrar advertencia amigable
- no compartir simulación inexistente o incompleta
- no permitir que paciente vea simulaciones no compartidas

## Reglas de negocio
- El paciente NO crea simulaciones manuales
- El admin sí crea y comparte
- `mode` debe quedar registrado siempre
- Toda simulación debe quedar ligada a un paciente
- Toda simulación debe tener `createdAt`

---

# Textos y disclaimers recomendados

## En admin
**“Esta simulación es una referencia visual orientativa para apoyar la explicación del tratamiento. No representa una promesa exacta del resultado final.”**

## En paciente
**“La imagen mostrada es una simulación orientativa con fines informativos y de valoración.”**

---

# Archivos a crear o completar

## Nuevos archivos
- `lib/features/simulator/data/models/simulation_model.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/services/simulator/mock_simulation_service.dart`
- `lib/shared/widgets/before_after_slider.dart`

## Archivos a completar/integrar
- `lib/services/firebase/image_picker_service.dart`
- `lib/services/firebase/face_detection_service.dart`
- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `lib/app/router/route_names.dart`
- `lib/app/router/app_router.dart`

---

# Entregables obligatorios del bloque

- [ ] `ImagePickerService` funcional
- [ ] `FaceDetectionService` con ML Kit funcional para detección/sugerencia
- [ ] `MockSimulationService` funcional
- [ ] `SimulationModel` creado y serializable
- [ ] `SimulationRepository` funcional con Storage + Firestore
- [ ] `simulation_provider` funcional
- [ ] `BeforeAfterSlider` funcional
- [ ] `SimulatorScreen` funcional en modo mock
- [ ] `SimulatorScreen` funcional en modo manual
- [ ] `patient_simulator_tab.dart` funcional
- [ ] Rutas integradas
- [ ] Historial admin funcional
- [ ] Vista paciente funcional para simulaciones compartidas
- [ ] Textos orientativos agregados
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅

---

# Criterios de cierre del bloque

Este bloque SOLO puede darse por cerrado si se cumple TODO lo siguiente:

## Flujo base
- [ ] El admin puede abrir el simulador desde un paciente real
- [ ] El admin puede cargar una imagen original desde cámara o galería
- [ ] El sistema procesa la imagen sin romperse aunque ML Kit no detecte la región exacta
- [ ] Existe una sugerencia visual de rostro/sonrisa o un ajuste manual equivalente

## Modo mock
- [ ] El sistema puede generar una imagen resultado mock interna
- [ ] La comparación before/after funciona correctamente
- [ ] El admin puede guardar una simulación creada en modo mock

## Modo manual
- [ ] El admin puede crear una simulación manual
- [ ] El admin puede subir la imagen “después” manualmente
- [ ] El admin puede reemplazar la imagen resultado si se equivocó
- [ ] La comparación before/after funciona también para modo manual

## Persistencia
- [ ] La imagen original se guarda en Storage
- [ ] La imagen resultado se guarda en Storage
- [ ] Los metadatos de la simulación se guardan correctamente en Firestore
- [ ] Cada simulación queda ligada al paciente correcto
- [ ] El historial de simulaciones del paciente carga correctamente

## Compartir con paciente
- [ ] El admin puede compartir o descompartir una simulación
- [ ] El paciente solo ve simulaciones compartidas
- [ ] El paciente no puede editar simulaciones

## Arquitectura futura
- [ ] El modelo de datos deja listo el campo `mode`
- [ ] Existe espacio para `promptMetadata`
- [ ] La arquitectura permite conectar después un motor real sin rehacer el módulo completo

## Calidad
- [ ] `flutter analyze` ejecuta limpio
- [ ] `flutter test` ejecuta limpio
- [ ] El módulo no rompe navegación ni pantallas de pacientes
- [ ] Los textos dejan claro que es una simulación orientativa

---

# Orden recomendado de implementación (v2.1)

## Fase 1 — Núcleo manual (MVP de negocio)
1. `SimulationModel` con estados `draft/ready/shared/archived`
2. `SimulationRepository` (Firestore + Storage por rutas)
3. creación de `draft` con imagen original
4. carga manual de imagen resultado
5. transición de estado `draft -> ready`
6. compartir/descompartir (`ready <-> shared`)
7. vista paciente (solo `shared`)
8. historial admin/paciente con miniaturas

## Fase 2 — Robustez técnica
9. reglas Firestore/Storage alineadas a visibilidad
10. manejo de reemplazo de imagen resultado
11. archivado (`archived`) sin borrado destructivo
12. disclaimers clínicos en toda la UI

## Fase 3 — Evolución visual
13. `MockSimulationService`
14. `BeforeAfterSlider` avanzado
15. refinamientos UX y accesibilidad

## Fase 4 — Preparación IA futura
16. `FaceDetectionService` (ML Kit) para asistencia de encuadre
17. metadatos de prompt/pipeline en modelo
18. contrato de integración para motor externo (sin activarlo aún)

## Fase 5 — Cierre
19. tests
20. analyze

---

## Estado de implementación (cierre técnico 2026-03-23)

Implementado en código:
- Modelo `SimulationModel` + enums (`mode`, `status`) y serialización.
- Repositorio con persistencia en Firestore/Storage:
  - `watchSimulations`
  - `watchSharedSimulations`
  - `uploadOriginalImage`
  - `uploadResultImage`
  - `saveSimulation`
  - `updateSimulation`
  - `toggleShare`
- Flujo admin completo:
  - modo `manual_doctora`
  - modo `mock` interno local
  - guardado `draft/ready/shared`
  - historial por paciente
  - abrir simulación existente
  - compartir/descompartir
- Comparador `BeforeAfterSlider` reutilizable integrado en admin y paciente.
- Vista paciente solo lectura con filtro estricto de simulaciones compartidas.
- Soporte ML Kit de detección facial y sugerencia de región con ajuste manual y fallback.
- Disclaimers orientativos visibles en admin y paciente.

Pendiente (fuera de este bloque):
- IA externa real (API/Cloud Functions/inpainting real).

# Resultado esperado al cerrar el bloque

Al finalizar este bloque, OCG debe tener un **Simulador de Sonrisa usable desde ya**, donde:
- el admin puede crear simulaciones,
- el sistema soporta mock interno,
- la doctora puede subir manualmente imágenes resultado,
- existe comparación before/after,
- todo queda guardado y ordenado por paciente,
- el paciente puede ver simulaciones compartidas,
- y la arquitectura queda lista para que en el futuro solo se conecte un motor real por API sin rehacer la base del módulo.

---

# Nota final para el desarrollador

NO conviertas este bloque en una integración temprana con APIs externas.  
PRIMERO cierra el producto interno, la UX, la persistencia, el comparador y el historial.  
DESPUÉS, si el uso real demuestra valor, se conecta el motor de generación.

La prioridad aquí no es “magia IA”.  
La prioridad aquí es **producto usable, escalable y listo para evolucionar**.
