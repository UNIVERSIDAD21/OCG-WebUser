import 'package:flutter/material.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../../../../shared/utils/ui_formatters.dart';
import '../../../../shared/widgets/profile_photo_avatar.dart';
import '../../data/models/patient_model.dart';

class PatientProfileTab extends StatelessWidget {
  const PatientProfileTab({
    super.key,
    required this.patient,
    this.scrollable = true,
  });

  final PatientModel patient;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClinicalProfileHero(patient: patient),
          const SizedBox(height: 14),
          _ProfileSectionCard(
            title: 'Datos básicos',
            subtitle: 'Información de contacto y datos administrativos útiles.',
            icon: Icons.badge_outlined,
            children: [
              _ProfileInfoTile(
                icon: Icons.mail_outline,
                label: 'Correo',
                value: _human(patient.email, fallback: 'No registrado'),
              ),
              _ProfileInfoTile(
                icon: Icons.phone_outlined,
                label: 'Teléfono',
                value: _human(patient.telefono, fallback: 'No registrado'),
              ),
              _ProfileInfoTile(
                icon: Icons.cake_outlined,
                label: 'Fecha de nacimiento',
                value: _fmt(patient.fechaNacimiento),
                trailing: _ageLabel(patient.fechaNacimiento),
              ),
              _ProfileInfoTile(
                icon: Icons.event_available_outlined,
                label: 'Fecha de creación',
                value: patient.createdAt == null
                    ? 'No registrada'
                    : _fmt(patient.createdAt!),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProfileSectionCard(
            title: 'Datos clínicos',
            subtitle: 'Resumen clínico del tratamiento actual del paciente.',
            icon: Icons.monitor_heart_outlined,
            children: [
              _ProfileInfoTile(
                icon: Icons.medical_services_outlined,
                label: 'Tipo de tratamiento',
                value: _treatmentTypeLabel(patient.tipoTratamiento),
              ),
              _ProfileInfoTile(
                icon: Icons.timeline_outlined,
                label: 'Etapa actual',
                value: formatTreatmentStage(patient.etapaActual),
              ),
              _ProfileInfoTile(
                icon: Icons.play_circle_outline,
                label: 'Inicio',
                value: _fmt(patient.fechaInicio),
              ),
              _ProfileInfoTile(
                icon: Icons.flag_outlined,
                label: 'Fin estimado',
                value: patient.fechaEstimadaFin == null
                    ? 'Sin fecha estimada'
                    : _fmt(patient.fechaEstimadaFin!),
              ),
              _ProfileNotesTile(
                value: _human(
                  patient.notasClinicas,
                  fallback: 'Sin notas clínicas',
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!scrollable) return content;
    return ListView(padding: EdgeInsets.zero, children: [content]);
  }

  static String _fmt(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }

  static String _human(String? value, {required String fallback}) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return fallback;
    return clean;
  }

  static String _ageLabel(DateTime birthDate) {
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    final hadBirthday =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) years--;
    if (years < 0 || years > 120) return 'Edad no definida';
    return '$years años';
  }

  static String _treatmentTypeLabel(TreatmentType? type) {
    if (type == null) return 'No definido';
    return switch (type) {
      TreatmentType.convencional => 'Ortodoncia convencional',
      TreatmentType.estetico => 'Ortodoncia estética',
      TreatmentType.autoligado => 'Ortodoncia autoligado',
      TreatmentType.alineadores => 'Alineadores',
      TreatmentType.ortopedia => 'Ortopedia',
      TreatmentType.interceptivo => 'Interceptivo',
      TreatmentType.retenedores => 'Retenedores',
    };
  }
}

class _ClinicalProfileHero extends StatelessWidget {
  const _ClinicalProfileHero({required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    final secondary = [
      patient.email.trim(),
      patient.telefono.trim(),
    ].where((item) => item.isNotEmpty).join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3527), Color(0xFF8C6A4E)],
        ),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: OcgColors.ivory.withOpacity(0.55)),
                ),
                child: ProfilePhotoAvatar(
                  label: patient.nombre,
                  photoUrl: patient.fotoUrl,
                  radius: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PatientProfileTab._human(
                        patient.nombre,
                        fallback: 'Paciente sin nombre',
                      ),
                      style: const TextStyle(
                        color: OcgColors.ivory,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      secondary.isEmpty ? 'Contacto no registrado' : secondary,
                      style: TextStyle(
                        color: OcgColors.ivory.withOpacity(0.82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                icon: Icons.favorite_border,
                label: patient.treatmentStatusLabel,
              ),
              _HeroChip(
                icon: Icons.account_balance_wallet_outlined,
                label: patient.saldoPendiente > 0
                    ? 'Saldo ${formatCop(patient.saldoPendiente)} COP'
                    : 'Sin saldo pendiente',
              ),
              _HeroChip(
                icon: Icons.event_available_outlined,
                label: patient.proximaCita == null
                    ? 'Sin próxima cita'
                    : 'Próxima ${PatientProfileTab._fmt(patient.proximaCita!)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OcgColors.ivory.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OcgColors.ivory.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: OcgColors.ivory),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: OcgColors.ivory,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.05),
            blurRadius: 14,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EFE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: OcgColors.espresso, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: OcgColors.espresso,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: OcgColors.bronze,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: OcgColors.bronze, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: OcgColors.bronze,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: OcgColors.espresso,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: OcgColors.ivory,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  color: OcgColors.espresso,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileNotesTile extends StatelessWidget {
  const _ProfileNotesTile({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_outlined, color: OcgColors.bronze, size: 18),
              SizedBox(width: 8),
              Text(
                'Notas clínicas',
                style: TextStyle(
                  color: OcgColors.bronze,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: OcgColors.espresso,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
