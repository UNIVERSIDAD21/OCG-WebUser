# BLOQUE 04 - Preflight de foto y compatibilidad por tratamiento

## Objetivo

Evitar llamadas a OpenAI cuando la foto no sirve o no es compatible con el tratamiento.

Esto reduce costo, evita resultados deformes y mejora la confianza del doctor.

## Estado actual

Ya existe:

- `lib/services/firebase/face_detection_service.dart`
- Detecta rostro con ML Kit en mobile.
- En web devuelve `mlkit_unavailable_web`.
- Sugiere una region de sonrisa.

Falta:

- resultado de calidad estructurado;
- compatibilidad con tratamiento;
- bloqueo antes de generar;
- mensajes accionables;
- persistencia en `photoQuality`.

## Archivos a tocar

- `lib/services/firebase/face_detection_service.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/presentation/simulator_screen.dart`
- `lib/features/simulator/data/models/simulation_model.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `functions/src/simulator/generate_smile_simulation_core.ts`
- `test/features/simulator/simulator_mobile_flow_test.dart`
- `test/features/simulator/simulation_model_test.dart`

Archivo nuevo sugerido:

- `lib/services/simulator/photo_quality_service.dart`

## Modelo de resultado

Crear estructura en Flutter:

```dart
class PhotoQualityResult {
  final String status; // valid | usable_with_warning | rejected
  final double score;
  final List<String> warnings;
  final List<String> blockingReasons;
  final Map<String, dynamic> metadata;
}
```

Persistir como map:

```json
{
  "status": "usable_with_warning",
  "score": 0.72,
  "warnings": ["La sonrisa es pequena."],
  "blockingReasons": [],
  "metadata": {
    "hasFace": true,
    "faceDetectionSource": "mlkit_face_detector",
    "photoType": "frontal_smile"
  }
}
```

## Validaciones minimas

Sin agregar dependencias pesadas, validar:

- bytes no vacios;
- tamano de archivo razonable;
- dimensiones minimas usando decode nativo si es posible;
- rostro detectado cuando ML Kit este disponible;
- region de sonrisa disponible o fallback manual;
- `photoType` requerido para expansor y algunos retenedores.

Estados:

```text
valid: puede generar
usable_with_warning: puede generar con advertencia visible
rejected: no puede generar
```

## Reglas por tratamiento

### Brackets metalicos / esteticos

Foto ideal:

- sonrisa frontal;
- dientes superiores visibles;
- luz suficiente.

Bloquear si:

- no hay dientes visibles;
- no hay rostro y no hay ajuste manual.

Advertir si:

- sonrisa pequena;
- foto de perfil.

### Alineadores

Bloquear si:

- no hay dientes visibles.

Advertir si:

- foto borrosa;
- dientes muy pequenos en encuadre.

### Blanqueamiento

Bloquear si:

- casi no se ven dientes.

Advertir si:

- luz muy amarilla;
- sombra fuerte.

### Carillas / diseno de sonrisa

Bloquear si:

- no se ve sonrisa.

Advertir si:

- foto inclinada;
- sonrisa parcial.

### Expansor de paladar

Bloquear si:

- `photoType` no es `upper_intraoral` o equivalente.
- no se ve arcada superior interna/paladar.

Mensaje:

```text
Para simular expansor de paladar, toma una foto intraoral superior donde se vea el paladar.
```

### Retenedor

Reglas:

- `essix`: puede usar sonrisa frontal, advertencia si poco visible.
- `hawley`: necesita alambre visible esperado; sonrisa frontal amplia.
- `fixed_lingual`: advertir que no sera visible en sonrisa frontal; bloquear solo si el doctor pretende verlo en una foto incompatible.

## UI

Mostrar un bloque compacto despues de cargar foto:

- Estado: foto valida / con advertencias / no apta.
- Warnings.
- Boton cambiar foto si esta rechazada.
- No mostrar tecnicismos al paciente.

Si `photoQuality.status == rejected`:

- Deshabilitar `Generar con IA`.
- No llamar Cloud Function.

Si `usable_with_warning`:

- Permitir generar.
- Mantener advertencia visible para admin.

## Backend

Aunque Flutter haga preflight, backend debe protegerse tambien.

En `generate_smile_simulation_core.ts`:

- Leer `photoQuality` desde request o documento.
- Si `status == rejected`, rechazar con `failed-precondition`.
- Para `palatal_expander`, si `photoQuality.metadata.photoType` no es compatible, rechazar.
- Para `retainer` fijo lingual, advertir/guardar warning si no visible.

No confiar solo en Flutter.

## Restricciones

- No llamar OpenAI si la foto esta rechazada.
- No consumir intento si se bloquea antes de generar.
- No agregar dependencias nuevas salvo que sean necesarias y justificadas.
- No bloquear web solo porque ML Kit no esta disponible; usar warnings y configuracion manual.

## Tests requeridos

Flutter:

- Foto con ML Kit OK crea `photoQuality.status = valid`.
- Web/MLKit unavailable crea warning, no crash.
- Expansor con `photoType = frontal_smile` bloquea generacion.
- `photoQuality.status = rejected` deshabilita boton generar.
- `usable_with_warning` permite generar.

Functions:

- `processGenerateSmileSimulation` rechaza `photoQuality.status = rejected`.
- `palatal_expander` rechaza foto incompatible.
- Rechazo preflight no incrementa `attemptCount`.

Si no hay framework de tests Functions, validar con `npm run build` y cubrir la logica pura con funciones exportadas faciles de probar en bloque final.

## Criterios de cierre

- Admin recibe feedback claro antes de generar.
- Fotos rechazadas no llaman OpenAI.
- Expansor no se genera con sonrisa frontal normal.
- `photoQuality` queda guardado en Firestore.
- `flutter test test/features/simulator` pasa.
- `npm run build` pasa.

## Resultado esperado

El simulador deja de depender de suerte con fotos malas y empieza a proteger la generacion desde Flutter y backend.
