import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/ocg_colors.dart';
import '../legacy_migration_service.dart';
import '../providers/legacy_migration_provider.dart';

/// Dialogo para ejecutar la migracion legacy (Bloque 09).
class LegacyMigrationDialog extends ConsumerStatefulWidget {
  const LegacyMigrationDialog({super.key});

  @override
  ConsumerState<LegacyMigrationDialog> createState() =>
      _LegacyMigrationDialogState();
}

class _LegacyMigrationDialogState
    extends ConsumerState<LegacyMigrationDialog> {
  String _progressMessage = '';
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final migrationState = ref.watch(legacyMigrationProvider);

    return AlertDialog(
      title: const Text('Migracion Legacy'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta accion revisa y corrige datos legacy en todo el sistema:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _bullet('Citas sin treatmentId → auto-asociar o marcar como legacy'),
            _bullet('Documentos clinicos sin treatmentId → auto-asociar o marcar'),
            _bullet('Stage history → revisar sin modificar'),
            _bullet('Dictamenes → revisar trazabilidad'),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Esta es una migracion CONSERVADORA. No se inventan datos. '
              'Los registros ambiguos se marcan para revision manual.',
              style: TextStyle(
                color: Color(0xFFC56B16),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (!_confirmed)
              Row(
                children: [
                  Checkbox(
                    value: _confirmed,
                    onChanged: (_) => setState(() => _confirmed = true),
                  ),
                  const Expanded(
                    child: Text(
                      'Confirmo que entiendo los cambios que se aplicaran.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            if (_progressMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: migrationState.isLoading ? null : 1,
                backgroundColor: OcgColors.mist,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  OcgColors.bronze,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _progressMessage,
                style: const TextStyle(
                  fontSize: 12,
                  color: OcgColors.bronze,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (migrationState.hasValue && migrationState.value != null)
              _buildResults(migrationState.value!),
            if (migrationState.hasError)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: ${migrationState.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        if (!_confirmed && !migrationState.isLoading)
          FilledButton(
            onPressed: () async {
              setState(() => _confirmed = true);
              ref.read(legacyMigrationProvider.notifier).migrateAll();

              // Listen to progress
              ref.listen(legacyMigrationProvider, (prev, next) {
                if (next.isLoading) {
                  setState(() => _progressMessage = 'Iniciando migracion...');
                } else if (next.hasValue) {
                  final results = next.value!;
                  final total = results.fold<int>(
                    0,
                    (sum, r) => sum + r.totalActions,
                  );
                  final withErrors = results.where((r) => r.hasErrors).length;
                  setState(() {
                    _progressMessage =
                        'Completada: $total acciones en ${results.length} pacientes. '
                        '${withErrors > 0 ? '$withErrors con errores.' : ''}';
                  });
                } else if (next.hasError) {
                  setState(() => _progressMessage = 'Error en la migracion.');
                }
              });
            },
            child: const Text('Ejecutar migracion'),
          ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildResults(List<LegacyMigrationResult> results) {
    final totalActions = results.fold<int>(
      0,
      (sum, r) => sum + r.totalActions,
    );
    final totalAutoLinked = results.fold<int>(
      0,
      (sum, r) => sum + r.appointmentsAutoLinked + r.clinicalFilesAutoLinked,
    );
    final totalMarkedLegacy = results.fold<int>(
      0,
      (sum, r) => sum + r.appointmentsMarkedLegacy + r.clinicalFilesMarkedLegacy,
    );
    final totalConsultations = results.fold<int>(
      0,
      (sum, r) => sum + r.consultationsReviewed,
    );
    final totalStageHistory = results.fold<int>(
      0,
      (sum, r) => sum + r.stageHistoryReviewed,
    );
    final totalErrors = results.fold<int>(
      0,
      (sum, r) => sum + r.errors.length,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OcgColors.mist,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de migracion',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _summaryRow('Pacientes procesados', '${results.length}'),
          _summaryRow('Total acciones', '$totalActions'),
          _summaryRow('Auto-asociados', '$totalAutoLinked', color: const Color(0xFF2E7D4C)),
          _summaryRow('Marcados como legacy', '$totalMarkedLegacy', color: const Color(0xFFC56B16)),
          _summaryRow('Dictamenes revisados', '$totalConsultations'),
          _summaryRow('Stage history revisado', '$totalStageHistory'),
          if (totalErrors > 0)
            _summaryRow('Errores', '$totalErrors', color: Colors.red),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Detalle por paciente:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            ...results.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${r.patientName}: ${r.totalActions} acciones${r.hasErrors ? ' (${r.errors.length} errores)' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
