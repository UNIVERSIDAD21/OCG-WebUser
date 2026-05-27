import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../appointments/data/models/urgency_model.dart';
import '../../appointments/providers/urgency_provider.dart';
import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/widgets/ocg_empty_state.dart';
import '../../../../shared/widgets/ocg_loading_state.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

Color _statusColor(UrgencyStatus status) => switch (status) {
      UrgencyStatus.pendiente => const Color(0xFFEF4444),
      UrgencyStatus.enProceso => const Color(0xFFF59E0B),
      UrgencyStatus.atendida => const Color(0xFF10B981),
      UrgencyStatus.reprogramada => const Color(0xFF6366F1),
      UrgencyStatus.rechazada => const Color(0xFF6B7280),
    };

// ─── AdminUrgencyScreen ───────────────────────────────────────────────────────

class AdminUrgencyScreen extends ConsumerStatefulWidget {
  const AdminUrgencyScreen({super.key});

  @override
  ConsumerState<AdminUrgencyScreen> createState() =>
      _AdminUrgencyScreenState();
}

class _AdminUrgencyScreenState extends ConsumerState<AdminUrgencyScreen> {
  @override
  Widget build(BuildContext context) {
    final urgenciesAsync = ref.watch(allUrgenciesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEDE8DC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 20,
                20,
                20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2C2016), Color(0xFF4A3628), Color(0xFF2C2016)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bandeja de Urgencias',
                              style: TextStyle(
                                color: OcgColors.ivory,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Gestiona solicitudes prioritarias de pacientes',
                              style: TextStyle(
                                color: OcgColors.ivory,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: urgenciesAsync.when(
                loading: () => const Center(child: OcgLoadingState()),
                error: (e, _) => Center(
                  child: OcgEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'No se pudieron cargar las urgencias',
                    subtitle: '$e',
                  ),
                ),
                data: (urgencies) {
                  if (urgencies.isEmpty) {
                    return Center(
                      child: OcgEmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'Sin solicitudes de urgencia',
                        subtitle: 'No hay urgencias registradas',
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: urgencies.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final urgency = urgencies[i];
                      return _UrgencyCard(
                        urgency: urgency,
                        onGestionar: () => _showGestionarDialog(context, ref, urgency),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGestionarDialog(
    BuildContext context,
    WidgetRef ref,
    UrgencyRequestModel urgency,
  ) {
    final notesController = TextEditingController(text: urgency.adminNotes ?? '');
    String selectedStatus = urgency.estado.name;
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Gestionar urgencia'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info del paciente
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paciente: ${urgency.patientName}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Teléfono: ${urgency.patientPhone}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Creado: ${_fmtDate(urgency.createdAt)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          urgency.descripcion,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Estado
                  const Text('Estado:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UrgencyStatus.values.map((status) {
                      final isSelected = status.name == selectedStatus;
                      return ChoiceChip(
                        label: Text(status.name.replaceAll('enProceso', 'En proceso')),
                        selected: isSelected,
                        onSelected: (v) {
                          setDialogState(() {
                            selectedStatus = status.name;
                          });
                        },
                        selectedColor: _statusColor(status).withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Notas
                  const Text('Notas del admin:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Agregar notas...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        final repo = ref.read(urgencyRepositoryProvider);
                        await repo.updateStatus(
                          requestId: urgency.id,
                          newStatus: UrgencyStatus.values.firstWhere(
                            (e) => e.name == selectedStatus,
                            orElse: () => UrgencyStatus.pendiente,
                          ),
                          adminNotes: notesController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Urgencia actualizada'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Urgency Card ─────────────────────────────────────────────────────────────

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard({required this.urgency, required this.onGestionar});

  final UrgencyRequestModel urgency;
  final VoidCallback onGestionar;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(urgency.estado);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgency.isActive ? statusColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C2016).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: estado + fecha
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      urgency.estadoLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _fmtDate(urgency.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Paciente
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18, color: OcgColors.espresso),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  urgency.patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Teléfono
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('tel:${urgency.patientPhone}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Text(
                  urgency.patientPhone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF25D366),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Descripción
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              urgency.descripcion,
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ),

          // Admin notes (si existen)
          if (urgency.adminNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.note_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    urgency.adminNotes!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final phone = urgency.patientPhone.replaceAll(RegExp(r'[^0-9+]'), '');
                    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent('Hola ${urgency.patientName}, te contactamos desde OCG Clínica sobre tu solicitud de urgencia.')}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onGestionar,
                  style: FilledButton.styleFrom(
                    backgroundColor: OcgColors.espresso,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Gestionar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
