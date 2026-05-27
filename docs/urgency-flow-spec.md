# 🚨 Flujo de Urgencias - OCG Clínica

> **Especificación técnica para implementación completa**
> Combina: solicitud de urgencia in-app con auto-redirección a WhatsApp + admin reprograma citas para dar slot a urgencia
> Proyecto: OCG-WebUser | Repo: `/home/borlty/OCG-WebUser/ocg_proyect`
> Última actualización: 2026-05-27 | Commit verificado en origin/main

---

## 📋 Resumen ejecutivo

Cuando un paciente necesita atención urgente, el flujo es:

1. **El paciente envía solicitud de urgencia in-app**: describe lo que le pasa en un campo de notas → se crea el documento en Firestore → le llega **notificación push al admin** → automáticamente se **redirige al paciente al WhatsApp del admin** para que tengan conversación directa por ahí.
2. **Solo el admin gestiona**: él decide si reprogramar una cita normal existente para darle ese slot al paciente de urgencia. Nadie más mueve la agenda.
3. **Canal directo (fallback)**: un botón secundario para el paciente que quiere ir directo a WhatsApp sin pasar por el formulario in-app.

Todo queda trazado en Firestore: quién pidió, cuándo, qué hizo el admin, y qué cita se reprogramó.

---

## 🏗️ Arquitectura

```
┌─────────────────────┐     Firestore       ┌─────────────────────┐
│   PACIENTE (App)    │ ─────────────────►  │  ADMIN (Dashboard)  │
│                     │                     │                     │
│  ┌───────────────┐  │   urgencyRequests   │  ┌───────────────┐  │
│  │ Escribe notas │  │ ◄─────────────────  │  │ Bandeja de    │  │
│  │ de urgencia   │──│                     │  │  Urgencias    │  │
│  └───────┬───────┘  │                     │  └───────┬───────┘  │
│          │          │                     │          │          │
│          ▼          │   FCM Push          │  ┌───────┴───────┐  │
│  ┌───────────────┐  │ ──────────────────► │  │ Reprograma    │  │
│  │ AUTO-REDIRIGE │  │                     │  │ cita → da slot│  │
│  │ a WhatsApp    │  │   WhatsApp          │  │ a urgencia    │  │
│  │ del admin     │──│──────────────────►  │  └───────────────┘  │
│  │ (conversación │  │                     │                     │
│  │  directa)     │  │                     │                     │
└─────────────────────┘                     └─────────────────────┘
```

---

## 🔑 Bloques de implementación

Cada bloque es independiente y secuencial. Se implementa uno por vez con validación de Jefe entre bloques.

---

### 🔵 BLOQUE 1 — Modelo de datos y enums

**Objetivo:** Definir la estructura de datos para solicitudes de urgencia.

#### 1.1 Nuevo enum `UrgencyStatus`

Archivo: `lib/features/appointments/data/models/urgency_model.dart`

```dart
enum UrgencyStatus {
  pendiente,       // Recién creada, sin atender
  enProceso,       // Admin la vio y está gestionando
  atendida,        // Se creó cita o se atendió por otro canal
  reprogramada,    // Admin movió cita existente para darle slot a esta urgencia
  rechazada,       // No era urgencia real o no aplica
}
```

#### 1.2 Modelo `UrgencyRequestModel`

Archivo: `lib/features/appointments/data/models/urgency_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UrgencyStatus {
  pendiente,
  enProceso,
  atendida,
  reprogramada,
  rechazada,
}

class UrgencyRequestModel {
  const UrgencyRequestModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    required this.descripcion,
    required this.estado,
    required this.createdAt,
    this.updatedAt,
    this.appointmentId,           // Si se creó cita desde esta urgencia
    this.reprogramadaFromId,      // ID de la cita que se reprogramó para dar slot
    this.adminNotes,              // Notas del admin al gestionar
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientPhone;
  final String descripcion;
  final UrgencyStatus estado;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? appointmentId;
  final String? reprogramadaFromId;  // Qué cita se movió para darle este slot
  final String? adminNotes;

  // ─── Serialización ────────────────────────────────────────────────

  factory UrgencyRequestModel.fromJson(Map<String, dynamic> json) {
    return UrgencyRequestModel(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      patientName: (json['patientName'] ?? '').toString(),
      patientPhone: (json['patientPhone'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      estado: UrgencyStatus.values.firstWhere(
        (e) => e.name == (json['estado'] ?? 'pendiente').toString(),
        orElse: () => UrgencyStatus.pendiente,
      ),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
      appointmentId: json['appointmentId']?.toString(),
      reprogramadaFromId: json['reprogramadaFromId']?.toString(),
      adminNotes: json['adminNotes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'descripcion': descripcion,
      'estado': estado.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      if (appointmentId != null) 'appointmentId': appointmentId,
      if (reprogramadaFromId != null) 'reprogramadaFromId': reprogramadaFromId,
      if (adminNotes != null) 'adminNotes': adminNotes,
    };
  }

  UrgencyRequestModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? patientPhone,
    String? descripcion,
    UrgencyStatus? estado,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? appointmentId,
    String? reprogramadaFromId,
    String? adminNotes,
  }) {
    return UrgencyRequestModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      appointmentId: appointmentId ?? this.appointmentId,
      reprogramadaFromId: reprogramadaFromId ?? this.reprogramadaFromId,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  // ─── Parsers ──────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  String get estadoLabel => switch (estado) {
    UrgencyStatus.pendiente => '⏳ Pendiente',
    UrgencyStatus.enProceso => '🔄 En proceso',
    UrgencyStatus.atendida => '✅ Atendida',
    UrgencyStatus.reprogramada => '📅 Reprogramada (de otra cita)',
    UrgencyStatus.rechazada => '❌ Rechazada',
  };

  bool get isActive => estado == UrgencyStatus.pendiente || estado == UrgencyStatus.enProceso;

  /// Color semántico según estado
  String get statusColorHex => switch (estado) {
    UrgencyStatus.pendiente => '#EF4444',
    UrgencyStatus.enProceso => '#F59E0B',
    UrgencyStatus.atendida => '#10B981',
    UrgencyStatus.reprogramada => '#6366F1',
    UrgencyStatus.rechazada => '#6B7280',
  };
}
```

#### 1.3 Estructura en Firestore

Colección: `urgencyRequests/{requestId}`

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | string | Auto-generado por Firestore |
| `patientId` | string | UID del paciente que solicita |
| `patientName` | string | Nombre completo |
| `patientPhone` | string | Teléfono de contacto |
| `descripcion` | string | Lo que le pasa al paciente (notas de urgencia) |
| `estado` | string | `pendiente`, `enProceso`, `atendida`, `reprogramada`, `rechazada` |
| `createdAt` | timestamp | Cuándo se creó |
| `updatedAt` | timestamp | Última modificación |
| `appointmentId` | string? | ID de la cita creada si se atendió |
| `reprogramadaFromId` | string? | ID de la cita que se reprogramó para dar este slot |
| `adminNotes` | string? | Notas del admin al gestionar |

#### 1.4 Reglas Firestore para `urgencyRequests`

Agregar en `firestore.rules`:

```javascript
match /urgencyRequests/{requestId} {
  // Paciente puede crear y leer las suyas
  allow create: if request.auth != null
    && request.resource.data.patientId == request.auth.uid;
  allow read: if request.auth != null
    && (resource.data.patientId == request.auth.uid || isAdmin());
  // Solo admin puede actualizar (cambiar estado, agregar notas, etc.)
  allow update: if isAdmin();
  // Solo admin puede borrar (limpieza histórica)
  allow delete: if isAdmin();
}
```

> **Nota:** `isAdmin()` es la función que ya existe en las reglas actuales que verifica superadmin o rol admin.

---

### 🟢 BLOQUE 2 — UI Paciente: Solicitud de urgencia con notas + auto-redirección a WhatsApp

**Objetivo:** El paciente describe su urgencia en notas → se crea la solicitud → automáticamente se le redirige al WhatsApp del admin para tener conversación directa.

#### 2.1 Ubicación

Archivo a modificar: `lib/features/dashboard/presentation/patient_appointments_screen.dart`

Agregar debajo del botón normal de "Agendar cita" un **bloque destacado** con estilo de alerta:

```
┌──────────────────────────────────────────────┐
│  🚨 ¿Necesitas atención urgente?             │
│                                              │
│  Si tienes una emergencia o dolor severo,    │
│  envíanos tu situación. La clínica te        │
│  responderá lo antes posible.                │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  📝  Solicitar atención prioritaria    │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ── o también ──                             │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  💬  Ir directo a WhatsApp             │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

#### 2.2 Botón principal: Solicitar atención prioritaria

- Abre un `AlertDialog` con:
  - Campo de texto multilinea: **"Describe brevemente lo que te pasa"**
  - Validación: mínimo 10 caracteres
  - Botón **"Enviar solicitud"** → ejecuta el flujo completo:

**Flujo al enviar:**

```dart
Future<void> _submitUrgencyRequest() async {
  final repo = UrgencyRepository();
  final patient = authState.currentUser!;

  // 1. Crear solicitud en Firestore
  final request = await repo.create(
    patientId: patient.uid,
    patientName: patient.displayName ?? 'Paciente',
    patientPhone: patient.phoneNumber ?? '',
    descripcion: _descriptionController.text.trim(),
  );

  // 2. Notificar al admin (FCM push de alta prioridad)
  await _sendUrgencyNotification(request);

  // 3. AUTO-REDIRIGIR a WhatsApp del admin
  final phone = ClinicContact.whatsappNumber;
  final message =
      'Hola, soy ${patient.displayName}. '
      'Acabo de enviar una solicitud de urgencia desde la app. '
      'Necesito atención urgente.';
  final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // 4. Cerrar dialog y mostrar confirmación
  if (mounted) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Solicitud enviada. Se abrió WhatsApp para contacto directo con la clínica.',
        ),
      ),
    );
  }
}
```

#### 2.3 Botón secundario: Ir directo a WhatsApp (fallback)

Para el paciente que **prefiere ir directo a WhatsApp sin pasar por el formulario in-app**:

- NO crea documento en Firestore
- Solo abre WhatsApp con mensaje prellenado
- El admin puede crear la urgencia manualmente desde su dashboard si lo desea

```dart
Future<void> _launchWhatsAppDirect() async {
  final patient = authState.currentUser!;
  final phone = ClinicContact.whatsappNumber;
  final message =
      'Hola, soy ${patient.displayName ?? "un paciente"}. '
      'Necesito atención urgente en OCG Clínica.';
  final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

#### 2.4 Configuración del teléfono de clínica

Archivo nuevo: `lib/core/constants/clinic_contact.dart`

```dart
class ClinicContact {
  static const String whatsappNumber = '+57XXXXXXXXXX';  // ← Número real del admin/clínica
  static const String clinicName = 'OCG Clínica';
}
```

---

### 🟡 BLOQUE 3 — Repositorio de urgencias

**Objetivo:** Capa de datos para CRUD de solicitudes de urgencia.

Archivo nuevo: `lib/features/appointments/data/repositories/urgency_repository.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/urgency_model.dart';

class UrgencyRepository {
  final _collection = FirebaseFirestore.instance.collection('urgencyRequests');

  /// Crear nueva solicitud (paciente)
  Future<UrgencyRequestModel> create({
    required String patientId,
    required String patientName,
    required String patientPhone,
    required String descripcion,
  }) async {
    final docRef = _collection.doc();
    final model = UrgencyRequestModel(
      id: docRef.id,
      patientId: patientId,
      patientName: patientName,
      patientPhone: patientPhone,
      descripcion: descripcion,
      estado: UrgencyStatus.pendiente,
      createdAt: DateTime.now(),
    );
    await docRef.set(model.toJson());
    return model;
  }

  /// Stream de todas las urgencias (admin) — ordenadas por más reciente primero
  Stream<List<UrgencyRequestModel>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UrgencyRequestModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Stream de urgencias de un paciente específico
  Stream<List<UrgencyRequestModel>> watchByPatient(String patientId) {
    return _collection
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UrgencyRequestModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Urgencias activas (pendientes + en proceso) — para admin
  Stream<List<UrgencyRequestModel>> watchActive() {
    return _collection
        .where('estado', whereIn: ['pendiente', 'enProceso'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UrgencyRequestModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Actualizar estado (solo admin)
  Future<void> updateStatus({
    required String requestId,
    required UrgencyStatus newStatus,
    String? adminNotes,
    String? appointmentId,
    String? reprogramadaFromId,
  }) async {
    final data = <String, dynamic>{
      'estado': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (adminNotes != null) data['adminNotes'] = adminNotes;
    if (appointmentId != null) data['appointmentId'] = appointmentId;
    if (reprogramadaFromId != null) data['reprogramadaFromId'] = reprogramadaFromId;
    await _collection.doc(requestId).update(data);
  }

  /// Conteo de urgencias pendientes (para badge en admin)
  Stream<int> countPending() {
    return _collection
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Acción clave: reprogramar una cita existente y dar su slot a la urgencia
  /// SOLO admin puede ejecutar esto.
  Future<void> rescheduleAppointmentForUrgency({
    required String requestId,
    required String originalAppointmentId,
    required String originalPatientId,
    required DateTime newDateTimeForOriginal,
    required DateTime urgentSlotDateTime,
    required String urgentPatientId,
    required String urgentPatientName,m   
    required String urgentPatientPhone,
    required String adminId,
    int duracionMinutos = 30,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Reprogramar la cita original del otro paciente
    final originalApptRef = _getAppointmentRef(originalAppointmentId);
    batch.update(originalApptRef, {
      'estado': 'reprogramada',
      'fechaHora': Timestamp.fromDate(newDateTimeForOriginal),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Crear nueva cita de urgencia en el slot que se liberó
    final urgentApptRef = FirebaseFirestore.instance.collection('appointments').doc();
    final urgentApptData = {
      'id': urgentApptRef.id,
      'patientId': urgentPatientId,
      'patientName': urgentPatientName,
      'patientPhone': urgentPatientPhone,
      'tipo': 'urgencia',
      'estado': 'programada',
      'fechaHora': Timestamp.fromDate(urgentSlotDateTime),
      'duracionMinutos': duracionMinutos,
      'creadoPor': adminId,
      'notas': 'Cita de urgencia — slot liberado por reprogramación',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(urgentApptRef, urgentApptData);

    // Ejecutar atómicamente
    await batch.commit();

    // 3. Marcar urgencia como atendida vía reprogramación
    await updateStatus(
      requestId: requestId,
      newStatus: UrgencyStatus.atendida,
      appointmentId: urgentApptRef.id,
      reprogramadaFromId: originalAppointmentId,
    );
  }

  DocumentReference _getAppointmentRef(String appointmentId) {
    return FirebaseFirestore.instance.collection('appointments').doc(appointmentId);
  }
}
```

---

### 🔴 BLOQUE 4 — UI Admin: Bandeja de urgencias + Reprogramación de citas

> **Poder exclusivo del admin**: solo él puede tomar una cita ya programada, reprogramarla para otro horario, y darle ese slot liberado al paciente de urgencia.

**Objetivo:** El admin ve todas las solicitudes de urgencia y puede gestionarlas.

#### 4.1 Ubicación

- **Admin web (dashboard):** Nueva sección "Urgencias" en el sidebar, al lado de "Agenda"
- **Admin móvil:** Nuevo tab en el bottom nav o un botón destacado en la pantalla de Inicio

#### 4.2 Diseño de la bandeja

```
┌─────────────────────────────────────────────────────────┐
│  🚨 Solicitudes de Urgencia              [3 pendientes] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ ⏳ PENDIENTE                          Hace 5 min │    │
│  │ María García — 300-123-4567                     │    │
│  │ "Dolor intenso en la mandíbula desde anoche"    │    │
│  │ 💬 Paciente ya redirigido a WhatsApp            │    │
│  │                                                 │    │
│  │ [✅ Crear cita] [🔄 Reprogramar→dar slot]      │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ ✅ ATENDIDA                        Hace 2 horas │    │
│  │ Carlos López — 310-987-6543                     │    │
│  │ "Inflamación después de la instalación"         │    │
│  │ Cita: abc123xyz — Slot liberado de cita xyz789  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ─── Historial ───                                      │
│  ✅ Atendida — Ana Martínez — Hace 2 días              │
│  📅 Reprogramada — Juan Pérez — Hace 3 días            │
└─────────────────────────────────────────────────────────┘
```

#### 4.3 Acciones del admin

Cada solicitud pendiente tiene estas acciones:

| Acción | Qué hace |
|---|---|
| **✅ Crear cita** | Abre el dialog normal de crear cita con los datos del paciente ya cargados. El tipo se pre-selecciona como `urgencia`. Al crear la cita, se actualiza la urgencia con `estado: atendida` + `appointmentId`. El admin busca un slot libre normal. |
| **🔄 Reprogramar cita → dar slot** | **Acción clave**: el admin ve las citas del día/semana, selecciona una cita normal existente, la reprograma para otro horario (liberando el slot original), y asigna ese slot liberado al paciente de urgencia. Todo en una operación atómica. La urgencia queda `estado: atendida` con `appointmentId` (nueva cita de urgencia) y `reprogramadaFromId` (cita que se movió). |
| **❌ Rechazar** | (Opcional, con campo de motivo) Cambia estado a `rechazada` |

> **Nota sobre WhatsApp:** No hay botón de WhatsApp en la bandeja del admin porque el paciente **ya fue redirigido automáticamente** al enviar la solicitud. La conversación ya está abierta por ese canal. El admin muestra un indicador "💬 Paciente ya redirigido a WhatsApp" para confirmar.

#### 4.4 Badge de notificación

- El tab/botón de urgencias muestra un **badge rojo** con el count de pendientes
- Se alimenta del stream `countPending()` del repositorio

---

### 🟣 BLOQUE 5 — Crear cita de urgencia desde admin (bypass de disponibilidad)

**Objetivo:** Cuando el admin crea una cita desde una urgencia (sin reprogramar otra), debe poder saltarse las reglas de disponibilidad.

#### 5.1 Modificación al formulario de citas admin

Archivo: `lib/features/appointments/presentation/admin_appointment_form.dart` (o el archivo equivalente del dialog actual)

Cambios:

1. **Parámetro opcional** en el constructor: `UrgencyRequestModel? urgencyRequest`
2. Si viene una urgencia:
   - Pre-llenar paciente (nombre, teléfono, ID)
   - Pre-seleccionar `tipo: AppointmentType.urgencia`
   - Mostrar un banner: "🚨 Citando desde solicitud de urgencia — las validaciones de disponibilidad están desactivadas"
3. **Desactivar validaciones** para urgencias:
   - `validateWithinWorkingHours` → skip (puede agendar fuera de horario si es urgente)
   - `hasTimeConflict` → mostrar advertencia en vez de bloqueo: "⚠️ Hay otra cita en ese horario. ¿Confirmar de todas formas?"
   - `validateNoSameDayAppointment` → skip
4. **Al crear la cita:**
   - Llamar `reserveAppointment` normal O crear directo si el admin tiene permisos
   - Después de crear, actualizar la urgencia: `estado: atendida`, `appointmentId: nuevoId`

#### 5.2 Lógica de bypass

```dart
bool get _isUrgencyBooking => widget.urgencyRequest != null;

String? _validateSlot(DateTime start, int duration) {
  if (_isUrgencyBooking) {
    // En urgencia: solo validar que no sea en el pasado
    return AppointmentsBusinessRules.validateStartNotInPast(start: start);
  }
  // Validaciones normales
  return AppointmentsBusinessRules.validateWithinWorkingHours(
    start: start,
    durationMinutes: duration,
  );
}
```

---

### 🟤 BLOQUE 6 — Reprogramar cita existente para dar slot a urgencia

**Objetivo:** Solo el admin puede tomar una cita normal ya programada, moverla a otro horario, y darle ese slot liberado al paciente de urgencia. Este es el mecanismo principal de "hacer espacio" en la agenda.

#### 6.1 Flujo de reprogramación para urgencia

1. Admin recibe urgencia pendiente (ya tiene conversación de WhatsApp con el paciente)
2. Presiona **"🔄 Reprogramar cita → dar slot"** en la bandeja de urgencias
3. Se abre una vista que muestra:
   - Las citas operativas del día (o semana) — solo las que tienen status `programada` o `confirmada`
   - El admin selecciona una cita que quiera mover
4. Se abre un date/time picker para elegir **nuevo horario** para la cita original
5. Al confirmar (operación atómica via batch):
   - La cita original cambia a `estado: reprogramada` y se mueve al nuevo horario
   - Se crea una nueva cita para el paciente de urgencia en el slot que se liberó (tipo: `urgencia`)
   - La urgencia cambia a `estado: atendida` con `appointmentId` (nueva cita urgencia) y `reprogramadaFromId` (cita original movida)
   - FCM a ambos pacientes:
     - Al paciente original: "Tu cita fue reprogramada para [nueva fecha/hora]"
     - Al paciente de urgencia: "Tu cita de urgencia fue confirmada para [fecha/hora]"

#### 6.2 Reglas de la reprogramación

- **Solo el admin** puede ejecutar esto — no hay vía desde el lado paciente
- La cita original **no se cancela**, se reprograma (status `reprogramada` con nueva fecha)
- El slot liberado se ocupa **inmediatamente** con la cita de urgencia
- Si no hay citas para reprogramar, el admin usa "✅ Crear cita" y busca un slot libre normal
- La operación es **atómica** (Firestore batch): o se hacen ambos cambios o ninguno

#### 6.3 UI del selector de cita a reprogramar

```
┌────────────────────────────────────────────────┐
│  🔄 Reprogramar cita para dar slot a urgencia │
│                                                │
│  Urgencia: María García                        │
│  "Dolor intenso en la mandíbula"               │
│                                                │
│  Selecciona una cita para reprogramar:         │
│  ───────────────────────────────────────────   │
│  ○  09:00 AM — Pedro Ruiz (Control)           │
│     [Ver detalles]                             │
│                                                │
│  ○  10:30 AM — Ana Torres (Valoración)        │
│     [Ver detalles]                             │
│                                                │
│  ○  02:00 PM — Luis Méndez (Instalación)      │
│     [Ver detalles]                             │
│  ───────────────────────────────────────────   │
│                                                │
│  Nuevo horario para la cita seleccionada:      │
│  📅 [DatePicker]  🕐 [TimePicker]             │
│                                                │
│  ┌──────────────┐  ┌──────────────────────┐   │
│  │   Cancelar   │  │  Confirmar cambio    │   │
│  └──────────────┘  └──────────────────────┘   │
└────────────────────────────────────────────────┘
```

---

### ⚫ BLOQUE 7 — Notificaciones FCM de alta prioridad

**Objetivo:** Cuando un paciente envía una solicitud de urgencia, el admin recibe una notificación push de alta prioridad.

#### 7.1 Modificación en `fcm_payload_router.dart`

Agregar routing para tipo `urgency_request`:

```dart
/// Payload para urgencia nueva → alta prioridad
Map<String, dynamic> buildUrgencyPayload({
  required String patientName,
  required String requestId,
  required String descripcion,
}) {
  return {
    'type': 'urgency_request',
    'title': '🚨 Nueva solicitud de urgencia',
    'body': '$patientName: ${_truncate(descripcion, 80)}',
    'requestId': requestId,
    'priority': 'high',
    // Android
    'channel_id': 'urgency_alerts',
    // iOS
    'apns_headers': {
      'apns-priority': '10',
      'apns-push-type': 'alert',
    },
  };
}

String _truncate(String text, int maxLen) {
  return text.length > maxLen ? '${text.substring(0, maxLen)}...' : text;
}
```

#### 7.2 Trigger: enviar FCM al crear urgencia

Opción A (recomendada): Cloud Function `onUrgencyCreate` que escucha `urgencyRequests` nuevos y envía FCM a todos los dispositivos admin registrados.

Opción B (más rápido, sin deploy de functions): Enviar desde el cliente paciente al crear la solicitud, usando un callable que solo envía a tokens admin.

#### 7.3 Canal de notificación Android

En `fcm_service.dart`, registrar canal `urgency_alerts` con:
- Importancia: `Importance.high`
- Sonido: personalizado o default
- Vibración: activa
- Badge: siempre visible

---

### ⚪ BLOQUE 8 — Limpieza y mantenimiento

**Objetivo:** Las urgencias viejas no se acumulan indefinidamente.

#### 8.1 Reglas de visualización

- Urgencias **pendientes** y **en proceso**: siempre visibles
- Urgencias **atendidas**, **reprogramadas**, **rechazadas**: se muestran en sección "Historial" colapsable
- Después de 30 días: se archivan automáticamente (Cloud Function o proceso manual)

#### 8.2 Cloud Function de limpieza (opcional, v2)

```typescript
// functions/src/urgencyCleanup.ts
// Ejecutar cada 24h: mover urgencias resueltas > 30 días a subcolección archive
```

---

## 📊 Resumen de archivos a crear/modificar

### Nuevos archivos
| Archivo | Bloque | Descripción |
|---|---|---|
| `lib/features/appointments/data/models/urgency_model.dart` | 1 | Modelo + enum de urgencia |
| `lib/features/appointments/data/repositories/urgency_repository.dart` | 3 | CRUD Firestore + `rescheduleAppointmentForUrgency` |
| `lib/features/appointments/presentation/admin_urgency_screen.dart` | 4 | Pantalla bandeja admin |
| `lib/core/constants/clinic_contact.dart` | 2 | Config WhatsApp del admin |

### Archivos a modificar
| Archivo | Bloque | Cambio |
|---|---|---|
| `lib/features/dashboard/presentation/patient_appointments_screen.dart` | 2 | Bloque de urgencia con formulario de notas + auto-redirección a WhatsApp + botón directo |
| `lib/features/appointments/presentation/admin_appointment_form.dart` | 5 | Bypass de validaciones para urgencias |
| `lib/services/notifications/fcm_payload_router.dart` | 7 | Payload de urgencia alta prioridad |
| `lib/services/notifications/fcm_service.dart` | 7 | Canal de notificación urgencia |
| `firestore.rules` | 1 | Reglas para `urgencyRequests` |

---

## 🔄 Flujos completos

### Flujo 1: Paciente solicita urgencia → Admin atiende (conversación por WhatsApp)

```
1. Paciente abre "Mis citas" → ve bloque "¿Necesitas atención urgente?"
2. Presiona "📝 Solicitar atención prioritaria"
3. Escribe lo que le pasa en el campo de notas → Presiona "Enviar solicitud"
4. Firestore crea documento en urgencyRequests (estado: pendiente)
5. FCM push → Admin recibe notificación de alta prioridad
6. AUTO-REDIRECCIÓN: el paciente es enviado al WhatsApp del admin con mensaje prellenado
7. Paciente y admin conversan por WhatsApp directamente
8. Admin abre bandeja de urgencias → ve la solicitud + indicador "ya en WhatsApp"
9. Admin decide:
   a) "✅ Crear cita" → crea cita de urgencia en un slot libre (bypass validaciones)
   b) "🔄 Reprogramar cita → dar slot" → mueve una cita existente, le da ese slot a la urgencia
10. Si crea cita: urgencia → estado=atendida, appointmentId=<id>
11. Paciente ve la cita nueva en su lista + notificación FCM
```

### Flujo 2: Admin reprograma cita de otro paciente para dar slot a urgencia

```
1. Pasos 1-7 iguales al Flujo 1
2. Admin presiona "🔄 Reprogramar cita → dar slot"
3. Se abre vista con citas del día — admin selecciona una cita para mover
4. Elige nuevo horario para esa cita original
5. Al confirmar (batch atómico):
   a. Cita original → estado: reprogramada, nuevo horario
   b. Nueva cita de urgencia creada en el slot que se liberó
   c. Urgencia → estado: atendida, appointmentId: nueva cita, reprogramadaFromId: cita original
6. FCM al paciente original: "Tu cita fue reprogramada para [nueva fecha]"
7. FCM al paciente de urgencia: "Tu cita de urgencia fue confirmada para [fecha]"
```

### Flujo 3: Paciente va directo a WhatsApp (sin solicitud in-app)

```
1. Paciente abre "Mis citas" → ve bloque de urgencia
2. Presiona "💬 Ir directo a WhatsApp"
3. Se abre WhatsApp con mensaje prellenado al admin
4. NO se crea documento en urgencyRequests (canal externo directo)
5. El admin puede crear una urgencia manualmente desde su dashboard si lo desea
```

### Flujo 4: Admin crea urgencia manualmente

```
1. Admin recibe llamada telefónica directa del paciente
2. Admin va a bandeja de urgencias → botón "+ Nueva urgencia"
3. Busca paciente → escribe descripción → crea solicitud
4. Desde ahí sigue el Flujo 1 o 2
```

---

## 🎨 Guía visual rápida

### Colores semánticos

| Estado | Color | Hex |
|---|---|---|
| Pendiente | Rojo | `#EF4444` |
| En proceso | Ámbar | `#F59E0B` |
| Atendida | Verde | `#10B981` |
| Reprogramada | Índigo | `#6366F1` |
| Rechazada | Gris | `#6B7280` |

### Iconografía

- 🚨 Urgencia / alerta
- 📝 Solicitar
- 💬 WhatsApp / conversación directa
- ✅ Confirmar / Atender
- 🔄 Reprogramar → dar slot
- ⏳ Pendiente

---

## ✅ Checklist de validación pre-merge

- [ ] `flutter analyze` sin errores ni warnings
- [ ] Tests de urgency_repository (unit)
- [ ] Reglas Firestore validadas con `firebase emulators:start`
- [ ] FCM push probado con dispositivo real (no solo emulator)
- [ ] url_launcher probado en Android e iOS
- [ ] Badge de urgencias se actualiza en tiempo real
- [ ] Crear cita de urgencia bypassa validaciones correctamente
- [ ] Reprogramar cita → crear urgencia funciona como batch atómico
- [ ] Auto-redirección a WhatsApp funciona tras enviar solicitud
- [ ] Canales de notificación Android configurados
- [ ] Commits como UNIVERSIDAD21, mensajes en español

---

> **Nota para implementación:** Este documento está diseñado para ejecución bloque por bloque. Cada bloque es independiente y se puede validar con Jefe antes de pasar al siguiente. El orden recomendado es: **1 → 3 → 2 → 4 → 5 → 6 → 7 → 8**.
