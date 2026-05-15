# 02 — Base de Datos: Esquema de Firestore (Versión Final)

> **Tu objetivo en este bloque:** diseñar e implementar el esquema completo de Firestore, los modelos Dart con serialización, las reglas de seguridad y los índices necesarios. Todo lo demás depende de que esto esté bien hecho.

---

## ⚠️ VERSIÓN FINAL — Todas las correcciones integradas

Este documento incorpora todas las correcciones críticas aplicadas al proyecto:
- **BD-01**: fotosUrls movido a subcolección `patients/{patientId}/photos/`
- **BD-02**: `fotosIds` agregado a `StageHistoryEntry` como array
- **BD-03**: `payments` usa `patientId` como ID (relación 1:1 directa)
- **BD-04**: `NotificationModel.data` reemplazado por campos tipados
- **BD-05**: `SmileSimulationModel` con `compartida` y `fechaCompartida`
- **BD-06**: 7 índices compuestos para recordatorios y búsquedas
- **DAT-01**: `saldoPendiente` en payments es FUENTE DE VERDAD
- **CIT-01**: `createAppointment` usa Firestore Transaction

---

## Lo que debes entregar al terminar este bloque

- [ ] Los 6 modelos Dart implementados con fromJson / toJson
- [ ] Los enums correctamente definidos
- [ ] Las reglas de seguridad de Firestore escritas y probadas en el emulador
- [ ] Los 7 índices compuestos creados en firestore.indexes.json
- [ ] Tests unitarios de serialización de cada modelo
- [ ] Seed data creado y validado en Firebase Console

---

## Arquitectura de la base de datos

No existe una colección `users` genérica. El sistema tiene dos tipos de usuario con estructuras distintas. Los datos se separan en seis colecciones raíz:

```
admins/          ← Perfiles de los administradores (la doctora)
patients/        ← Perfiles de los pacientes con datos clínicos
appointments/    ← Todas las citas de la clínica
payments/        ← Planes de pago por paciente (ID = patientId) — BD-03
simulations/     ← Resultados del Simulador de Sonrisa
notifications/   ← Log de notificaciones enviadas
```

La identidad en Firebase Auth (uid) apunta directamente a un documento en `admins/{uid}` o `patients/{uid}`. El rol se determina leyendo en cuál de las dos colecciones existe el documento. **No hay campo `role` suelto en Auth**— se usan Custom Claims. Ver `03_AUTENTICACION_Y_ROLES.md`.

---

## Colección: `admins/{adminId}`

El adminId es el mismo uid de Firebase Auth.

```dart
class AdminModel {
  final String id;              // uid de Firebase Auth
  final String nombre;          // Nombre completo de la doctora
  final String email;           // Correo de login
  final String telefono;        // WhatsApp de contacto
  final String? fotoUrl;        // URL foto de perfil en Storage (temporal)
  final String fcmToken;        // Token FCM — actualizar en cada login y onTokenRefresh
  final DateTime createdAt;     // Automático con serverTimestamp()
  final DateTime updatedAt;     // Automático con serverTimestamp()
}
```

**Notas importantes:**
- Solo habrá 1 o 2 documentos en esta colección en toda la vida del sistema.
- No tiene subcolecciones.
- El fcmToken se actualiza cada vez que el admin inicia sesión.
- La fotoUrl debe ser una URL firmada temporal (válida 1 semana).

---

## Colección: `patients/{patientId}`

El patientId es el mismo uid de Firebase Auth del paciente.

```dart
class PatientModel {
  final String id;                      // uid de Firebase Auth
  final String nombre;                  // Nombre completo
  final String email;                   // Correo de login
  final String telefono;                // WhatsApp del paciente
  final DateTime fechaNacimiento;       // Para calcular edad
  final String? fotoUrl;                // URL foto de perfil (temporal)

  // Datos clínicos del tratamiento
  final TreatmentType tipoTratamiento;  // Enum — ver abajo
  final TreatmentStage etapaActual;     // Enum — etapa en curso
  final DateTime fechaInicio;           // Inicio del tratamiento
  final DateTime? fechaEstimadaFin;     // Estimado de finalización
  final String notasClinicas;           // Solo visible para admin

  // Datos financieros (resumen — detalle en colección payments)
  final double totalTratamiento;        // Valor total acordado (COP)
  final double saldoPendiente;          // CACHE — fuente de verdad en payments/{patientId}
  final DateTime? fechaProximoPago;     // Para recordatorio automático

  // Metadata
  final String fcmToken;                // Token FCM para push notifications
  final DateTime createdAt;             // Automático
  final DateTime updatedAt;             // Automático
}
```

**⚠️ BD-01 CRÍTICO:** El array `fotosUrls` ha sido **MOVIDO a subcolección**. El documento del paciente NO contiene un array de URLs — eso ahora está en `patients/{patientId}/photos/`.

---

## Subcolección: `patients/{patientId}/photos` [BD-01]

**Razón de cambio:** El array `fotosUrls` en el documento del paciente presenta riesgo de exceder el límite de 1MB por documento con el tiempo. Además, falta paginación, filtrado por fecha y metadatos individuales por foto. En ortodoncia, el registro fotográfico es parte del historial clínico crítico.

**Nueva solución:** Crear una subcolección que permite:
- Ilimitadas fotos sin riesgo de overflow
- Paginación y filtrado eficiente
- Metadatos por cada foto (tipo, etapa, notas)
- Indexación por fecha y tipo

```dart
class PatientPhoto {
  final String id;
  final String url;                // URL firmada en Storage (válida 1 semana)
  final String tipo;               // frontal | lateral | oclusal | rxPanoramica | otro
  final TreatmentStage? etapa;     // Etapa clínica asociada (opcional)
  final String? notas;             // Descripción de la foto (ej: "Antes de instalación")
  final String subidaPor;          // adminId que subió la foto
  final DateTime createdAt;        // Automático
}
```

**Acceso en el código:**
```dart
static String patientPhotos(String patientId) => 'patients/$patientId/photos';
```

**Ejemplo de uso en Dart:**
```dart
// Subir una foto
await _db.collection(FirestorePaths.patientPhotos(patientId))
    .doc()
    .set(patientPhoto.toJson());

// Recuperar fotos de una etapa
_db.collection(FirestorePaths.patientPhotos(patientId))
    .where('etapa', isEqualTo: TreatmentStage.instalacion.name)
    .orderBy('createdAt', descending: true)
    .snapshots()
```

---

## Subcolección: `patients/{patientId}/stageHistory` [BD-02]

Registro histórico de cada cambio de etapa. El admin no puede editar el historial, solo agregar nuevas entradas.

```dart
class StageHistoryEntry {
  final String id;
  final TreatmentStage etapa;
  final DateTime fecha;
  final String notas;          // Observaciones de la doctora al cambiar la etapa (mínimo 10 caracteres)
  final String cambiadoPor;    // adminId que realizó el cambio
  final List<String> fotosIds; // ⚠️ BD-02: IDs de fotos del momento del cambio (ARRAY, no string)
}
```

**Razón:** Asociar fotografías clínicas al historial de cambios de etapa permite una trazabilidad completa del caso. Cuando se expande una etapa en el timeline, se cargan sus fotos asociadas.

**Nota crítica:** `fotosIds` es un **array de strings**, no una string individual. Esto permite:
```dart
// Query: "Dame todas las etapas que tengan la foto XYZ"
_db.collection(FirestorePaths.stageHistory(patientId))
    .where('fotosIds', arrayContains: 'seed_photo_1')
    .snapshots()
```

---

## Enums de tratamiento

```dart
enum TreatmentType {
  convencional,    // Ortodoncia convencional con brackets metálicos
  estetico,        // Brackets de cerámica o zafiro
  autoligado,      // Sistema de autoligado
  alineadores,     // Alineadores transparentes removibles (tipo Invisalign)
  ortopedia,       // Ortopedia maxilar — guía de crecimiento
  retenedores,     // Solo fase de retención
}

enum TreatmentStage {
  diagnostico,         // Valoración inicial, rx, fotos, plan
  planificacion,       // Plan aprobado, presupuesto firmado
  instalacion,         // Colocación de brackets o alineadores
  seguimientoActivo,   // Controles periódicos y ajustes
  ajusteFinal,         // Refinamientos y detallado final
  retencion,           // Retenedores instalados
  alta,                // Tratamiento completado
}
```

**Regla importante:** la etapa solo puede avanzar, nunca retroceder. Si necesitas corregir un error de etapa, crea una nota en el historial explicando el ajuste. No borres registros del historial.

**En Firestore:** Siempre guardar como `.name` (ejemplo: `"diagnostico"`, no el enum object).

---

## Colección: `appointments/{appointmentId}` [CIT-01]

```dart
class AppointmentModel {
  final String id;
  final String patientId;          // Referencia al paciente
  final String patientName;        // Desnormalizado para queries rápidas
  final String patientPhone;       // Para contacto rápido del admin
  final DateTime fechaHora;        // Fecha y hora exacta
  final int duracionMinutos;       // 30, 45 o 60
  final AppointmentType tipo;      // Enum — ver abajo
  final AppointmentStatus estado;  // Enum — ver abajo
  final String notas;              // Indicaciones de la cita
  final String creadoPor;          // 'admin' o el patientId
  final bool recordatorio24hEnviado;
  final bool recordatorio2hEnviado;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum AppointmentType {
  valoracion,    // Primera cita — diagnóstico inicial
  instalacion,   // Colocación de aparatos
  control,       // Control mensual de seguimiento
  ajuste,        // Ajuste específico entre controles
  urgencia,      // Cita de urgencia (bracket suelto, dolor, etc.)
  alta,          // Cita de finalización del tratamiento
}

enum AppointmentStatus {
  programada,    // Cita creada — sin confirmar
  confirmada,    // Paciente confirmó asistencia
  completada,    // Cita realizada exitosamente
  cancelada,     // Cancelada (admin o paciente)
  noAsistio,     // Paciente no llegó sin avisar
  reprogramada,  // Se movió a otra fecha (crea una nueva cita)
}
```

**Regla de negocio:** cuando una cita se reprograma, no se edita la fecha de la cita original. Se cambia el estado a `reprogramada` y se crea un documento nuevo con los datos nuevos. Así se mantiene el historial completo.

**⚠️ CIT-01 CRÍTICO:** Las citas usan **Firestore Transaction** en su creación para prevenir race conditions. Dos pacientes NO pueden agendar el mismo horario simultáneamente. Ver sección de repositorio abajo.

---

## Colección: `payments/{patientId}` [BD-03 — RELACIÓN 1:1]

**⚠️ CAMBIO CRÍTICO:** El documentId **DEBE SER IGUAL A patientId**. Esto es una relación 1:1 directa que:
- Elimina la necesidad de queries by patientId
- Simplifica las reglas de seguridad de Firestore
- Permite acceso directo: `_db.collection('payments').doc(patientId)`

```dart
class PaymentModel {
  final String id;                    // ⚠️ CRÍTICO: DEBE SER IGUAL A patientId
  final String patientId;
  final double totalTratamiento;      // Valor total acordado (COP)
  final double montoPagado;           // Suma de todas las transacciones
  final double saldoPendiente;        // totalTratamiento - montoPagado
                                      // ⚠️ FUENTE DE VERDAD (no usar el de patients/)
  final DateTime? fechaProximoPago;   // Para recordatorio automático
  final PaymentStatus estado;         // Enum
  final DateTime createdAt;           // Automático
  final DateTime updatedAt;           // Automático
}

enum PaymentStatus {
  alDia,        // Sin saldo vencido
  pendiente,    // Tiene cuota próxima a vencer (< 7 días)
  vencido,      // Tiene cuota vencida
  pagadoTotal,  // Saldo = 0, tratamiento pagado en su totalidad
}
```

**Acceso en el código:**
```dart
// Acceso DIRECTO — sin necesidad de query
_db.collection('payments').doc(patientId).snapshots()
```

**Importante:** El campo `saldoPendiente` en `patients/{patientId}` es solo un CACHE para facilitar las listas de pacientes. La fuente de verdad está en `payments/{patientId}.saldoPendiente`. **DAT-01: Todos los cálculos usan el valor en payments/, luego se actualiza el cache en patients/.**

### Subcolección: `payments/{patientId}/transactions`

```dart
class PaymentTransaction {
  final String id;
  final double monto;           // Valor de este pago (COP)
  final DateTime fecha;         // Cuándo se registró
  final PaymentMethod metodo;   // Enum
  final String? referencia;     // Referencia bancaria o de Epayco
  final String registradoPor;   // adminId o 'epayco_webhook'
  final String? notas;          // Notas adicionales del pago
}

enum PaymentMethod {
  efectivo,
  transferencia,
  tarjetaCredito,
  tarjetaDebito,
  pse,
  efecty,
  payU,
}
```

---

## Colección: `simulations/{simulationId}` [BD-05]

```dart
class SmileSimulationModel {
  final String id;
  final String patientId;
  final String originalFrenteUrl;    // Foto original frente en Storage
  final String? originalPerfilUrl;   // Foto perfil — opcional, v2.0
  final String simuladoFrenteUrl;    // Resultado IA frente
  final String? simuladoPerfilUrl;   // Resultado IA perfil — v2.0
  final String tipoTratamiento;      // 'braces_removal' | 'aligners' | 'whitening'
  final String promptUsado;          // Prompt enviado a OpenAI — para auditoría
  final String creadoPor;            // adminId o patientId
  final String? notasDoctora;        // Observaciones clínicas opcionales
  
  // ⚠️ BD-05: Campos de auditoría de compartición
  final bool compartida;             // ¿Se compartió por WhatsApp?
  final DateTime? fechaCompartida;   // Cuándo se compartió
  
  final DateTime createdAt;
}
```

**Uso BD-05:** Al hacer tap en "Compartir por WhatsApp":
```dart
await _db.collection('simulations').doc(simulationId).update({
  'compartida': true,
  'fechaCompartida': FieldValue.serverTimestamp(),
});
```

Esto permite auditoría y métricas: "¿Cuántas simulaciones se compartieron este mes?"

---

## Colección: `notifications/{notificationId}` [BD-04]

Solo log de auditoría. El sistema de push es FCM — este documento sirve para que el usuario vea su historial de notificaciones en la app.

```dart
class NotificationModel {
  final String id;
  final String recipientId;        // patientId o adminId
  final String titulo;
  final String cuerpo;
  final NotificationType tipo;     // Enum
  final bool leida;
  
  // ⚠️ BD-04: Campos tipados en lugar de Map genérico
  // Esto permite type-safety, detecta typos en compilación,
  // y permite queries sobre estos campos en el futuro
  final String? appointmentId;     // Para notificaciones de citas
  final String? patientId;         // Para notificaciones de pacientes
  final String? paymentId;         // Para notificaciones de pagos
  
  final DateTime createdAt;
}

enum NotificationType {
  recordatorioCita24h,
  recordatorioCita2h,
  citaCancelada,
  citaReprogramada,
  etapaActualizada,
  pagoProximo,
  pagoRecibido,
  resumenDiarioAdmin,
}
```

---

## Reglas de seguridad de Firestore

Escribe esto en `firestore.rules`. No uses los defaults. No dejes todo en `allow read, write: if true`.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: verifica si el usuario autenticado es admin
    function isAdmin() {
      return request.auth != null &&
             request.auth.token.role == 'admin';
    }

    // Helper: verifica si el uid es el propio paciente
    function isOwnPatient(patientId) {
      return request.auth != null &&
             request.auth.uid == patientId &&
             request.auth.token.role == 'patient';
    }

    // admins/ — solo el propio admin puede leer y escribir su documento
    match /admins/{adminId} {
      allow read, write: if request.auth != null &&
                            request.auth.uid == adminId &&
                            isAdmin();
    }

    // patients/ — admin: lectura y escritura total | paciente: solo su documento
    match /patients/{patientId} {
      allow read: if isAdmin() || isOwnPatient(patientId);
      allow write: if isAdmin();

      // Subcolección photos/ — fotos clínicas
      match /photos/{photoId} {
        allow read: if isAdmin() || isOwnPatient(patientId);
        allow create, update: if isAdmin();
        allow delete: if isAdmin();
      }

      // Subcolección stageHistory/ — historial de cambios de etapa
      match /stageHistory/{entryId} {
        allow read: if isAdmin() || isOwnPatient(patientId);
        allow create: if isAdmin();
        allow update, delete: if false; // El historial no se edita ni elimina
      }
    }

    // appointments/ — admin: todo | paciente: leer y crear sus propias citas
    match /appointments/{appointmentId} {
      allow read: if isAdmin() ||
                    (request.auth != null &&
                     resource.data.patientId == request.auth.uid);
      allow create: if isAdmin() ||
                      (request.auth != null &&
                       request.resource.data.patientId == request.auth.uid &&
                       request.auth.token.role == 'patient');
      allow update: if isAdmin();
      allow delete: if isAdmin();
    }

    // payments/{patientId}/ — BD-03: acceso directo por patientId
    // Nota: paymentId = patientId por lo que no se necesita query adicional
    match /payments/{patientId} {
      allow read: if isAdmin() || isOwnPatient(patientId);
      allow write: if isAdmin();

      match /transactions/{txId} {
        allow read: if isAdmin() || isOwnPatient(patientId);
        allow write: if isAdmin();
      }
    }

    // simulations/ — admin: todo | paciente: leer y crear las suyas
    match /simulations/{simId} {
      allow read: if isAdmin() ||
                    (request.auth != null &&
                     resource.data.patientId == request.auth.uid);
      allow create: if request.auth != null &&
                      (isAdmin() ||
                       request.resource.data.patientId == request.auth.uid);
      allow update, delete: if isAdmin();
    }

    // notifications/ — cada usuario lee solo las suyas
    match /notifications/{notifId} {
      allow read: if request.auth != null &&
                    resource.data.recipientId == request.auth.uid;
      allow create: if isAdmin();
      allow update: if request.auth != null &&
                      resource.data.recipientId == request.auth.uid;
      allow delete: if false;
    }
  }
}
```

---

## Índices compuestos requeridos [BD-06]

Agregar a `firestore.indexes.json`. **Sin estos índices, las Cloud Functions de recordatorios fallarán en producción con "The query requires an index".**

```json
{
  "indexes": [
    {
      "collectionGroup": "appointments",
      "fields": [
        { "fieldPath": "patientId", "order": "ASCENDING" },
        { "fieldPath": "fechaHora", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "appointments",
      "fields": [
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "fechaHora", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "appointments",
      "fields": [
        { "fieldPath": "fechaHora", "order": "ASCENDING" },
        { "fieldPath": "estado", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "appointments",
      "fields": [
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "recordatorio24hEnviado", "order": "ASCENDING" },
        { "fieldPath": "fechaHora", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "appointments",
      "fields": [
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "recordatorio2hEnviado", "order": "ASCENDING" },
        { "fieldPath": "fechaHora", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "simulations",
      "fields": [
        { "fieldPath": "patientId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "photos",
      "fields": [
        { "fieldPath": "etapa", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

**Explicación:**
- Los índices 4 y 5 son **CRÍTICOS** para las Cloud Functions que programan recordatorios. Sin ellos, las queries fallan.
- El índice 6 permite paginar simulaciones por paciente.
- El índice 7 permite filtrar fotos por etapa.

---

## Repository: `appointments_repository.dart` [CIT-01 — Transacción]

```dart
class AppointmentsRepository {
  final FirebaseFirestore _db;
  AppointmentsRepository(this._db);

  // Stream de citas de un día específico (para el calendario del admin)
  Stream<List<AppointmentModel>> watchAppointmentsByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection(FirestorePaths.appointments)
        .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fechaHora', isLessThan: Timestamp.fromDate(end))
        .where('estado', whereNotIn: ['cancelada', 'noAsistio'])
        .orderBy('fechaHora')
        .snapshots()
        .map((s) => s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList());
  }

  // Stream de citas de un paciente específico
  Stream<List<AppointmentModel>> watchPatientAppointments(String patientId) {
    return _db
        .collection(FirestorePaths.appointments)
        .where('patientId', isEqualTo: patientId)
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AppointmentModel.fromJson(d.data())).toList());
  }

  // ⚠️ CIT-01: Crear cita con Firestore Transaction
  // Previene race condition: dos pacientes viendo el mismo horario y creando cita simultáneamente
  Future<String> createAppointment(AppointmentModel appointment) async {
    try {
      final appointmentId = await _db.runTransaction<String>((transaction) async {
        // Query conflictos DENTRO de la transacción
        // Si otro paciente crea una cita en este bloque de tiempo mientras
        // ejecutamos esta query, la transacción se reintentar automáticamente
        final conflictingQuery = _db
            .collection(FirestorePaths.appointments)
            .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(appointment.fechaHora))
            .where('fechaHora', isLessThan: Timestamp.fromDate(
              appointment.fechaHora.add(Duration(minutes: appointment.duracionMinutos))
            ))
            .where('estado', whereNotIn: ['cancelada', 'noAsistio', 'reprogramada']);

        final conflicts = await transaction.get(conflictingQuery);

        if (conflicts.docs.isNotEmpty) {
          // Horario ya fue tomado — lanzar excepción especial
          throw FirebaseException(
            plugin: 'appointments',
            code: 'SLOT_TAKEN',
            message: 'Este horario acaba de ser tomado. Por favor elige otro.',
          );
        }

        // No hay conflicto — crear la cita dentro de la transacción
        final ref = _db.collection(FirestorePaths.appointments).doc();
        final appointmentWithId = appointment.copyWith(id: ref.id);
        transaction.set(ref, appointmentWithId.toJson());

        return ref.id;
      });

      return appointmentId;
    } catch (e) {
      // Capturar la excepción específica de horario tomado
      if (e is FirebaseException && e.code == 'SLOT_TAKEN') {
        throw Exception('SLOT_TAKEN: ${e.message}');
      }
      rethrow;
    }
  }

  // Actualizar estado de una cita
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus newStatus,
  ) async {
    await _db
        .collection(FirestorePaths.appointments)
        .doc(appointmentId)
        .update({
      'estado': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Reprogramar cita (cambia estado de la original + crea nueva)
  Future<void> rescheduleAppointment({
    required String originalId,
    required AppointmentModel newAppointment,
  }) async {
    final batch = _db.batch();
    final newRef = _db.collection(FirestorePaths.appointments).doc();

    batch.update(
      _db.collection(FirestorePaths.appointments).doc(originalId),
      {
        'estado': AppointmentStatus.reprogramada.name,
        'updatedAt': FieldValue.serverTimestamp()
      },
    );

    batch.set(newRef, newAppointment.copyWith(id: newRef.id).toJson());
    await batch.commit();
  }
}
```

---

## Repository: `payments_repository.dart` [DAT-01 — Fuente de verdad]

```dart
class PaymentsRepository {
  final FirebaseFirestore _db;

  // BD-03: Acceso directo — paymentId = patientId
  Stream<PaymentModel?> watchPatientPayments(String patientId) {
    return _db
        .collection(FirestorePaths.payments)
        .doc(patientId)  // Acceso DIRECTO, no query
        .snapshots()
        .map((snap) => snap.exists ? PaymentModel.fromJson(snap.data()!) : null);
  }

  Stream<List<PaymentTransaction>> watchTransactions(String patientId) {
    return _db
        .collection(FirestorePaths.transactions(patientId))
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PaymentTransaction.fromJson(d.data()))
            .toList());
  }

  // Registrar pago manual (admin)
  // ⚠️ DAT-01: Actualizar payments/ (fuente de verdad) + patients/ (cache)
  Future<void> registerManualPayment({
    required String patientId,
    required double monto,
    required PaymentMethod metodo,
    required String adminId,
    String? referencia,
    String? notas,
  }) async {
    final batch = _db.batch();

    // 1. Verificar que saldo no se vuelva negativo
    final paymentDoc = await _db.collection(FirestorePaths.payments).doc(patientId).get();
    if (!paymentDoc.exists) {
      throw Exception('No existe registro de pago para este paciente');
    }

    final paymentData = paymentDoc.data() as Map<String, dynamic>;
    final saldoActual = (paymentData['saldoPendiente'] as num).toDouble();

    if (monto > saldoActual) {
      throw Exception(
        'El monto (\$${monto.toStringAsFixed(0)}) supera el saldo pendiente (\$${saldoActual.toStringAsFixed(0)})',
      );
    }

    // 2. Agregar transacción
    final txRef = _db.collection(FirestorePaths.transactions(patientId)).doc();
    batch.set(txRef, {
      'id': txRef.id,
      'monto': monto,
      'fecha': FieldValue.serverTimestamp(),
      'metodo': metodo.name,
      'referencia': referencia,
      'registradoPor': adminId,
      'notas': notas,
    });

    // 3. Actualizar payment (FUENTE DE VERDAD)
    batch.update(
      _db.collection(FirestorePaths.payments).doc(patientId),
      {
        'montoPagado': FieldValue.increment(monto),
        'saldoPendiente': FieldValue.increment(-monto),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // 4. Actualizar patient (CACHE para listas)
    batch.update(
      _db.collection(FirestorePaths.patients).doc(patientId),
      {
        'saldoPendiente': FieldValue.increment(-monto),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }
}
```

---

## FirestorePaths — Constantes de Firestore

```dart
// lib/shared/constants/firestore_paths.dart
class FirestorePaths {
  FirestorePaths._();
  
  static const String admins       = 'admins';
  static const String patients     = 'patients';
  static const String appointments = 'appointments';
  static const String payments     = 'payments';
  static const String simulations  = 'simulations';
  static const String notifications = 'notifications';

  static String adminDoc(String adminId)     => 'admins/$adminId';
  static String patientDoc(String patientId) => 'patients/$patientId';
  
  // BD-01: Subcolección de fotos
  static String patientPhotos(String patientId) => 'patients/$patientId/photos';
  static String patientPhoto(String patientId, String photoId) => 
      'patients/$patientId/photos/$photoId';
  
  // BD-02: Subcolección de historial de etapas
  static String stageHistory(String patientId) => 'patients/$patientId/stageHistory';
  
  // BD-03: payments usa patientId como docId
  static String paymentDoc(String patientId) => 'payments/$patientId';
  static String transactions(String patientId) => 'payments/$patientId/transactions';
  
  static String simulationDoc(String simulationId) => 'simulations/$simulationId';
  static String notificationDoc(String notificationId) => 'notifications/$notificationId';
}
```

---

## Tests de serialización — No te los saltes

Por cada modelo debes tener tests así:

```dart
void main() {
  group('PatientModel', () {
    test('serializa y deserializa correctamente', () {
      final original = PatientModel(
        id: 'test_uid_123',
        nombre: 'María González',
        email: 'maria@test.com',
        telefono: '+573001234567',
        fechaNacimiento: DateTime(1990, 5, 15),
        fotoUrl: 'https://example.com/photo.jpg',
        tipoTratamiento: TreatmentType.convencional,
        etapaActual: TreatmentStage.diagnostico,
        fechaInicio: DateTime.now(),
        fechaEstimadaFin: DateTime.now().add(Duration(days: 730)),
        notasClinicas: 'Paciente con sobremordida',
        totalTratamiento: 3500000,
        saldoPendiente: 2100000,
        fechaProximoPago: DateTime.now().add(Duration(days: 30)),
        fcmToken: 'token_123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = original.toJson();
      final restored = PatientModel.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.nombre, equals(original.nombre));
      expect(restored.email, equals(original.email));
      expect(restored.telefono, equals(original.telefono));
      expect(restored.fechaNacimiento, equals(original.fechaNacimiento));
      expect(restored.tipoTratamiento, equals(original.tipoTratamiento));
      expect(restored.etapaActual, equals(original.etapaActual));
      expect(restored.totalTratamiento, equals(original.totalTratamiento));
      expect(restored.saldoPendiente, equals(original.saldoPendiente));
    });

    test('maneja null fields correctamente', () {
      final json = {
        'id': 'test_uid',
        'nombre': 'Test',
        'email': 'test@test.com',
        'telefono': '3001234567',
        'fechaNacimiento': Timestamp.fromDate(DateTime(2000, 1, 1)),
        'fotoUrl': null,
        'tipoTratamiento': 'convencional',
        'etapaActual': 'diagnostico',
        'fechaInicio': Timestamp.fromDate(DateTime.now()),
        'fechaEstimadaFin': null,
        'notasClinicas': '',
        'totalTratamiento': 1000,
        'saldoPendiente': 1000,
        'fechaProximoPago': null,
        'fcmToken': '',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      final patient = PatientModel.fromJson(json);
      expect(patient.fotoUrl, isNull);
      expect(patient.fechaEstimadaFin, isNull);
    });
  });
}
```

---

## Diagrama de relaciones

```
┌─────────────────┐
│    admins       │ (1-2 documentos)
└─────────────────┘
         │
         ├──→ Crea/Actualiza → patients
         ├──→ Crea           → appointments (CIT-01: Transaction)
         ├──→ Registra       → payments (DAT-01: saldoPendiente es fuente de verdad)
         └──→ Genera         → simulations (BD-05: auditoría de compartición)

┌─────────────────┐
│    patients     │ (N documentos)
└─────────────────┘
         │
         ├──→ [subcolección] photos/        (BD-01: ilimitadas fotos)
         ├──→ [subcolección] stageHistory/  (BD-02: timeline de cambios)
         │
         ├──→ Agenda/Cancela → appointments
         ├──→ Vinculado a    → payments/{patientId} (BD-03: ID = patientId)
         ├──→ Crea/Comparte  → simulations
         └──→ Recibe         → notifications (BD-04: campos tipados)

┌──────────────────────┐
│ payments/{patientId} │ (1 doc por paciente, ID = patientId)
└──────────────────────┘
         │
         └──→ [subcolección] transactions/  (historial de pagos)

┌──────────────────────┐
│ appointments         │ (N documentos)
└──────────────────────┘
         │
         └──→ Dispara → FCM recordatorios (con índices BD-06)

┌──────────────────────┐
│ simulations          │ (N documentos)
└──────────────────────┘
         │
         └──→ Notifica compartición (BD-05)

┌──────────────────────┐
│ notifications        │ (N documentos, log)
└──────────────────────┘
         (Append-only, no borrable)
```

---

## Checklist de validación final

- [ ] `id` en cada documento coincide con el ID del documento en Firestore
- [ ] Todos los campos `timestamp` son de tipo `timestamp` en Firestore (no string)
- [ ] Todos los campos `updatedAt` están correctamente nombrados (no `updateAt`)
- [ ] `patients.stageHistory.fotosIds` es un **array** de strings, no un string individual
- [ ] `payments/{patientId}` tiene ID exactamente igual a `patientId`
- [ ] `saldoPendiente` en payments = totalTratamiento - montoPagado
- [ ] Todos los enums usan `.name` (ejemplo: `"diagnostico"`, no enum object)
- [ ] Timestamps están en la zona horaria correcta (UTC-5 para Colombia)
- [ ] Las 7 reglas de seguridad están implementadas en `firestore.rules`
- [ ] Los 7 índices compuestos están en `firestore.indexes.json`
- [ ] No hay documentos en colecciones que no deberían existir
- [ ] Cada modelo tiene tests unitarios de serialización/deserialización

---

## Referencias de documentos relacionados

- **03_AUTENTICACION_Y_ROLES.md** — Custom Claims y gestión de roles
- **04_GESTION_PACIENTES.md** — CRUD y pantallas de pacientes
- **05_AGENDA_CITAS.md** — Citas con Transaction (CIT-01)
- **06_TRATAMIENTO_Y_ETAPAS.md** — Timeline y historial de etapas (BD-02)
- **07_PAGOS.md** — Gestión de pagos (DAT-01)
- **08_SIMULADOR_SONRISA.md** — Simulador con auditoría (BD-05)
- **09_NOTIFICACIONES_FCM.md** — Notificaciones con Cloud Functions y índices (BD-06)
