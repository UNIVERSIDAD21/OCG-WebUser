import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/notifications_provider.dart';

class PatientNotificationsScreen extends ConsumerWidget {
  const PatientNotificationsScreen({
    super.key,
    this.embedded = false,
    this.patientIdOverride,
  });

  final bool embedded;
  final String? patientIdOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;
    final patientId = (patientIdOverride?.isNotEmpty == true)
        ? patientIdOverride!
        : (user?.uid ?? '');

    if (patientId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(patientId));
    final actionsState = ref.watch(notificationsActionsProvider);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: embedded ? Colors.transparent : const Color(0xFFF8F5F0),
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Notificaciones'),
              actions: [
                TextButton(
                  onPressed: actionsState.isLoading
                      ? null
                      : () => ref.read(notificationsActionsProvider.notifier).markAllAsRead(patientId),
                  child: const Text('Marcar todas'),
                ),
              ],
            ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('No se pudieron cargar notificaciones: $error'),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const OcgEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No tienes notificaciones',
              subtitle: 'Aquí aparecerán tus recordatorios de citas y avisos importantes.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: item.read
                    ? null
                    : () => ref.read(notificationsActionsProvider.notifier).markAsRead(item.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.read
                          ? OcgColors.espresso.withValues(alpha: 0.10)
                          : OcgColors.bronze.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: (item.read ? OcgColors.ink : OcgColors.bronze).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.type == 'appointment_reminder'
                              ? Icons.event_available_outlined
                              : Icons.notifications_outlined,
                          color: item.read ? OcgColors.ink : OcgColors.bronze,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: OcgColors.espresso,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (!item.read)
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: OcgColors.bronze,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.body,
                              style: const TextStyle(color: OcgColors.ink),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.createdAt != null ? dateFmt.format(item.createdAt!) : 'Ahora',
                              style: TextStyle(
                                fontSize: 12,
                                color: OcgColors.ink.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
