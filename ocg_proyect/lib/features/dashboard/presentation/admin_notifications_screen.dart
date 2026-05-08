import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/web/common/web_layout_context.dart';
import '../../../shared/theme/ocg_colors.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(title: const Text('Notificaciones')),
      body: body,
    );
  }
}

class _AdminNotificationsBody extends ConsumerStatefulWidget {
  const _AdminNotificationsBody({required this.user});

  final User? user;

  @override
  ConsumerState<_AdminNotificationsBody> createState() =>
      _AdminNotificationsBodyState();
}

enum _NotificationInboxFilter {
  all,
  unread,
  appointments,
  payments,
  treatments,
  documents,
  simulations,
}

class _AdminNotificationsBodyState
    extends ConsumerState<_AdminNotificationsBody> {
  _NotificationInboxFilter _filter = _NotificationInboxFilter.all;

  @override
  Widget build(BuildContext context) {
    final recipientId = widget.user?.uid;
    if (recipientId == null || recipientId.isEmpty) {
      return const Center(
        child: Text('No se pudo identificar al administrador actual.'),
      );
    }

    final notificationsAsync = ref.watch(
      userNotificationsProvider(recipientId),
    );
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
        final filtered = _filteredItems(items);
        final unread = items.where((item) => !item.read).length;
        final today = _itemsToday(items);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            _NotificationsHero(
              total: items.length,
              unread: unread,
              today: today,
            ),
            const SizedBox(height: 12),
            _buildFilters(items),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} notificaciones',
                    style: const TextStyle(
                      color: OcgColors.espresso,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: actionsState.isLoading || unread == 0
                      ? null
                      : () => ref
                            .read(notificationsActionsProvider.notifier)
                            .markAllAsRead(recipientId),
                  icon: const Icon(Icons.done_all_outlined),
                  label: const Text('Marcar leídas'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              _NotificationsEmptyState(
                title: 'Sin notificaciones todavía',
                subtitle:
                    'Cuando lleguen avisos de citas, pagos, documentos o tratamientos aparecerán aquí.',
                icon: Icons.notifications_none_outlined,
              )
            else if (filtered.isEmpty)
              _NotificationsEmptyState(
                title: 'Sin resultados para este filtro',
                subtitle:
                    'Cambia el filtro para revisar otros tipos de notificaciones.',
                icon: Icons.filter_alt_off_outlined,
                onClear: () =>
                    setState(() => _filter = _NotificationInboxFilter.all),
              )
            else
              for (final item in filtered) ...[
                _NotificationCard(item: item),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  int _itemsToday(List<AppNotificationModel> items) {
    final now = DateTime.now();
    return items.where((item) {
      final created = item.createdAt;
      return created != null &&
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
    }).length;
  }

  List<AppNotificationModel> _filteredItems(List<AppNotificationModel> items) {
    final filtered = items.where((item) {
      return switch (_filter) {
        _NotificationInboxFilter.all => true,
        _NotificationInboxFilter.unread => !item.read,
        _NotificationInboxFilter.appointments =>
          _kind(item) == _NotificationKind.appointment,
        _NotificationInboxFilter.payments =>
          _kind(item) == _NotificationKind.payment,
        _NotificationInboxFilter.treatments =>
          _kind(item) == _NotificationKind.treatment,
        _NotificationInboxFilter.documents =>
          _kind(item) == _NotificationKind.document,
        _NotificationInboxFilter.simulations =>
          _kind(item) == _NotificationKind.simulation,
      };
    }).toList();
    filtered.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return filtered;
  }

  bool _matchesFilter(
    AppNotificationModel item,
    _NotificationInboxFilter filter,
  ) {
    return switch (filter) {
      _NotificationInboxFilter.all => true,
      _NotificationInboxFilter.unread => !item.read,
      _NotificationInboxFilter.appointments =>
        _kind(item) == _NotificationKind.appointment,
      _NotificationInboxFilter.payments =>
        _kind(item) == _NotificationKind.payment,
      _NotificationInboxFilter.treatments =>
        _kind(item) == _NotificationKind.treatment,
      _NotificationInboxFilter.documents =>
        _kind(item) == _NotificationKind.document,
      _NotificationInboxFilter.simulations =>
        _kind(item) == _NotificationKind.simulation,
    };
  }

  int _countForFilter(
    _NotificationInboxFilter filter,
    List<AppNotificationModel> items,
  ) => items.where((item) => _matchesFilter(item, filter)).length;

  Widget _buildFilters(List<AppNotificationModel> items) {
    final filters = _NotificationInboxFilter.values;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final active = filter == _filter;
          final count = _countForFilter(filter, items);
          return ChoiceChip(
            selected: active,
            avatar: Icon(
              _filterIcon(filter),
              size: 16,
              color: active ? OcgColors.ivory : OcgColors.espresso,
            ),
            label: Text('${_filterLabel(filter)} · $count'),
            selectedColor: OcgColors.espresso,
            backgroundColor: OcgColors.ivory,
            labelStyle: TextStyle(
              color: active ? OcgColors.ivory : OcgColors.espresso,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: active
                  ? OcgColors.espresso
                  : OcgColors.bronze.withOpacity(0.24),
            ),
            onSelected: (_) => setState(() => _filter = filter),
          );
        },
      ),
    );
  }

  String _filterLabel(_NotificationInboxFilter filter) {
    return switch (filter) {
      _NotificationInboxFilter.all => 'Todas',
      _NotificationInboxFilter.unread => 'No leídas',
      _NotificationInboxFilter.appointments => 'Citas',
      _NotificationInboxFilter.payments => 'Pagos',
      _NotificationInboxFilter.treatments => 'Tratamientos',
      _NotificationInboxFilter.documents => 'Docs',
      _NotificationInboxFilter.simulations => 'Simulador',
    };
  }

  IconData _filterIcon(_NotificationInboxFilter filter) {
    return switch (filter) {
      _NotificationInboxFilter.all => Icons.layers_outlined,
      _NotificationInboxFilter.unread => Icons.mark_email_unread_outlined,
      _NotificationInboxFilter.appointments => Icons.event_available_outlined,
      _NotificationInboxFilter.payments => Icons.payments_outlined,
      _NotificationInboxFilter.treatments => Icons.monitor_heart_outlined,
      _NotificationInboxFilter.documents => Icons.folder_shared_outlined,
      _NotificationInboxFilter.simulations => Icons.auto_awesome_outlined,
    };
  }
}

enum _NotificationKind {
  appointment,
  payment,
  treatment,
  document,
  simulation,
  generic,
}

_NotificationKind _kind(AppNotificationModel item) {
  final raw = '${item.type} ${item.entityType ?? ''} ${item.targetRoute ?? ''}'
      .toLowerCase();
  if (raw.contains('appointment') || raw.contains('cita')) {
    return _NotificationKind.appointment;
  }
  if (raw.contains('payment') || raw.contains('pago') || raw.contains('payu')) {
    return _NotificationKind.payment;
  }
  if (raw.contains('treatment') || raw.contains('tratamiento')) {
    return _NotificationKind.treatment;
  }
  if (raw.contains('document') ||
      raw.contains('clinical') ||
      raw.contains('archivo')) {
    return _NotificationKind.document;
  }
  if (raw.contains('simulation') || raw.contains('simulador')) {
    return _NotificationKind.simulation;
  }
  return _NotificationKind.generic;
}

IconData _kindIcon(_NotificationKind kind) {
  return switch (kind) {
    _NotificationKind.appointment => Icons.event_available_outlined,
    _NotificationKind.payment => Icons.payments_outlined,
    _NotificationKind.treatment => Icons.monitor_heart_outlined,
    _NotificationKind.document => Icons.folder_shared_outlined,
    _NotificationKind.simulation => Icons.auto_awesome_outlined,
    _NotificationKind.generic => Icons.notifications_outlined,
  };
}

Color _kindColor(_NotificationKind kind) {
  return switch (kind) {
    _NotificationKind.appointment => const Color(0xFF1565C0),
    _NotificationKind.payment => const Color(0xFF2E7D32),
    _NotificationKind.treatment => const Color(0xFF7A8A20),
    _NotificationKind.document => const Color(0xFF7E3AF2),
    _NotificationKind.simulation => const Color(0xFFC56B16),
    _NotificationKind.generic => OcgColors.bronze,
  };
}

String _kindLabel(_NotificationKind kind) {
  return switch (kind) {
    _NotificationKind.appointment => 'Cita',
    _NotificationKind.payment => 'Pago',
    _NotificationKind.treatment => 'Tratamiento',
    _NotificationKind.document => 'Documento',
    _NotificationKind.simulation => 'Simulador',
    _NotificationKind.generic => 'General',
  };
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({
    required this.total,
    required this.unread,
    required this.today,
  });

  final int total;
  final int unread;
  final int today;

  @override
  Widget build(BuildContext context) {
    Widget metric(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: OcgColors.ivory.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OcgColors.ivory.withOpacity(0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: OcgColors.ivory.withOpacity(0.78)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: OcgColors.ivory,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: OcgColors.ivory.withOpacity(0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3527), Color(0xFF9A7654)],
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OcgColors.ivory.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: OcgColors.ivory,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro de notificaciones',
                      style: TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Prioriza alertas clínicas, pagos y seguimiento operativo.',
                      style: TextStyle(color: Color(0xFFEADFD4), height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              metric('Total', '$total', Icons.inbox_outlined),
              const SizedBox(width: 8),
              metric('No leídas', '$unread', Icons.mark_email_unread_outlined),
              const SizedBox(width: 8),
              metric('Hoy', '$today', Icons.today_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onClear,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: OcgColors.bronze),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OcgColors.bronze, height: 1.3),
          ),
          if (onClear != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpiar filtro'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationPill extends StatelessWidget {
  const _NotificationPill({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});

  final AppNotificationModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = _kind(item);
    final color = _kindColor(kind);
    final routeLabel = _routeLabel(item);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => ref
          .read(notificationsActionsProvider.notifier)
          .openNotification(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.read ? Colors.white : const Color(0xFFF8F3ED),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: item.read
                ? const Color(0xFFE7D6C6)
                : color.withOpacity(0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: OcgColors.espresso.withOpacity(item.read ? 0.035 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_kindIcon(kind), color: color, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isEmpty ? 'Notificación' : item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OcgColors.espresso,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: OcgColors.ink.withOpacity(0.78),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _NotificationPill(
                      label: item.read ? 'Leída' : 'Nueva',
                      color: item.read ? OcgColors.bronze : color,
                      icon: item.read
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                    ),
                    const SizedBox(height: 6),
                    _NotificationPill(
                      label: _kindLabel(kind),
                      color: color,
                      icon: _kindIcon(kind),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.createdAt != null)
                  _NotificationPill(
                    label: _formatDate(item.createdAt!),
                    color: OcgColors.bronze,
                    icon: Icons.schedule_outlined,
                  ),
                if (routeLabel != null)
                  _NotificationPill(
                    label: routeLabel,
                    color: OcgColors.espresso,
                    icon: Icons.open_in_new_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ref
                    .read(notificationsActionsProvider.notifier)
                    .openNotification(item),
                icon: const Icon(Icons.arrow_forward_outlined, size: 16),
                label: Text(item.read ? 'Abrir destino' : 'Leer y abrir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _routeLabel(AppNotificationModel item) {
    final route = item.targetRoute ?? item.payload['route']?.toString();
    if (route == null || route.trim().isEmpty) return null;
    if (route.contains('appointments') || route.contains('citas')) {
      return 'Abrir agenda';
    }
    if (route.contains('payments') || route.contains('pagos')) {
      return 'Abrir pagos';
    }
    if (route.contains('treatment') || route.contains('tratamiento')) {
      return 'Abrir tratamiento';
    }
    if (route.contains('clinical') || route.contains('document')) {
      return 'Abrir documentos';
    }
    if (route.contains('simulation') || route.contains('simulador')) {
      return 'Abrir simulador';
    }
    return 'Abrir destino';
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} · $hour:$minute';
  }
}
