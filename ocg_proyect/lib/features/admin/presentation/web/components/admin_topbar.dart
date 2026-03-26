import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_names.dart';
import '../../../../../shared/constants/firestore_paths.dart';
import '../../../../../shared/theme/ocg_colors.dart';

class AdminTopbar extends StatefulWidget {
  const AdminTopbar({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<AdminTopbar> createState() => _AdminTopbarState();
}

class _AdminTopbarState extends State<AdminTopbar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<_GlobalSearchItem>> _searchGlobal(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final db = FirebaseFirestore.instance;
    final results = <_GlobalSearchItem>[];

    final patientsSnap = await db
        .collection(FirestorePaths.patients)
        .limit(200)
        .get();

    for (final doc in patientsSnap.docs) {
      final data = doc.data();
      final nombre = (data['nombre'] ?? '').toString();
      final correo = (data['email'] ?? '').toString();
      final telefono = (data['telefono'] ?? '').toString();
      final hayMatch = nombre.toLowerCase().contains(q) ||
          correo.toLowerCase().contains(q) ||
          telefono.toLowerCase().contains(q);
      if (!hayMatch) continue;

      results.add(
        _GlobalSearchItem(
          icon: Icons.person_outline,
          title: nombre.isEmpty ? 'Paciente sin nombre' : nombre,
          subtitle: 'Paciente · ${correo.isNotEmpty ? correo : telefono}',
          onTap: (context) => context.go(
            RouteNames.adminPatientDetail.replaceFirst(':patientId', doc.id),
          ),
        ),
      );
    }

    final appointmentsSnap = await db
        .collection(FirestorePaths.appointments)
        .orderBy('fechaHora', descending: true)
        .limit(250)
        .get();

    for (final doc in appointmentsSnap.docs) {
      final data = doc.data();
      final patientName = (data['patientName'] ?? '').toString();
      final notas = (data['notas'] ?? '').toString();
      final estado = (data['estado'] ?? '').toString();
      final patientId = (data['patientId'] ?? '').toString();
      final tipo = (data['tipo'] ?? '').toString();

      final hayMatch = patientName.toLowerCase().contains(q) ||
          notas.toLowerCase().contains(q) ||
          estado.toLowerCase().contains(q) ||
          tipo.toLowerCase().contains(q);
      if (!hayMatch || patientId.isEmpty) continue;

      results.add(
        _GlobalSearchItem(
          icon: Icons.event_note_outlined,
          title: patientName.isEmpty ? 'Cita' : 'Cita · $patientName',
          subtitle: 'Agenda · Estado: ${estado.isEmpty ? 'N/D' : estado}',
          onTap: (context) => context.go(
            RouteNames.adminPatientDetail.replaceFirst(':patientId', patientId),
          ),
        ),
      );
    }

    final txSnap = await db.collectionGroup('transactions').limit(250).get();
    for (final doc in txSnap.docs) {
      final data = doc.data();
      final ref = (data['referencia'] ?? '').toString();
      final notas = (data['notas'] ?? '').toString();
      final registradoPor = (data['registradoPor'] ?? '').toString();
      final patientId = doc.reference.parent.parent?.id ?? '';

      final hayMatch = ref.toLowerCase().contains(q) ||
          notas.toLowerCase().contains(q) ||
          registradoPor.toLowerCase().contains(q);
      if (!hayMatch || patientId.isEmpty) continue;

      results.add(
        _GlobalSearchItem(
          icon: Icons.payments_outlined,
          title: 'Pago ${ref.isEmpty ? '' : '· Ref $ref'}'.trim(),
          subtitle: 'Transacción · Registrado por: ${registradoPor.isEmpty ? 'N/D' : registradoPor}',
          onTap: (context) => context.go(
            RouteNames.adminPatientDetail.replaceFirst(':patientId', patientId),
          ),
        ),
      );
    }

    return results.take(40).toList();
  }

  Future<void> _runSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Buscando en pacientes, citas y pagos...')),
    );

    try {
      final results = await _searchGlobal(query);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Resultados para "$query"'),
          content: SizedBox(
            width: 640,
            child: results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No encontré coincidencias en el sistema.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = results[index];
                      return ListTile(
                        leading: Icon(item.icon, color: OcgColors.espresso),
                        title: Text(item.title),
                        subtitle: Text(item.subtitle),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          item.onTap(context);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo ejecutar la búsqueda global.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;

        return Container(
          height: compact ? 62 : 68,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          decoration: const BoxDecoration(
            color: OcgColors.ivory,
            border: Border(bottom: BorderSide(color: Color(0x11000000))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: OcgColors.espresso,
                  ),
                ),
              ),
              if (!compact)
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _runSearch(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Buscar en todo el sistema...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Buscar',
                        onPressed: _runSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                      filled: true,
                      fillColor: OcgColors.mist,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GlobalSearchItem {
  const _GlobalSearchItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context) onTap;
}
