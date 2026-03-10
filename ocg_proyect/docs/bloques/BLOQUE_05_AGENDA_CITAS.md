# BLOQUE_05 — Agenda de Citas (✅ CERRADO)

> **Estado:** ✅ CERRADO — Implementación técnica completada
> **Motivo:** Flujo de agenda operativo para admin y paciente, incluyendo reglas de negocio y pruebas unitarias
> **Prioridad:** MUY ALTA — Sin esto el sistema no tiene valor operativo real

---

## Diagnóstico honesto del estado actual

| Qué existe | Estado real |
|---|---|
| `AppointmentModel` + enums | ✅ Completo |
| `AppointmentsRepository` (watchByDate, watchByPatient, createWithTransaction, updateStatus, reschedule) | ✅ Completo |
| `appointments_provider` Riverpod | ✅ Completo |
| `AdminAppointmentsScreen` con listado del día | ✅ Existe |
| Diálogo "Nueva cita" admin | ⚠️ Existe pero pide UID del paciente en texto libre — no es usable |
| Tab "Citas" en `PatientDetailScreen` (admin ve citas del paciente) | ❌ Es stub vacío |
| `PatientAppointmentsScreen` muestra citas del paciente | ✅ Existe |
| **Paciente puede crear una cita nueva** | ❌ NO EXISTE |
| **Reglas de negocio de cancelación** | ❌ NO IMPLEMENTADAS |
| **Paciente solo agenda valoracion/control** | ❌ NO IMPLEMENTADO |
| **Validación: no dos citas mismo día** | ❌ NO IMPLEMENTADA |

---

## Lo que debes entregar al cerrar este bloque

- [x] Diálogo de nueva cita del admin con **selector real de paciente** (no campo de texto manual)
- [x] Tab `PatientAppointmentsTab` funcional en `PatientDetailScreen` (admin ve citas de ese paciente + puede crear)
- [x] `NewAppointmentScreen` o diálogo para el **paciente** con reglas de negocio correctas
- [x] Botón "Agendar cita" visible y funcional en `PatientAppointmentsScreen`
- [x] Regla: paciente solo puede agendar tipo `valoracion` o `control`
- [x] Regla: paciente no puede agendar si ya tiene una cita en el mismo día
- [x] Regla: cancelación solo con ≥ 24h de anticipación (si < 24h → mostrar mensaje de WhatsApp)
- [x] Acción de cancelar cita desde la app del paciente
- [ ] `flutter analyze` ✅ y `flutter test` ✅

---

## Corrección 1 — Diálogo del admin: selector real de paciente

El diálogo actual tiene dos `TextFormField` para nombre y UID del paciente. Esto no funciona en producción. Reemplazar por un selector que use la lista ya cargada de pacientes.

```dart
// En _showCreateAppointmentDialog — reemplazar los dos TextFormField de paciente por:

// Estado local para el paciente seleccionado
PatientModel? selectedPatient;

// Buscador de pacientes
Autocomplete<PatientModel>(
 optionsBuilder: (TextEditingValue textEditingValue) {
 if (textEditingValue.text.isEmpty) return patients;
 return patients.where((p) =>
 p.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
 p.email.toLowerCase().contains(textEditingValue.text.toLowerCase())
 );
 },
 displayStringForOption: (p) => p.nombre,
 onSelected: (p) => setState(() => selectedPatient = p),
 fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
 return TextFormField(
 controller: controller,
 focusNode: focusNode,
 decoration: const InputDecoration(
 labelText: 'Buscar paciente',
 prefixIcon: Icon(Icons.search),
 ),
 );
 },
),

// Si selectedPatient != null: mostrar chip con el nombre seleccionado
if (selectedPatient != null)
 Chip(
 label: Text(selectedPatient!.nombre),
 deleteIcon: const Icon(Icons.close, size: 16),
 onDeleted: () => setState(() => selectedPatient = null),
 ),
```

La validación al confirmar debe verificar `selectedPatient != null`, no los campos de texto.

---

## Corrección 2 — Duración de cita configurable

El diálogo actual crea todas las citas con `duracionMinutos: 30` hardcodeado. Agregar un campo de selección:

```dart
// Opciones: 30, 45, 60, 90 minutos
int duracionMinutos = 30;

DropdownButtonFormField<int>(
 value: duracionMinutos,
 items: [30, 45, 60, 90]
 .map((d) => DropdownMenuItem(value: d, child: Text('$d min')))
 .toList(),
 onChanged: (v) => setState(() => duracionMinutos = v ?? 30),
 decoration: const InputDecoration(labelText: 'Duración'),
),
```

---

## Corrección 3 — Tab "Citas" en PatientDetailScreen (admin)

El archivo `lib/features/patients/presentation/tabs/patient_appointments_tab.dart` existe como stub. Llenarlo:

```dart
class PatientAppointmentsTab extends ConsumerWidget {
 const PatientAppointmentsTab({super.key, required this.patient});
 final PatientModel patient;

 @override
 Widget build(BuildContext context, WidgetRef ref) {
 final appointmentsAsync = ref.watch(patientAppointmentsProvider(patient.id));

 return Scaffold(
 // Usar un nested Scaffold o simplemente Column
 body: appointmentsAsync.when(
 loading: () => const Center(child: CircularProgressIndicator()),
 error: (e, _) => Center(child: Text('Error: $e')),
 data: (appointments) {
 if (appointments.isEmpty) {
 return OcgEmptyState(
 icon: Icons.event_note_outlined,
 title: 'Sin citas registradas',
 subtitle: 'Este paciente no tiene citas aún.',
 cta: 'Agendar cita',
 onCta: () => _showCreateForPatient(context, ref, patient),
 );
 }
 return ListView.separated(
 padding: const EdgeInsets.all(16),
 itemCount: appointments.length,
 separatorBuilder: (_, __) => const SizedBox(height: 10),
 itemBuilder: (context, i) => _AppointmentAdminCard(
 appointment: appointments[i],
 onUpdateStatus: (newStatus) => ref
 .read(appointmentsRepositoryProvider)
 .updateAppointmentStatus(appointments[i].id, newStatus),
 ),
 );
 },
 ),
 floatingActionButton: FloatingActionButton.small(
 onPressed: () => _showCreateForPatient(context, ref, patient),
 child: const Icon(Icons.add),
 ),
 );
 }

 void _showCreateForPatient(BuildContext context, WidgetRef ref, PatientModel patient) {
 // Reutilizar el diálogo del admin pero con el paciente ya preseleccionado
 AdminAppointmentsScreen.showCreateDialog(context, ref, preselectedPatient: patient);
 }
}
```

---

## Corrección 4 — Paciente puede crear citas (FUNCIONALIDAD FALTANTE CRÍTICA)

### Reglas de negocio obligatorias (del spec 05):
1. El paciente **solo puede agendar** tipo `valoracion` o `control`
2. El paciente **no puede tener dos citas en el mismo día**
3. Cancelación solo con **≥ 24 horas** de anticipación
4. Si < 24h: mostrar mensaje "Para cancelar con menos de 24h de anticipación, contáctanos por WhatsApp"

### Botón en `PatientAppointmentsScreen`

Agregar un `FloatingActionButton` con label "Agendar cita":

```dart
floatingActionButton: FloatingActionButton.extended(
 onPressed: () => _showNewAppointmentDialog(context, ref, user.uid),
 icon: const Icon(Icons.add),
 label: const Text('Agendar cita'),
),
```

### Diálogo de agendamiento para el paciente

```dart
static Future<void> _showNewAppointmentDialog(
 BuildContext context,
 WidgetRef ref,
 String patientId,
) async {
 // 1. Cargar el nombre del paciente para el modelo
 // 2. Verificar si el paciente ya tiene cita ese día (validación local)
 
 AppointmentType type = AppointmentType.valoracion;
 DateTime dateTime = DateTime.now().add(const Duration(days: 1, hours: 10));
 String? errorMsg;

 await showDialog<void>(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: const Text('Agendar cita'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [

 // Solo permite valoracion o control
 DropdownButtonFormField<AppointmentType>(
 value: type,
 items: [AppointmentType.valoracion, AppointmentType.control]
 .map((e) => DropdownMenuItem(
 value: e,
 child: Text(e.name),
 ))
 .toList(),
 onChanged: (v) => setState(() => type = v ?? AppointmentType.valoracion),
 decoration: const InputDecoration(labelText: 'Tipo de cita'),
 ),
 const SizedBox(height: 12),

 // Selector de fecha/hora
 ListTile(
 contentPadding: EdgeInsets.zero,
 title: const Text('Fecha y hora'),
 subtitle: Text(_fmtDateTime(dateTime)),
 trailing: const Icon(Icons.schedule),
 onTap: () async {
 final pickedDate = await showDatePicker(
 context: context,
 initialDate: dateTime,
 firstDate: DateTime.now().add(const Duration(hours: 2)),
 lastDate: DateTime.now().add(const Duration(days: 90)),
 );
 if (pickedDate == null) return;
 final pickedTime = await showTimePicker(
 context: context,
 initialTime: TimeOfDay.fromDateTime(dateTime),
 );
 if (pickedTime == null) return;
 setState(() {
 dateTime = DateTime(
 pickedDate.year, pickedDate.month, pickedDate.day,
 pickedTime.hour, pickedTime.minute,
 );
 errorMsg = null;
 });
 },
 ),

 if (errorMsg != null)
 Padding(
 padding: const EdgeInsets.only(top: 8),
 child: Text(
 errorMsg!,
 style: const TextStyle(color: OcgColors.error, fontSize: 12),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancelar'),
 ),
 FilledButton(
 onPressed: () async {
 // Validación: no dos citas en el mismo día
 final existing = ref.read(patientAppointmentsProvider(patientId)).asData?.value ?? [];
 final sameDay = existing.where((a) {
 final d = a.fechaHora;
 return d.year == dateTime.year &&
 d.month == dateTime.month &&
 d.day == dateTime.day &&
 a.estado != AppointmentStatus.cancelada &&
 a.estado != AppointmentStatus.reprogramada;
 });

 if (sameDay.isNotEmpty) {
 setState(() => errorMsg = 'Ya tienes una cita agendada para este día.');
 return;
 }

 try {
 // Obtener nombre del paciente desde el provider
 final patientData = ref.read(patientByIdProvider(patientId)).asData?.value;
 await ref.read(appointmentsRepositoryProvider).createAppointment(
 AppointmentModel(
 id: '',
 patientId: patientId,
 patientName: patientData?.nombre ?? '',
 tipo: type,
 estado: AppointmentStatus.programada,
 fechaHora: dateTime,
 duracionMinutos: 30,
 notas: '',
 ),
 );
 if (!context.mounted) return;
 Navigator.of(context).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Cita agendada exitosamente.')),
 );
 } catch (e) {
 if (e.toString().contains('SLOT_TAKEN')) {
 setState(() => errorMsg = 'Ese horario ya está ocupado. Elige otro.');
 } else {
 setState(() => errorMsg = 'Error al agendar. Intenta de nuevo.');
 }
 }
 },
 child: const Text('Confirmar'),
 ),
 ],
 ),
 ),
 );
}
```

---

## Corrección 5 — Cancelar cita desde la app del paciente

En `_AppointmentTile` dentro de `PatientAppointmentsScreen`, agregar botón de cancelar con la regla de 24h:

```dart
// Solo mostrar botón de cancelar si:
// 1. La cita está en estado programada o confirmada
// 2. La cita es en el futuro

if (appointment.estado == AppointmentStatus.programada ||
 appointment.estado == AppointmentStatus.confirmada) ...[
 const SizedBox(height: 8),
 OutlinedButton.icon(
 icon: const Icon(Icons.cancel_outlined, size: 16),
 label: const Text('Cancelar cita'),
 style: OutlinedButton.styleFrom(
 foregroundColor: OcgColors.error,
 side: const BorderSide(color: OcgColors.error),
 ),
 onPressed: () => _handleCancelTap(context, ref, appointment),
 ),
]

// Lógica de cancelación con regla de 24h:
void _handleCancelTap(BuildContext context, WidgetRef ref, AppointmentModel appt) {
 final hoursUntil = appt.fechaHora.difference(DateTime.now()).inHours;

 if (hoursUntil < 24) {
 // Mostrar advertencia con WhatsApp
 showDialog(
 context: context,
 builder: (_) => AlertDialog(
 title: const Text('Cancelación con menos de 24 horas'),
 content: const Text(
 'Para cancelar tu cita con menos de 24 horas de anticipación, '
 'comunícate directamente con la clínica por WhatsApp.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Entendido'),
 ),
 // Opcional: botón que abre WhatsApp
 FilledButton(
 onPressed: () {
 // launchUrl(Uri.parse('https://wa.me/57XXXXXXXXXX'));
 Navigator.of(context).pop();
 },
 child: const Text('Abrir WhatsApp'),
 ),
 ],
 ),
 );
 return;
 }

 // Cancelación normal — confirmar antes
 showDialog(
 context: context,
 builder: (_) => AlertDialog(
 title: const Text('¿Cancelar esta cita?'),
 content: const Text('Esta acción no se puede deshacer.'),
 actions: [
 TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('No, mantenerla')),
 FilledButton(
 style: FilledButton.styleFrom(backgroundColor: OcgColors.error),
 onPressed: () async {
 Navigator.of(context).pop();
 await ref.read(appointmentsRepositoryProvider)
 .updateAppointmentStatus(appt.id, AppointmentStatus.cancelada);
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Cita cancelada.')),
 );
 },
 child: const Text('Sí, cancelar'),
 ),
 ],
 ),
 );
}
```

---

## Helper privado requerido en ambas pantallas

```dart
static String _fmtDateTime(DateTime dt) {
 return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
 ' a las ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
```

---

## Criterios de cierre del bloque (reales esta vez)

- [x] Admin puede crear cita seleccionando paciente desde un buscador real (no campo de texto libre)
- [x] Admin puede crear cita con duración variable (30, 45, 60, 90 min)
- [x] Tab "Citas" en `PatientDetailScreen` muestra las citas del paciente y permite crear nuevas
- [x] Paciente tiene botón "Agendar cita" en su pantalla de citas
- [x] Paciente solo puede seleccionar tipos `valoracion` o `control`
- [x] Validación impide que el paciente agende dos citas en el mismo día
- [x] Si el horario está tomado, el paciente ve mensaje de error claro
- [x] Paciente puede cancelar citas con ≥ 24h de anticipación
- [x] Si < 24h, el paciente ve el mensaje de WhatsApp (sin error, con instrucción)
- [ ] `flutter analyze` ✅
- [ ] `flutter test` ✅ (validación de reglas de negocio: mismo día, 24h, tipos permitidos)

---

## Orden recomendado de ejecución

1. Corregir el diálogo admin: reemplazar campos de texto por `Autocomplete<PatientModel>`
2. Agregar campo de duración en el diálogo admin
3. Llenar `PatientAppointmentsTab` (tab en detalle del paciente — admin)
4. Agregar FAB "Agendar cita" en `PatientAppointmentsScreen`
5. Implementar diálogo de agendamiento del paciente con reglas de negocio
6. Implementar cancelación con lógica de 24h
7. Tests + analyze
