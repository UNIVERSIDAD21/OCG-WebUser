import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_adaptive_scaffold.dart';
import '../../admin/presentation/web/shell/admin_web_shell.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/data/models/app_notification_model.dart';
import '../../notifications/providers/notifications_provider.dart';

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = WebLayoutContext.useDesktopShell(context);
    final user = ref.watch(authStateProvider).asData?.value;

    final body = _AdminNotificationsBody(user: user);

    if (isDesktop) {
      return AdminWebShell(title: 'Notificaciones', child: body);
    }

    return OcgAdaptiveScaffold(
      selectedIndex: 6,
      title: 'Notificaciones',
      appBarActions: const [],
      body: body,
    );
  }
}

class _AdminNotificationsBody extends ConsumerWidget {
  const _AdminNotificationsBody({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipientId = user?.uid;
    if (recipientId == null || recipientId.isEmpty) {
      return const Center(
        child: Text('No se pudo identificar al administrador actual.'),
      );
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(recipientId));
    final actionsState = ref.watch(notificationsActionsProvider);

    return notificationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudieron cargar notificaciones: $error'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 52,
                    color: OcgColors.bronze,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No hay notificaciones para el administrador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: OcgColors.ink),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: actionsState.isLoading
                    ? null
                    : () => ref
                        .read(notificationsActionsProvider.notifier)
                        .markAllAsRead(recipientId),
                icon: const Icon(Icons.done_all_outlined),
                label: const Text('Marcar todas como leídas'),
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items) ...[
              _NotificationCard(item: item),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});

  final AppNotificationModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => ref
          .read(notificationsActionsProvider.notifier)
          .openNotification(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.read ? Colors.white : const Color(0xFFF8F3ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.read ? const Color(0xFFE7D6C6) : OcgColors.bronze,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.read
                      ? Icons.notifications_none_outlined
                      : Icons.notifications_active_outlined,
                  color: item.read ? OcgColors.bronze : OcgColors.espresso,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title.isEmpty ? 'Notificación' : item.title,
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w700,
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
            const SizedBox(height: 8),
            Text(
              item.body,
              style: const TextStyle(color: OcgColors.ink),
            ),
            if (item.createdAt != null) ...[
              const SizedBox(height: 10),
              Text(
                _formatDate(item.createdAt!),
                style: const TextStyle(
                  color: OcgColors.bronze,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} · $hour:$minute';
  }
}
