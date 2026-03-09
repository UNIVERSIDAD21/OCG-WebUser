# BLOQUE_08 — Simulador de Sonrisa

> **Stack:** Flutter + Firebase Storage + OpenAI API (inpainting) + ML Kit (detección facial)
> **Prioridad:** ALTA — Feature estrella de OCG, diferenciador comercial
> **Depende de:** Bloque 04 (pacientes) ✅, Bloque 01 (StoragePaths) ✅

---

## Objetivo del bloque

Implementar el simulador de sonrisa: el paciente o la doctora sube una foto del paciente, el sistema detecta la boca con ML Kit, envía la imagen a OpenAI con un prompt específico de ortodoncia, y devuelve una imagen mejorada de la sonrisa que se puede comparar con el original usando `BeforeAfterSlider`.

---

## Lo que debes entregar al cerrar este bloque

- [ ] `ImagePickerService` — captura / selección de imagen desde cámara y galería
- [ ] `FaceDetectionService` — ML Kit para detectar la región de la boca
- [ ] `OpenAiService` — llamada real a la API de inpainting de OpenAI
- [ ] `SimulationRepository` — persistencia en Firestore y Storage
- [ ] `simulation_provider` Riverpod con estados de progreso
- [ ] `BeforeAfterSlider` widget (ya especificado en Bloque 01 — implementarlo aquí)
- [ ] `SimulatorScreen` completa para admin y paciente
- [ ] Tab de Simulador en `PatientDetailScreen` funcional
- [ ] `flutter analyze` ✅ y `flutter test` ✅

---

## Flujo completo del simulador

```
1. Usuario toca "Simular sonrisa"
2. Selecciona foto (cámara o galería)
3. ML Kit analiza la imagen → genera máscara de la región bucal
4. Imagen + máscara → OpenAI inpainting API
5. OpenAI devuelve imagen con sonrisa mejorada
6. Se muestra resultado con BeforeAfterSlider
7. Admin/Paciente puede guardar el resultado en Firestore/Storage
8. El resultado queda en la subcolección simulations/{id}
```

---

## Archivos a crear

### 1. `lib/services/api/openai_service.dart`

```dart
class OpenAiService {
  // La API key NUNCA va en el cliente Flutter.
  // Debe estar en Cloud Functions como variable de entorno.
  // El cliente llama a la Cloud Function, que hace la petición real.
  
  // Llama a la Cloud Function 'simulateSmile'
  // Recibe: imageBytes (base64), maskBytes (base64)
  // Devuelve: imageBytes resultado (base64)
  Future<Uint8List> simulateSmile({
    required Uint8List imageBytes,
    required Uint8List maskBytes,
  });
}
```

**Cloud Function `simulateSmile` (functions/src/index.ts):**
```typescript
export const simulateSmile = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '...');
  
  const { imageBase64, maskBase64 } = data;
  
  // Llamar a OpenAI DALL-E inpainting
  const response = await openai.images.edit({
    image: Buffer.from(imageBase64, 'base64'),
    mask: Buffer.from(maskBase64, 'base64'),
    prompt: "Professional dental smile improvement for orthodontic consultation. Natural-looking, healthy teeth, same person, same lighting, photorealistic.",
    n: 1,
    size: "1024x1024",
  });
  
  return { resultBase64: response.data[0].b64_json };
});
```

---

### 2. `lib/services/firebase/image_picker_service.dart`

```dart
class ImagePickerService {
  // Seleccionar desde galería — devuelve bytes
  Future<Uint8List?> pickFromGallery();
  
  // Capturar desde cámara — devuelve bytes
  Future<Uint8List?> captureFromCamera();
  
  // Comprimir imagen a tamaño máximo razonable para API
  // Máximo: 4MB (límite OpenAI), recomendado: < 2MB
  Future<Uint8List> compress(Uint8List bytes, {int maxWidthPx = 1024});
}
```

Dependencias requeridas en `pubspec.yaml`:
```yaml
image_picker: ^1.x.x
flutter_image_compress: ^2.x.x
```

---

### 3. `lib/services/firebase/face_detection_service.dart`

```dart
class FaceDetectionService {
  // Detecta rostros en la imagen
  // Devuelve la región de la boca como Rect normalizado (0.0 a 1.0)
  // Si no detecta boca, devuelve null → el usuario debe enmarcar manualmente
  Future<Rect?> detectMouthRegion(Uint8List imageBytes);
  
  // Genera máscara PNG: blanco en región de boca, negro en el resto
  // La máscara es lo que OpenAI usa para el inpainting
  Future<Uint8List> generateMask(Uint8List imageBytes, Rect mouthRegion);
}
```

Dependencias requeridas:
```yaml
google_mlkit_face_detection: ^0.x.x
```

**Nota:** Si ML Kit no detecta la boca con suficiente precisión, el usuario puede ajustar la región manualmente con un `InteractiveViewer` o un `GestureDetector` sobre la imagen.

---

### 4. `lib/features/simulator/data/models/simulation_model.dart`

```dart
class SimulationModel {
  final String id;
  final String patientId;
  final String originalUrl;      // URL de imagen original en Storage
  final String resultUrl;        // URL de imagen resultado en Storage
  final bool compartidaConPaciente; // Admin puede compartir o no
  final DateTime createdAt;
  final String creadoPor;       // adminId o patientId
}
```

---

### 5. `lib/features/simulator/data/repositories/simulation_repository.dart`

```dart
class SimulationRepository {
  // Stream de simulaciones de un paciente (ordenadas por fecha)
  Stream<List<SimulationModel>> watchSimulations(String patientId);
  
  // Subir imagen original a Storage (StoragePaths.simulationResult)
  Future<String> uploadOriginalImage(String patientId, String simId, Uint8List bytes);
  
  // Subir imagen resultado a Storage
  Future<String> uploadResultImage(String patientId, String simId, Uint8List bytes);
  
  // Guardar simulación en Firestore
  Future<void> saveSimulation(SimulationModel simulation);
  
  // Compartir/descompartir con paciente (solo admin)
  Future<void> toggleShare(String simulationId, bool compartir);
}
```

**Reglas de Storage:**
- Las URLs de fotos son **temporales** (signed URLs) — nunca URLs permanentes públicas
- Usar `StoragePaths.simulationResult(patientId, simId, fileName)`

---

### 6. `lib/features/simulator/providers/simulation_provider.dart`

```dart
final simulationRepositoryProvider = Provider<SimulationRepository>(...);

// Stream de simulaciones de un paciente
final simulationsProvider = StreamProvider.family<List<SimulationModel>, String>(
  (ref, patientId) => ...,
);

// Notifier del proceso de simulación — con estados de progreso
enum SimulatorStep { idle, pickingImage, detectingFace, processing, done, error }

class SimulatorNotifier extends AutoDisposeNotifier<SimulatorState> {
  // Estado incluye: step, originalBytes, resultBytes, errorMessage
  
  Future<void> startSimulation(String patientId, String adminId);
  Future<void> saveResult(String patientId, String createdBy);
  void reset();
}
```

El estado debe exponer el `step` para mostrar progress indicators al usuario.

---

### 7. `lib/shared/widgets/before_after_slider.dart`

Widget interactivo de comparación antes/después.

```dart
class BeforeAfterSlider extends StatefulWidget {
  final Uint8List beforeBytes;  // Imagen original
  final Uint8List afterBytes;   // Imagen resultado
  final double initialPosition; // 0.0 a 1.0 — posición inicial del divisor (default 0.5)
}
```

**Implementación:**
- Usar `Stack` con dos `Image.memory` en capas
- La imagen "after" tiene un `ClipRect` que recorta desde el divisor hacia la derecha
- Una línea vertical blanca con un círculo/handle en el centro
- `GestureDetector` con `onHorizontalDragUpdate` para mover el divisor
- El handle tiene un ícono `Icons.compare_arrows` o similar

---

### 8. `lib/features/simulator/presentation/simulator_screen.dart`

Pantalla completa del simulador (para admin y paciente):

```
Estado: idle
  → Botón "Subir foto" + Botón "Usar cámara"
  
Estado: pickingImage
  → Loading sutil

Estado: detectingFace
  → "Analizando imagen..." + LinearProgressIndicator

Estado: processing
  → "Generando simulación..." + LinearProgressIndicator animado
  → Texto: "Esto puede tardar 10-15 segundos"

Estado: done
  → BeforeAfterSlider con original vs resultado
  → Botón "Guardar simulación" (si admin: también "Compartir con paciente")
  → Botón "Volver a intentar"
  
Estado: error
  → OcgEmptyState con mensaje de error + botón "Intentar de nuevo"
```

---

### 9. Llenar `patient_simulator_tab.dart` (admin)

```dart
// lib/features/patients/presentation/tabs/patient_simulator_tab.dart

Column(
  children: [
    // Lista de simulaciones previas
    SimulationHistoryList(patientId: patientId),
    
    // Botón para nueva simulación
    ElevatedButton.icon(
      icon: Icon(Icons.auto_awesome),
      label: Text('Nueva simulación'),
      onPressed: () => context.push('/admin/patients/$patientId/simulator'),
    ),
  ],
)
```

---

### 10. Rutas nuevas a agregar en `route_names.dart` y `app_router.dart`

```dart
// route_names.dart
static const String adminPatientSimulator = '/admin/patients/:patientId/simulator';
static const String patientSimulator = '/patient/simulator';

// app_router.dart — agregar rutas:
GoRoute(
  path: RouteNames.adminPatientSimulator,
  builder: (context, state) {
    final patientId = state.pathParameters['patientId'] ?? '';
    return SimulatorScreen(patientId: patientId);
  },
),
GoRoute(
  path: RouteNames.patientSimulator,
  builder: (context, state) => const SimulatorScreen(),
),
```

---

## Cloud Function a crear en `functions/src/index.ts`

```typescript
import * as OpenAI from 'openai';

const openai = new OpenAI.OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export const simulateSmile = functions.https.onCall(async (data, context) => {
  // 1. Verificar autenticación
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
  }
  
  // 2. Recibir imagen y máscara en base64
  const { imageBase64, maskBase64 } = data as { imageBase64: string; maskBase64: string };
  
  if (!imageBase64 || !maskBase64) {
    throw new functions.https.HttpsError('invalid-argument', 'Imagen o máscara faltante');
  }
  
  // 3. Llamar a OpenAI DALL-E inpainting
  const response = await openai.images.edit({
    image: Buffer.from(imageBase64, 'base64'),
    mask: Buffer.from(maskBase64, 'base64'),
    prompt: "Professional orthodontic smile simulation. Improve teeth alignment and whitening naturally. Same person, same lighting, photorealistic result.",
    n: 1,
    size: "1024x1024",
    response_format: "b64_json",
  });
  
  return { resultBase64: response.data[0].b64_json };
});
```

**Variables de entorno requeridas en Cloud Functions:**
```
OPENAI_API_KEY=sk-...
```
Configurar con: `firebase functions:config:set openai.key="sk-..."`

---

## Criterios de cierre del bloque

- [ ] El usuario puede seleccionar imagen desde galería o cámara
- [ ] ML Kit detecta la región de la boca (o el usuario ajusta manualmente)
- [ ] La Cloud Function `simulateSmile` está desplegada y funcional
- [ ] `BeforeAfterSlider` muestra la comparación correctamente con drag fluido
- [ ] El admin puede guardar y compartir el resultado con el paciente
- [ ] El paciente ve sus simulaciones previas y puede crear nuevas
- [ ] El tab de Simulador en `PatientDetailScreen` está funcional
- [ ] Las imágenes se almacenan en Storage con las rutas correctas
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅ (serialización SimulationModel, lógica de estados del notifier)

---

## Orden recomendado de ejecución

1. Cloud Function `simulateSmile` (functions/) + variables de entorno
2. `SimulationModel` + serialización + tests
3. `ImagePickerService`
4. `FaceDetectionService` (con ML Kit)
5. `OpenAiService` (cliente que llama a Cloud Function)
6. `SimulationRepository`
7. `simulation_provider`
8. `BeforeAfterSlider` widget
9. `SimulatorScreen` con máquina de estados visual
10. Llenar `patient_simulator_tab.dart`
11. Rutas nuevas en router
12. Validación manual + analyze + tests
