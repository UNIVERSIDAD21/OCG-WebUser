import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/models/app_notification_model.dart';
import '../providers/notifications_provider.dart';

class PatientNotificationsScreen extends ConsumerStatefulWidget {
  const PatientNotificationsScreen({
    super.key,
    this.embedded = false,
    this.patientIdOverride,
  });

  final bool embedded;
  final String? patientIdOverride;

  @override
  ConsumerState<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

enum _PatientNotificationFilter {
  all,
  unread,
  appointments,
  payments,
  treatments,
  documents,
  simulations,
}

class _PatientNotificationsScreenState
    extends ConsumerState<PatientNotificationsScreen> {
  _PatientNotificationFilter _filter = _PatientNotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    final patientId = (widget.patientIdOverride?.isNotEmpty == true)
        ? widget.patientIdOverride!
        : (user?.uid ?? '');

    if (patientId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(patientId));
    final actionsState = ref.watch(notificationsActionsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider(patientId));

    return Scaffold(
      backgroundColor: widget.embedded
          ? Colors.transparent
          : const Color(0xFFF8F5F0),
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                unreadCount > 0
                    ? 'Notificaciones ($unreadCount)'
                    : 'Notificaciones',
              ),
              actions: [
                TextButton(
                  onPressed: actionsState.isLoading || unreadCount == 0
                      ? null
                      : () => ref
                            .read(notificationsActionsProvider.notifier)
                            .markAllAsRead(patientId),
                  child: const Text('Marcar todas'),
                ),
              ],
            ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: OcgEmptyState(
              icon: Icons.wifi_off_outlined,
              title: 'No pudimos cargar tus notificaciones',
              subtitle:
                  'Revisa tu conexión e intenta de nuevo. Detalle técnico: $error',
            ),
          ),
        ),
        data: (items) {
          final filtered = _filteredItems(items);
          final unread = items.where((item) => !item.read).length;
          final today = _itemsToday(items);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _PatientNotificationsHero(
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
                      '${filtered.length} avisos',
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
                              .markAllAsRead(patientId),
                    icon: const Icon(Icons.done_all_outlined),
                    label: const Text('Marcar leídas'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const OcgEmptyState(
                  icon: Icons.notifications_none_outlined,
                  title: 'No tienes notificaciones',
                  subtitle:
                      'Aquí aparecerán recordatorios de citas, pagos, documentos y avances de tratamiento.',
                )
              else if (filtered.isEmpty)
                _PatientNotificationEmptyFilter(
                  onClear: () =>
                      setState(() => _filter = _PatientNotificationFilter.all),
                )
              else
                for (final item in filtered) ...[
                  _PatientNotificationCard(
                    item: item,
                    actionsDisabled: actionsState.isLoading,
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
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
    final filtered = items
        .where((item) => _matchesFilter(item, _filter))
        .toList();
    filtered.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return filtered;
  }

  bool _matchesFilter(
    AppNotificationModel item,
    _PatientNotificationFilter filter,
  ) {
    return switch (filter) {
      _PatientNotificationFilter.all => true,
      _PatientNotificationFilter.unread => !item.read,
      _PatientNotificationFilter.appointments =>
        _patientKind(item) == _PatientNotificationKind.appointment,
      _PatientNotificationFilter.payments =>
        _patientKind(item) == _PatientNotificationKind.payment,
      _PatientNotificationFilter.treatments =>
        _patientKind(item) == _PatientNotificationKind.treatment,
      _PatientNotificationFilter.documents =>
        _patientKind(item) == _PatientNotificationKind.document,
      _PatientNotificationFilter.simulations =>
        _patientKind(item) == _PatientNotificationKind.simulation,
    };
  }

  int _countForFilter(
    _PatientNotificationFilter filter,
    List<AppNotificationModel> items,
  ) => items.where((item) => _matchesFilter(item, filter)).length;

  Widget _buildFilters(List<AppNotificationModel> items) {
    final filters = _PatientNotificationFilter.values;
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
                  : OcgColors.bronze.withValues(alpha: 0.24),
            ),
            onSelected: (_) => setState(() => _filter = filter),
          );
        },
      ),
    );
  }

  String _filterLabel(_PatientNotificationFilter filter) {
    return switch (filter) {
      _PatientNotificationFilter.all => 'Todas',
      _PatientNotificationFilter.unread => 'No leídas',
      _PatientNotificationFilter.appointments => 'Citas',
      _PatientNotificationFilter.payments => 'Pagos',
      _PatientNotificationFilter.treatments => 'Tratamiento',
      _PatientNotificationFilter.documents => 'Docs',
      _PatientNotificationFilter.simulations => 'Simulador',
    };
  }

  IconData _filterIcon(_PatientNotificationFilter filter) {
    return switch (filter) {
      _PatientNotificationFilter.all => Icons.layers_outlined,
      _PatientNotificationFilter.unread => Icons.mark_email_unread_outlined,
      _PatientNotificationFilter.appointments => Icons.event_available_outlined,
      _PatientNotificationFilter.payments => Icons.payments_outlined,
      _PatientNotificationFilter.treatments => Icons.monitor_heart_outlined,
      _PatientNotificationFilter.documents => Icons.folder_shared_outlined,
      _PatientNotificationFilter.simulations => Icons.auto_awesome_outlined,
    };
  }
}

enum _PatientNotificationKind {
  appointment,
  payment,
  treatment,
  document,
  simulation,
  generic,
}

_PatientNotificationKind _patientKind(AppNotificationModel item) {
  final raw = '${item.type} ${item.entityType ?? ''} ${item.targetRoute ?? ''}'
      .toLowerCase();
  if (raw.contains('appointment') || raw.contains('cita')) {
    return _PatientNotificationKind.appointment;
  }
  if (raw.contains('payment') || raw.contains('pago') || raw.contains('payu')) {
    return _PatientNotificationKind.payment;
  }
  if (raw.contains('treatment') || raw.contains('tratamiento')) {
    return _PatientNotificationKind.treatment;
  }
  if (raw.contains('document') ||
      raw.contains('clinical') ||
      raw.contains('archivo')) {
    return _PatientNotificationKind.document;
  }
  if (raw.contains('simulation') || raw.contains('simulador')) {
    return _PatientNotificationKind.simulation;
  }
  return _PatientNotificationKind.generic;
}

IconData _patientKindIcon(_PatientNotificationKind kind) {
  return switch (kind) {
    _PatientNotificationKind.appointment => Icons.event_available_outlined,
    _PatientNotificationKind.payment => Icons.payments_outlined,
    _PatientNotificationKind.treatment => Icons.monitor_heart_outlined,
    _PatientNotificationKind.document => Icons.folder_shared_outlined,
    _PatientNotificationKind.simulation => Icons.auto_awesome_outlined,
    _PatientNotificationKind.generic => Icons.notifications_outlined,
  };
}

Color _patientKindColor(_PatientNotificationKind kind) {
  return switch (kind) {
    _PatientNotificationKind.appointment => const Color(0xFF1565C0),
    _PatientNotificationKind.payment => const Color(0xFF2E7D32),
    _PatientNotificationKind.treatment => const Color(0xFF7A8A20),
    _PatientNotificationKind.document => const Color(0xFF7E3AF2),
    _PatientNotificationKind.simulation => const Color(0xFFC56B16),
    _PatientNotificationKind.generic => OcgColors.bronze,
  };
}

String _patientKindLabel(_PatientNotificationKind kind) {
  return switch (kind) {
    _PatientNotificationKind.appointment => 'Cita',
    _PatientNotificationKind.payment => 'Pago',
    _PatientNotificationKind.treatment => 'Tratamiento',
    _PatientNotificationKind.document => 'Documento',
    _PatientNotificationKind.simulation => 'Simulador',
    _PatientNotificationKind.generic => 'General',
  };
}

class _PatientNotificationsHero extends StatelessWidget {
  const _PatientNotificationsHero({
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
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.82)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
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
          colors: [Color(0xFF4A3527), Color(0xFFB6895F)],
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withValues(alpha: 0.14),
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
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tus avisos importantes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Citas, pagos, documentos y avances de tu tratamiento en un solo lugar.',
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

class _PatientNotificationEmptyFilter extends StatelessWidget {
  const _PatientNotificationEmptyFilter({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OcgColors.bronze.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            size: 42,
            color: OcgColors.bronze,
          ),
          const SizedBox(height: 12),
          const Text(
            'Sin avisos en este filtro',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cambia el filtro para revisar otros tipos de notificaciones.',
            textAlign: TextAlign.center,
            style: TextStyle(color: OcgColors.bronze, height: 1.3),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpiar filtro'),
          ),
        ],
      ),
    );
  }
}

class _PatientNotificationCard extends ConsumerWidget {
  const _PatientNotificationCard({
    required this.item,
    required this.actionsDisabled,
  });

  final AppNotificationModel item;
  final bool actionsDisabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = _patientKind(item);
    final color = _patientKindColor(kind);
    final routeLabel = _routeLabel(item);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: actionsDisabled
          ? null
          : () => ref
                .read(notificationsActionsProvider.notifier)
                .openNotification(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.read ? Colors.white : const Color(0xFFFFFBF4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: item.read
                ? OcgColors.espresso.withValues(alpha: 0.10)
                : color.withValues(alpha: 0.36),
          ),
          boxShadow: [
            BoxShadow(
              color: OcgColors.espresso.withValues(
                alpha: item.read ? 0.035 : 0.07,
              ),
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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_patientKindIcon(kind), color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isEmpty ? 'Notificación' : item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: OcgColors.espresso,
                          fontSize: 15,
                          fontWeight: item.read
                              ? FontWeight.w700
                              : FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: OcgColors.ink.withValues(
                            alpha: item.read ? 0.78 : 0.92,
                          ),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PatientMetaChip(
                  icon: item.read
                      ? Icons.mark_email_read_outlined
                      : Icons.mark_email_unread_outlined,
                  label: item.read ? 'Leída' : 'No leída',
                  color: item.read ? OcgColors.ink : color,
                  highlighted: !item.read,
                ),
                _PatientMetaChip(
                  icon: _patientKindIcon(kind),
                  label: _patientKindLabel(kind),
                  color: color,
                ),
                _PatientMetaChip(
                  icon: Icons.schedule_outlined,
                  label: item.createdAt != null
                      ? dateFmt.format(item.createdAt!)
                      : 'Ahora',
                  color: OcgColors.ink,
                ),
                if (routeLabel != null)
                  _PatientMetaChip(
                    icon: Icons.navigation_outlined,
                    label: routeLabel,
                    color: OcgColors.espresso,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: actionsDisabled
                    ? null
                    : () => ref
                          .read(notificationsActionsProvider.notifier)
                          .openNotification(item),
                icon: const Icon(Icons.arrow_forward_outlined, size: 16),
                label: Text(item.read ? 'Abrir' : 'Leer y abrir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _routeLabel(AppNotificationModel item) {
    final route =
        item.targetRoute ?? item.toRoutingPayload()['route']?.toString() ?? '';
    if (route.contains('/appointments')) return 'Ir a citas';
    if (route.contains('/payments')) return 'Ir a pagos';
    if (route.contains('/clinical-files')) return 'Ir a documentos';
    if (route.contains('/simulations')) return 'Ir a simulador';
    if (route.contains('/notifications')) return 'Ir a historial';
    if (item.type.contains('treatment')) return 'Ir a tratamiento';
    return null;
  }
}

class _PatientMetaChip extends StatelessWidget {
  const _PatientMetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final background = highlighted
        ? color.withValues(alpha: 0.13)
        : color.withValues(alpha: 0.07);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: highlighted ? 0.20 : 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.88)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              color: color.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}
