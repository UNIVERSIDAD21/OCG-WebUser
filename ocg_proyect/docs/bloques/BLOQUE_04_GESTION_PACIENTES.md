# BLOQUE_04 — Gestión de Pacientes (REABIERTO — Correcciones reales)

> **Estado:** ⚠️ REABIERTO
> **Motivo:** 5 problemas reales encontrados al revisar el código fuente contra el spec
> **Prioridad:** MUY ALTA — Estos problemas bloquean el uso real del sistema

---

## Diagnóstico honesto — problema por problema

### Problema 1 — CRÍTICO: `PatientFormScreen` tiene un error arquitectónico

El formulario de "Nuevo paciente" tiene un campo `UID paciente (UID de Firebase Auth)` de texto libre.

**¿Por qué esto es un error?**

El propio `docs/specs/03_AUTENTICACION_Y_ROLES.md` dice:
> "El admin NO crea las cuentas de los pacientes manualmente. El paciente se registra solo. Lo que SÍ hace el admin es completar los datos clínicos después de la primera cita presencial."

Y la Cloud Function `onAuthUserCreate` ya crea automáticamente `patients/{uid}` con campos mínimos cada vez que un paciente se registra.

**El flujo real correcto es:**
```
1. Paciente se registra desde login (dialog "Crear cuenta de paciente")
2. Cloud Function crea patients/{uid} con campos mínimos
3. Paciente aparece en la lista de admin automáticamente
4. Admin abre el perfil del paciente → completa los datos clínicos (edición)
```

**No existe un caso de uso para "crear un paciente desde cero con UID manual".**

**Corrección:** Eliminar el campo UID del formulario. En modo creación, mostrar una pantalla de "pacientes pendientes de completar datos" — son los documentos en `patients/` que tienen `tipoTratamiento == null` o `totalTratamiento == 0`. El admin selecciona uno y lo completa.

---

### Problema 2 — PatientCard no muestra "próxima cita"

El spec dice cada `PatientCard` debe mostrar:
> "Próxima cita (fecha corta) o 'Sin cita programada'"

El código actual solo muestra nombre, email, tipo de tratamiento y etapa. La próxima cita **no existe en absoluto** en la tarjeta.

**Corrección:** Agregar un campo `proximaCita` denormalizado en el documento `patients/{id}` que se actualiza cada vez que se crea o cancela una cita. Mostrar ese campo en la tarjeta.

Alternativa si no hay denormalización: hacer un `StreamProvider.family` que consulte la próxima cita de cada paciente. Pero esto genera N queries para N pacientes — **no usar este enfoque**. Usar denormalización.

---

### Problema 3 — PatientCard no muestra foto de perfil

El spec dice:
> "Avatar (foto o iniciales con fondo bronze)"

El código solo muestra iniciales siempre. El campo `fotoUrl` del `PatientModel` existe pero **nunca se usa en la tarjeta**.

**Corrección:** En `_PatientCard`, usar `CircleAvatar` con `backgroundImage: NetworkImage(patient.fotoUrl)` cuando `fotoUrl != null`, y las iniciales como fallback.

```dart
CircleAvatar(
 radius: 24,
 backgroundColor: OcgColors.bronze.withOpacity(0.18),
 backgroundImage: patient.fotoUrl != null
 ? NetworkImage(patient.fotoUrl!)
 : null,
 child: patient.fotoUrl == null
 ? Text(initial, style: ...)
 : null,
),
```

---

### Problema 4 — PatientProfileScreen: el paciente no puede editar nada

El spec dice el paciente puede editar:
- Su **foto de perfil**
- Su **número de teléfono**
- Su **contraseña** (via ForgotPassword)

El `PatientProfileScreen` actual es 100% solo lectura. No hay ningún campo editable, ningún botón de editar, ningún subir foto.

**Corrección:** Agregar en `PatientProfileScreen`:
- Botón de editar teléfono (inline o dialog)
- Avatar con botón de cámara/galería para subir foto de perfil
- Enlace "Cambiar contraseña" que llama a `resetPassword(email)`
- Los campos clínicos siguen siendo solo lectura con ícono de candado

---

### Problema 5 — 3 tabs en PatientDetailScreen tienen texto de placeholder visible al usuario

Los tabs `patient_payments_tab.dart` y `patient_simulator_tab.dart` tienen texto literal:
```
"Detalle de transacciones: siguiente iteración del bloque activo."
"Acceso e historial de simulaciones: siguiente iteración del bloque activo."
```

Este texto es un artefacto de desarrollo que **no debe ver el usuario final**. Aunque estos tabs se completan en Bloques 07 y 08, deben mostrar un `OcgEmptyState` profesional mientras tanto, no texto de debug.

**Corrección:** Reemplazar el texto de placeholder por `OcgEmptyState` en cada tab pendiente.

---

## Correcciones a implementar

### Corrección 1 — Rediseñar el flujo de alta de paciente

**Eliminar** el campo `UID paciente` del formulario en modo creación.

**Nuevo flujo para el admin:**

El FAB en `AdminPatientsScreen` ahora abre un diálogo con dos opciones:

```dart
showDialog(
 builder: (_) => AlertDialog(
 title: const Text('Agregar paciente'),
 content: const Text(
 'Para agregar un paciente, primero debe crear su cuenta desde '
 'la pantalla de login. Una vez registrado, aparecerá aquí '
 'para completar sus datos clínicos.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Entendido'),
 ),
 // Opcional: botón para ir a pacientes sin completar
 FilledButton(
 onPressed: () {
 Navigator.pop(context);
 // Filtrar pacientes sin datos clínicos completos
 ref.read(patientsFilterProvider.notifier).setFilter('Pendientes');
 },
 child: const Text('Ver pendientes de completar'),
 ),
 ],
 ),
);
```

**En el formulario de edición**, mantener todos los campos clínicos pero eliminar el campo UID (el paciente ya existe, el ID viene del `patientId` de la ruta).

**Agregar filtro "Pendientes"** en `AdminPatientsScreen`:

```dart
// En _filters, agregar:
static const _filters = <String>[
 'Todos',
 'Pendientes', // ← NUEVO: patients con totalTratamiento == 0
 'Activos',
 'Alta',
 ...
];

// En filteredPatientsProvider:
if (filter == 'Pendientes') {
 return p.totalTratamiento == 0 || p.tipoTratamiento == null;
}
```

---

### Corrección 2 — Denormalizar `proximaCita` en patients

**En `AppointmentsRepository.createAppointment`**, después de crear la cita exitosamente, actualizar el campo `proximaCita` en `patients/{patientId}`:

```dart
// Al final de createAppointment, fuera de la transaction:
await _db.collection(FirestorePaths.patients).doc(appointment.patientId).update({
 'proximaCita': appointment.fechaHora,
 'updatedAt': FieldValue.serverTimestamp(),
});
```

**En `AppointmentsRepository.updateAppointmentStatus`**, si el estado es `cancelada` o `completada`, limpiar el campo:

```dart
if (newStatus == AppointmentStatus.cancelada || 
 newStatus == AppointmentStatus.completada) {
 // Buscar la próxima cita activa más cercana y actualizar
 // (o poner null si no hay más citas activas)
 await _clearOrUpdateNextAppointment(appointment.patientId);
}
```

**Agregar campo a PatientModel:**
```dart
final DateTime? proximaCita; // Denormalizado — puede ser null
```

**En `_PatientCard`**, mostrar la próxima cita:
```dart
// Después de los OcgChip:
if (patient.proximaCita != null) ...[
 const SizedBox(height: 6),
 Row(
 children: [
 const Icon(Icons.event, size: 13, color: OcgColors.bronze),
 const SizedBox(width: 4),
 Text(
 _fmtDate(patient.proximaCita!),
 style: const TextStyle(fontSize: 12, color: OcgColors.bronze),
 ),
 ],
 ),
] else ...[
 const SizedBox(height: 4),
 const Text(
 'Sin cita programada',
 style: TextStyle(fontSize: 12, color: OcgColors.ink),
 ),
],
```

---

### Corrección 3 — PatientCard: usar foto de perfil

```dart
// En _PatientCard — reemplazar el CircleAvatar:
CircleAvatar(
 radius: 24,
 backgroundColor: OcgColors.bronze.withOpacity(0.18),
 backgroundImage: patient.fotoUrl != null && patient.fotoUrl!.isNotEmpty
 ? NetworkImage(patient.fotoUrl!)
 : null,
 onBackgroundImageError: patient.fotoUrl != null
 ? (_, __) {} // Fallback silencioso a iniciales
 : null,
 child: (patient.fotoUrl == null || patient.fotoUrl!.isEmpty)
 ? Text(
 initial,
 style: const TextStyle(
 fontFamily: 'Inter',
 fontWeight: FontWeight.w700,
 color: OcgColors.espresso,
 ),
 )
 : null,
),
```

---

### Corrección 4 — PatientProfileScreen: paciente puede editar teléfono y foto

**Agregar método al repositorio:**
```dart
// En PatientsRepository:
Future<void> updatePatientContactData(String patientId, {
 String? telefono,
 String? fotoUrl,
}) async {
 final data = <String, dynamic>{
 'updatedAt': FieldValue.serverTimestamp(),
 };
 if (telefono != null) data['telefono'] = telefono;
 if (fotoUrl != null) data['fotoUrl'] = fotoUrl;
 await _db.collection(FirestorePaths.patients).doc(patientId).update(data);
}
```

**En `PatientProfileScreen`**, reemplazar la sección de datos personales por:

```dart
// Avatar con botón de cámara
Stack(
 alignment: Alignment.bottomRight,
 children: [
 CircleAvatar(
 radius: 40,
 backgroundImage: patient.fotoUrl != null
 ? NetworkImage(patient.fotoUrl!)
 : null,
 child: patient.fotoUrl == null
 ? Text(patient.nombre[0], style: TextStyle(fontSize: 28))
 : null,
 ),
 CircleAvatar(
 radius: 14,
 backgroundColor: OcgColors.bronze,
 child: IconButton(
 icon: const Icon(Icons.camera_alt, size: 14, color: OcgColors.ivory),
 onPressed: () => _pickAndUploadPhoto(context, ref, patient.id),
 padding: EdgeInsets.zero,
 ),
 ),
 ],
),

// Campo teléfono editable:
ListTile(
 title: const Text('Teléfono'),
 subtitle: Text(patient.telefono),
 trailing: IconButton(
 icon: const Icon(Icons.edit, size: 18),
 onPressed: () => _editPhone(context, ref, patient),
 ),
),

// Cambiar contraseña:
ListTile(
 title: const Text('Contraseña'),
 subtitle: const Text('••••••••'),
 trailing: TextButton(
 onPressed: () => _sendPasswordReset(context, ref, patient.email),
 child: const Text('Cambiar'),
 ),
),
```

**Subida de foto** usa `image_picker` + `firebase_storage`:
```dart
Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref, String patientId) async {
 final picker = ImagePicker();
 final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
 if (file == null) return;
 
 final bytes = await file.readAsBytes();
 final storageRef = FirebaseStorage.instance
 .ref(StoragePaths.patientProfile(patientId));
 
 await storageRef.putData(bytes);
 final url = await storageRef.getDownloadURL();
 
 await ref.read(patientsRepositoryProvider)
 .updatePatientContactData(patientId, fotoUrl: url);
}
```

---

### Corrección 5 — Reemplazar textos de placeholder en tabs

**`patient_payments_tab.dart`** — reemplazar por:
```dart
@override
Widget build(BuildContext context) {
 return Center(
 child: OcgEmptyState(
 icon: Icons.payment_outlined,
 title: 'Pagos',
 subtitle: 'El historial de pagos estará disponible próximamente.',
 ),
 );
}
```

**`patient_simulator_tab.dart`** — reemplazar por:
```dart
@override
Widget build(BuildContext context) {
 return Center(
 child: OcgEmptyState(
 icon: Icons.auto_awesome_outlined,
 title: 'Simulador de sonrisa',
 subtitle: 'El simulador estará disponible próximamente.',
 ),
 );
}
```

**`patient_treatment_tab.dart`** — el timeline estático actual es aceptable como stub visual, pero agregar una nota interna: el historial real de `stageHistory` se conecta en Bloque 06.

---

## Criterios de cierre del bloque (reales)

- [ ] `PatientFormScreen` en modo creación no tiene campo UID — muestra instrucción de flujo correcto
- [ ] Filtro "Pendientes" visible en `AdminPatientsScreen` (pacientes sin datos clínicos)
- [ ] `PatientModel` tiene campo `proximaCita` y se denormaliza al crear/cancelar citas
- [ ] `PatientCard` muestra "próxima cita" o "Sin cita programada"
- [ ] `PatientCard` muestra foto de perfil si existe, iniciales como fallback
- [ ] Paciente puede editar su número de teléfono desde su perfil
- [ ] Paciente puede subir foto de perfil desde su pantalla
- [ ] Paciente puede iniciar cambio de contraseña (link a reset password)
- [ ] Tabs de Pagos y Simulador muestran `OcgEmptyState` en lugar de texto de debug
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅ — incluyendo serialización de `PatientModel` con `proximaCita`

---

## Orden recomendado de ejecución

1. Agregar `proximaCita` a `PatientModel` + serialización + test
2. Corregir `_PatientCard` (foto + próxima cita)
3. Actualizar `AppointmentsRepository` para denormalizar `proximaCita`
4. Rediseñar flujo del FAB en `AdminPatientsScreen` + filtro "Pendientes"
5. Eliminar campo UID del `PatientFormScreen` en modo creación
6. Agregar `updatePatientContactData` en `PatientsRepository`
7. Actualizar `PatientProfileScreen` con edición de teléfono + foto
8. Reemplazar placeholders en tabs de Pagos y Simulador con `OcgEmptyState`
9. `flutter analyze` + `flutter test`
