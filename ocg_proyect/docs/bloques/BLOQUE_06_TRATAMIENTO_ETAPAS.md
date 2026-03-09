# BLOQUE_06 — Tratamiento y Etapas del Paciente

> **Stack:** Flutter + Riverpod + Firestore
> **Prioridad:** ALTA — Es el módulo de mayor valor percibido por el paciente
> **Depende de:** Bloque 04 (pacientes) y Bloque 05 (citas) — ambos cerrados ✅

---

## Objetivo del bloque

Implementar el módulo completo de seguimiento de etapas del tratamiento: timeline visual para el paciente, herramienta de cambio de etapa para el admin, historial clínico de cambios, y notificación push automática al avanzar de etapa.

---

## Lo que debes entregar al cerrar este bloque

- [ ] `TreatmentTimeline` widget funcionando con 3 estados visuales (completada, activa, pendiente)
- [ ] Tab de Tratamiento en `PatientDetailScreen` (admin) completamente funcional
- [ ] Tab de Tratamiento en `PatientHomeScreen` / `PatientProfileScreen` (paciente)
- [ ] `UpdateStageDialog` con validación de notas obligatorias
- [ ] `StageHistoryList` con el historial de cambios de la subcolección `stageHistory`
- [ ] `TreatmentRepository` con escritura en `stageHistory` y `patients`
- [ ] `treatment_provider` Riverpod reactivo
- [ ] Notificación push al cambiar etapa (llamada a Cloud Function o escritura directa con FCM)
- [ ] `flutter analyze` ✅ y `flutter test` ✅

---

## Las 7 etapas — enum ya definido en `PatientModel`

```
diagnostico → planificacion → instalacion → seguimientoActivo
                                                    ↓
                                             ajusteFinal → retencion → alta
```

**Regla crítica:** La etapa **solo puede avanzar**. No hay botón de revertir. Si hay un error, el admin agrega una nota en el historial. Esto protege la integridad clínica.

---

## Archivos a crear

### 1. `lib/features/treatment/data/models/stage_history_entry.dart`

```dart
class StageHistoryEntry {
  final String id;
  final TreatmentStage etapaAnterior;
  final TreatmentStage etapaNueva;
  final String notas;          // Obligatorio — mín. 10 caracteres
  final String adminId;        // Quién hizo el cambio
  final DateTime fechaCambio;
}
```

Serialización: `fromJson` y `toJson` estándar con timestamps Firestore.

---

### 2. `lib/features/treatment/data/repositories/treatment_repository.dart`

```dart
class TreatmentRepository {
  final FirebaseFirestore _db;

  // Stream del historial de etapas — subcolección stageHistory, ordenada por fecha desc
  Stream<List<StageHistoryEntry>> watchStageHistory(String patientId);

  // Cambio de etapa: actualiza patients/{id} + escribe en stageHistory/ (batch atómico)
  // Valida: la nueva etapa debe ser mayor que la actual (no puede retroceder)
  Future<void> updateStage({
    required String patientId,
    required TreatmentStage nuevaEtapa,
    required String notas,
    required String adminId,
  });
}
```

**Regla de la escritura en batch:**
1. `batch.update(patients/{patientId}, { etapaActual: nuevaEtapa, updatedAt: serverTimestamp })`
2. `batch.set(patients/{patientId}/stageHistory/{auto}, { ...entry })`
3. `await batch.commit()`

Si la nueva etapa no es posterior a la actual, lanzar `Exception('STAGE_REGRESSION')` antes del batch.

---

### 3. `lib/features/treatment/providers/treatment_provider.dart`

```dart
// Repositorio
final treatmentRepositoryProvider = Provider<TreatmentRepository>(...);

// Stream del historial de un paciente
final stageHistoryProvider = StreamProvider.family<List<StageHistoryEntry>, String>(
  (ref, patientId) => ref.watch(treatmentRepositoryProvider).watchStageHistory(patientId),
);

// Notifier para el cambio de etapa
class UpdateStageNotifier extends AutoDisposeAsyncNotifier<void> {
  Future<void> update({
    required String patientId,
    required TreatmentStage nuevaEtapa,
    required String notas,
    required String adminId,
  });
}
final updateStageProvider = AutoDisposeAsyncNotifierProvider<UpdateStageNotifier, void>(...);
```

---

### 4. `lib/features/treatment/presentation/widgets/treatment_timeline.dart`

Widget vertical con los 7 nodos de etapas.

**Estado visual de cada nodo:**

| Estado | Ícono | Color línea |
|--------|-------|-------------|
| Completada | `Icons.check_circle` | `OcgColors.success` sólido |
| Activa (actual) | `Icons.access_time` con pulso animado | `OcgColors.bronze` |
| Pendiente | `Icons.circle_outlined` | gris punteado |

- El nodo activo tiene un `AnimationController` con `repeat(reverse: true)` para el pulso.
- Al tocar cualquier nodo, expandir una `StageCard` con detalles de esa etapa (fecha de cambio si completada, "En progreso" si activa, "Próximamente" si pendiente).
- La línea entre nodos: usa un `CustomPainter` o simplemente un `Container` de 2px con el color correspondiente.

```dart
class TreatmentTimeline extends StatefulWidget {
  final TreatmentStage etapaActual;
  final List<StageHistoryEntry> historial;
  // Si isAdmin: mostrar botón "Avanzar etapa" en el nodo activo
  final bool isAdmin;
  final VoidCallback? onAdvanceStage;
}
```

---

### 5. `lib/features/treatment/presentation/widgets/update_stage_dialog.dart`

Dialog de confirmación para el admin antes de avanzar la etapa.

**Contenido obligatorio:**
1. Título: `"Avanzar etapa del tratamiento"`
2. Fila visual: `etapaActual → nuevaEtapa` con flechas
3. `TextFormField` para notas — validación: mínimo 10 caracteres, obligatorio
4. Advertencia en rojo: `"Esta acción no se puede deshacer. El historial quedará registrado."`
5. Botón "Confirmar" (`OcgColors.espresso`) — deshabilitado si notas inválidas
6. Botón "Cancelar" en outline

Al confirmar, llama a `updateStageProvider.notifier.update(...)` y cierra el dialog.

---

### 6. `lib/features/treatment/presentation/widgets/stage_history_list.dart`

Lista del historial de cambios de etapa.

Cada ítem muestra:
- Fecha del cambio (formato `dd MMM yyyy, HH:mm`)
- De `etapaAnterior` → `etapaNueva` con un ícono de flecha
- Notas del cambio (texto expandible si es largo)
- Sutilmente: el adminId que realizó el cambio

Si el historial está vacío: `OcgEmptyState` con texto "Sin cambios de etapa registrados aún."

---

### 7. Llenar el tab de Tratamiento — Admin (`patient_treatment_tab.dart`)

```dart
// lib/features/patients/presentation/tabs/patient_treatment_tab.dart
// Este archivo ya existe como stub — llenarlo ahora

Widget build:
  - TreatmentTimeline(
      etapaActual: patient.etapaActual,
      historial: stageHistory,
      isAdmin: true,
      onAdvanceStage: () => showDialog(UpdateStageDialog),
    )
  - StageHistoryList(historial: stageHistory)
```

---

### 8. Llenar el tab de Tratamiento — Paciente (`patient_home_screen.dart` o nuevo widget)

En `PatientHomeScreen`, agregar una sección de tratamiento visible con:
- `TreatmentTimeline` en modo solo lectura (`isAdmin: false`)
- `TreatmentProgressBar`: barra horizontal simple que muestra `X / 7 etapas`

```dart
class TreatmentProgressBar extends StatelessWidget {
  final TreatmentStage etapaActual;
  // Muestra: LinearProgressIndicator con valor = indiceEtapa / 6 (0 a 1)
  // Label: "Etapa 3 de 7 — Instalación"
}
```

---

## Reglas de implementación

1. **Riverpod puro.** Cero `FutureBuilder` / `StreamBuilder` directos.
2. **Batch atómico** en `updateStage` — nunca escribir en dos documentos por separado.
3. **Validar regresión de etapa** antes del batch. Lanzar error descriptivo.
4. **El historial no se edita ni elimina.** La regla de Firestore ya lo prohíbe — respetar eso en el repositorio también (no exponer método delete).
5. **Animación del nodo activo:** usar `SingleTickerProviderStateMixin` en el widget `TreatmentTimeline`. No usar paquetes externos para esto.
6. Los colores del timeline deben ser 100% tokens OCG. Sin hardcodeo de colores.

---

## Criterios de cierre del bloque

- [ ] Admin puede ver timeline con historial en el tab de Tratamiento del paciente
- [ ] Admin puede abrir `UpdateStageDialog`, escribir notas y confirmar el avance
- [ ] El cambio se refleja en tiempo real en Firestore (stream reactivo)
- [ ] El paciente ve su timeline en modo solo lectura con su etapa actual destacada
- [ ] `StageHistoryList` muestra el historial correctamente ordenado
- [ ] Validación impide: notas vacías, etapa igual o anterior
- [ ] Notificación push enviada al paciente al cambiar etapa (ver BLOQUE_09)
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅ (tests de validación de regresión y serialización de StageHistoryEntry)

---

## Orden recomendado de ejecución

1. `StageHistoryEntry` model + serialización + test
2. `TreatmentRepository` con batch + validación de regresión
3. `treatment_provider` Riverpod
4. `TreatmentTimeline` widget (sin animación primero, luego agregar)
5. `UpdateStageDialog`
6. `StageHistoryList`
7. Llenar `patient_treatment_tab.dart` (admin)
8. Agregar `TreatmentProgressBar` en pantalla paciente
9. Validación manual + análisis + tests
