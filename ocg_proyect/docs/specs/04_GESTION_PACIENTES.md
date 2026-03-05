# 04 — Gestión de Pacientes

> **Tu objetivo:** sistema completo de gestión de pacientes. El admin puede ver la lista, crear perfiles clínicos, editarlos y ver el detalle completo. El paciente puede ver y editar solo su propio perfil.

---

## Lo que debes entregar al terminar este bloque

- [ ] PatientsListScreen con buscador y filtros funcionando
- [ ] PatientDetailScreen con TabBar y todas las pestañas
- [ ] PatientFormScreen para crear y editar datos del paciente
- [ ] patients_repository.dart con todos los métodos CRUD
- [ ] patients_provider.dart con estado reactivo y streams de Firestore
- [ ] PatientProfileScreen para el propio paciente

---

## patients_repository.dart

```dart
class PatientsRepository {
  final FirebaseFirestore _db;
  PatientsRepository(this._db);

  // Stream en tiempo real de todos los pacientes (para el admin)
  Stream<List<PatientModel>> watchAllPatients() {
    return _db
        .collection(FirestorePaths.patients)
        .orderBy('nombre')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PatientModel.fromJson(doc.data()))
            .toList());
  }

  // Stream de un solo paciente (para el detail screen)
  Stream<PatientModel?> watchPatient(String patientId) {
    return _db
        .collection(FirestorePaths.patients)
        .doc(patientId)
        .snapshots()
        .map((doc) => doc.exists ? PatientModel.fromJson(doc.data()!) : null);
  }

  // Actualizar datos clínicos del paciente (solo admin)
  Future<void> updatePatientClinicalData(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .collection(FirestorePaths.patients)
        .doc(patientId)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Actualizar etapa del tratamiento + crear entrada en historial
  Future<void> updateTreatmentStage({
    required String patientId,
    required TreatmentStage newStage,
    required String notas,
    required String adminId,
  }) async {
    final batch = _db.batch();

    // 1. Actualizar etapa en el documento del paciente
    batch.update(
      _db.collection(FirestorePaths.patients).doc(patientId),
      {
        'etapaActual': newStage.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // 2. Crear entrada en el historial
    final historyRef = _db
        .collection(FirestorePaths.stageHistory(patientId))
        .doc();
    batch.set(historyRef, {
      'id': historyRef.id,
      'etapa': newStage.name,
      'fecha': FieldValue.serverTimestamp(),
      'notas': notas,
      'cambiadoPor': adminId,
    });

    await batch.commit();
  }
}
```

---

## PatientsListScreen — Pantalla de lista de pacientes

Esta es la pantalla principal del admin después del dashboard.

Componentes visuales:
1. **AppBar** con título "Pacientes" y botón de búsqueda
2. **Barra de filtros** horizontal scrolleable: "Todos" · "Activos" · "Alta" · por tipo de tratamiento
3. **Lista de PatientCards** con lazy loading (usa ListView.builder siempre, nunca Column con map)
4. **FAB** para acceder a la búsqueda o agregar funcionalidad futura

Cada PatientCard muestra:
- Avatar (foto o iniciales con fondo bronze)
- Nombre completo
- Tipo de tratamiento como OcgChip
- Etapa actual como OcgChip con color semántico
- Próxima cita (fecha corta) o "Sin cita programada"

El buscador filtra en tiempo real por nombre. La búsqueda es local sobre la lista ya cargada del stream — no hagas una query a Firestore por cada letra.

**Advertencia:** no uses FutureBuilder directamente en la UI. Usa StreamProvider de Riverpod y ConsumerWidget. El stream ya maneja los estados de carga y error.

---

## PatientDetailScreen — Vista completa del paciente

TabBar con 5 pestañas:

| Tab | Contenido |
|---|---|
| Perfil | Datos personales + foto + datos de contacto |
| Tratamiento | Etapa actual + timeline + historial de cambios |
| Citas | Lista de citas próximas e historial |
| Pagos | Estado financiero + lista de transacciones |
| Simulador | Acceso al simulador y historial de simulaciones |

Cada tab es un Widget separado. No pongas todo en un solo archivo gigante de 800 líneas.

---

## Pantalla de perfil del paciente (vista propia)

El paciente ve su propio perfil pero no puede editar los campos clínicos (tipo de tratamiento, etapa, notas). Solo puede editar:
- Su foto de perfil
- Su número de teléfono
- Su contraseña (a través de ForgotPassword)

Los campos clínicos aparecen como texto de solo lectura con un ícono de candado discreto que indica que son gestionados por la clínica.
