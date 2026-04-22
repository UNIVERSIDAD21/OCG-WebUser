import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/models/app_notification_model.dart';
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
    final unreadCount = ref.watch(unreadNotificationsCountProvider(patientId));
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: embedded ? Colors.transparent : const Color(0xFFF8F5F0),
      appBar: embedded
          ? null
          : AppBar(
              title: Text(unreadCount > 0 ? 'Notificaciones ($unreadCount)' : 'Notificaciones'),
              actions: [
                TextButton(
                  onPressed: actionsState.isLoading || unreadCount == 0
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
                borderRadius: BorderRadius.circular(18),
                onTap: actionsState.isLoading
                    ? null
                    : () => ref.read(notificationsActionsProvider.notifier).openNotification(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: item.read ? Colors.white : const Color(0xFFFFFBF4),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: item.read
                          ? OcgColors.espresso.withValues(alpha: 0.10)
                          : OcgColors.bronze.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: OcgColors.espresso.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NotificationLeadingIcon(item: item),
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
                                    style: TextStyle(
                                      color: OcgColors.espresso,
                                      fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (!item.read)
                                  Container(
                                    width: 10,
                                    height: 10,
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
                              style: TextStyle(
                                color: OcgColors.ink.withValues(alpha: item.read ? 0.82 : 1),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaChip(
                                  icon: Icons.schedule_outlined,
                                  label: item.createdAt != null ? dateFmt.format(item.createdAt!) : 'Ahora',
                                ),
                                if (_routeLabel(item) case final routeLabel?)
                                  _MetaChip(
                                    icon: Icons.navigation_outlined,
                                    label: routeLabel,
                                  ),
                                if (!item.read)
                                  const _MetaChip(
                                    icon: Icons.markunread_outlined,
                                    label: 'No leída',
                                    highlighted: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: OcgColors.ink.withValues(alpha: 0.35),
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

  String? _routeLabel(AppNotificationModel item) {
    final route = item.targetRoute ?? item.toRoutingPayload()['route']?.toString() ?? '';
    if (route.contains('/appointments')) return 'Ir a citas';
    if (route.contains('/payments')) return 'Ir a pagos';
    if (route.contains('/notifications')) return 'Ir a historial';
    if (item.type.contains('treatment')) return 'Ir a tratamiento';
    return null;
  }
}

class _NotificationLeadingIcon extends StatelessWidget {
  const _NotificationLeadingIcon({required this.item});

  final AppNotificationModel item;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (item.type) {
      'appointment_created' => Icons.event_available_outlined,
      'appointment_cancelled' => Icons.event_busy_outlined,
      'appointment_rescheduled' => Icons.update_outlined,
      'appointment_reminder' => Icons.alarm_outlined,
      'payment_received' => Icons.check_circle_outline,
      'payment_due' => Icons.payments_outlined,
      'treatment_stage_updated' => Icons.timeline_outlined,
      _ => Icons.notifications_outlined,
    };

    final accent = item.read ? OcgColors.ink : OcgColors.bronze;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(iconData, color: accent),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? OcgColors.bronze : OcgColors.ink;
    final background = highlighted
        ? OcgColors.bronze.withValues(alpha: 0.12)
        : OcgColors.ink.withValues(alpha: 0.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
