import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class AdminTopbar extends StatelessWidget {
  const AdminTopbar({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: OcgColors.ivory,
        border: Border(bottom: BorderSide(color: Color(0x11000000))),
      ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
              if (!compact)
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Buscar...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: OcgColors.mist,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              if (!compact) const SizedBox(width: 10),
              Tooltip(
                message: 'Notificaciones',
                child: IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
              ),
              Tooltip(
                message: 'Acciones rápidas',
                child: IconButton(onPressed: () {}, icon: const Icon(Icons.flash_on_outlined)),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 16,
                backgroundColor: OcgColors.bronze,
                child: Icon(Icons.person, color: OcgColors.ivory, size: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}
