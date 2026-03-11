import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/data/models/appointment_model.dart';
import '../../appointments/domain/appointments_business_rules.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../patients/providers/patients_provider.dart';
import '../../../shared/theme/ocg_colors.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtDateTime(DateTime d) =>
    '${_fmtDate(d)} a las '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

String _tipoLabel(AppointmentType t) => switch (t) {
  AppointmentType.valoracion => 'Valoración',
  AppointmentType.control => 'Control',
  AppointmentType.instalacion => 'Instalación',
  AppointmentType.urgencia => 'Urgencia',
  AppointmentType.alta => 'Alta',
};

// ─── Filtro ───────────────────────────────────────────────────────────────────

enum _PatientFilter { proximas, historial }

// ─── PatientAppointmentsScreen ────────────────────────────────────────────────

class PatientAppointmentsScreen extends ConsumerStatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  ConsumerState<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState
    extends ConsumerState<PatientAppointmentsScreen> {
  _PatientFilter _filter = _PatientFilter.proximas;

  // ─── Diálogo nueva cita ──────────────────────────────────────────────────

  void _showNewAppointmentDialog(
    BuildContext context,
    WidgetRef ref,
    String patientId,
    List<AppointmentModel> existingAppointments,
  ) {
    final cachedPatient = ref
        .read(patientByIdProvider(patientId))
        .asData
        ?.value;

    final nameFromAppts = existingAppointments
        .where((a) => a.patientName.isNotEmpty)
        .map((a) => a.patientName)
        .firstOrNull;

    // ✅ FIX: Usar displayName de FirebaseAuth como fallback en lugar del UID.
    // Prioridad: Firestore nombre > citas existentes > displayName de Auth > ''
    final authDisplayName =
        FirebaseAuth.instance.currentUser?.displayName ?? '';

    final patientNombre =
        (cachedPatient?.nombre?.isNotEmpty == true
                ? cachedPatient!.nombre
                : nameFromAppts?.isNotEmpty == true
                ? nameFromAppts!
                : authDisplayName)
            .trim();

    final patientPhone = cachedPatient?.telefono ?? '';

    AppointmentType selectedType = AppointmentType.valoracion;
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));
    selectedDateTime = DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      10,
      0,
    );
    final notesCtrl = TextEditingController();
    String? errorMsg;
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDs) => AlertDialog(
          title: const Text('Agendar nueva cita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AppointmentType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cita',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  items: [AppointmentType.valoracion, AppointmentType.control]
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(_tipoLabel(t)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDs(() {
                    selectedType = v ?? AppointmentType.valoracion;
                  }),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.schedule,
                    color: OcgColors.espresso,
                  ),
                  title: const Text('Fecha y hora'),
                  subtitle: Text(
                    _fmtDateTime(selectedDateTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: OcgColors.espresso,
                    ),
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDateTime,
                      firstDate: DateTime.now().add(const Duration(hours: 2)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (pickedDate == null) return;
                    if (!dialogContext.mounted) return;
                    final pickedTime = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                    );
                    if (pickedTime == null) return;
                    setDs(() {
                      selectedDateTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                      errorMsg = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: const TextStyle(
                      color: OcgColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () {
                      // ✅ FIX WEB: diferir pop al siguiente frame
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      });
                    },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OcgColors.espresso,
                foregroundColor: OcgColors.ivory,
                minimumSize: const Size(100, 40),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final sameDayError =
                          AppointmentsBusinessRules.validateNoSameDayAppointment(
                            existingAppointments: existingAppointments,
                            newAppointmentDateTime: selectedDateTime,
                          );
                      if (sameDayError != null) {
                        setDs(() => errorMsg = sameDayError);
                        return;
                      }

                      setDs(() => saving = true);

                      // ✅ FIX: Resolución robusta del nombre del paciente.
                      // Intentar desde Firestore primero, luego Auth displayName.
                      // NUNCA usar patientId como nombre.
                      final resolvedFromProvider = ref
                          .read(patientByIdProvider(patientId))
                          .asData
                          ?.value
                          ?.nombre;

                      final finalNombre = patientNombre.isNotEmpty
                          ? patientNombre
                          : resolvedFromProvider?.isNotEmpty == true
                          ? resolvedFromProvider!
                          : authDisplayName;

                      try {
                        await ref
                            .read(appointmentsRepositoryProvider)
                            .createAppointmentAsPatient(
                              AppointmentModel(
                                id: '',
                                patientId: patientId,
                                patientName: finalNombre,
                                patientPhone: patientPhone,
                                creadoPor: patientId,
                                tipo: selectedType,
                                estado: AppointmentStatus.programada,
                                fechaHora: selectedDateTime,
                                duracionMinutos: 30,
                                notas: notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                              ),
                            );

                        notesCtrl.dispose();
                        if (!dialogContext.mounted) return;
                        // ✅ FIX WEB: diferir pop al siguiente frame
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        });

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Cita agendada exitosamente!'),
                            backgroundColor: Color(0xFF2E7D32),
                          ),
                        );
                      } catch (e) {
                        setDs(() {
                          saving = false;
                          errorMsg = e.toString().contains('SLOT_TAKEN')
                              ? 'Ese horario ya está ocupado. Elige otro.'
                              : 'No se pudo agendar la cita. Intenta de nuevo.';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OcgColors.ivory,
                      ),
                    )
                  : const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Debes iniciar sesión.')));
    }

    final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        icon: const Icon(Icons.add),
        label: const Text('Agendar cita'),
        onPressed: () => _showNewAppointmentDialog(
          context,
          ref,
          user.uid,
          appointmentsAsync.asData?.value ?? const [],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [OcgColors.espresso, OcgColors.bronze],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis citas',
                  style: TextStyle(
                    color: OcgColors.ivory,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Próximas citas e historial',
                  style: TextStyle(
                    color: OcgColors.ivory.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SegmentedButton<_PatientFilter>(
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? OcgColors.espresso
                      : OcgColors.ivory,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? OcgColors.ivory
                      : OcgColors.espresso,
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _PatientFilter.proximas,
                  label: Text('Próximas'),
                  icon: Icon(Icons.upcoming_outlined, size: 16),
                ),
                ButtonSegment(
                  value: _PatientFilter.historial,
                  label: Text('Historial'),
                  icon: Icon(Icons.history, size: 16),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error al cargar citas: $e',
                  textAlign: TextAlign.center,
                ),
              ),
              data: (all) {
                final now = DateTime.now();
                final filtered = _filter == _PatientFilter.proximas
                    ? all
                          .where(
                            (a) =>
                                a.fechaHora.isAfter(now) &&
                                a.estado != AppointmentStatus.cancelada &&
                                a.estado != AppointmentStatus.noAsistio,
                          )
                          .toList()
                    : all
                          .where(
                            (a) =>
                                a.fechaHora.isBefore(now) ||
                                a.estado == AppointmentStatus.cancelada ||
                                a.estado == AppointmentStatus.completada,
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _filter == _PatientFilter.proximas
                          ? 'No tienes citas próximas.\nToca + para agendar.'
                          : 'Sin historial de citas aún.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final appt = filtered[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.event,
                          color: OcgColors.bronze,
                        ),
                        title: Text(_tipoLabel(appt.tipo)),
                        subtitle: Text(_fmtDateTime(appt.fechaHora)),
                        trailing: Chip(
                          label: Text(
                            appt.estado.name,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
