import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_names.dart';
import '../../../../../shared/theme/ocg_colors.dart';

class PatientNavigation extends StatelessWidget {
  const PatientNavigation({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (label: 'Inicio', icon: Icons.home_outlined, route: RouteNames.patientHome),
      (label: 'Citas', icon: Icons.calendar_today_outlined, route: RouteNames.patientAppointments),
      (label: 'Tratamiento', icon: Icons.monitor_heart_outlined, route: RouteNames.patientHome),
      (label: 'Pagos', icon: Icons.payments_outlined, route: RouteNames.patientPayments),
      (label: 'Simulaciones', icon: Icons.auto_awesome_outlined, route: RouteNames.patientSimulations),
      (label: 'Perfil', icon: Icons.person_outline, route: RouteNames.patientProfile),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 260;

        if (compact) {
          return Container(
            color: OcgColors.mist,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: items.map((item) {
                final active = currentRoute == item.route;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    selected: active,
                    selectedColor: OcgColors.sand,
                    label: Text(item.label),
                    onSelected: (_) => context.go(item.route),
                  ),
                );
              }).toList(),
            ),
          );
        }

        return Container(
          width: 220,
          color: OcgColors.mist,
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: items.map((item) {
              final active = currentRoute == item.route;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  selected: active,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  selectedTileColor: OcgColors.sand,
                  iconColor: OcgColors.espresso,
                  textColor: OcgColors.espresso,
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  onTap: () => context.go(item.route),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
