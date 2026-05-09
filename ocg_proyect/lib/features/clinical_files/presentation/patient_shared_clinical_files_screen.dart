import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/ocg_colors.dart';
import '../../../shared/widgets/ocg_empty_state.dart';
import '../../../shared/widgets/ocg_loading_state.dart';
import '../../../shared/widgets/ocg_app_bar.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/models/clinical_file_model.dart';
import '../providers/clinical_files_provider.dart';

class PatientSharedClinicalFilesScreen extends ConsumerWidget {
  const PatientSharedClinicalFilesScreen({
    super.key,
    this.embedded = false,
    this.patientIdOverride,
    this.showEmbeddedHeader = true,
  });

  final bool embedded;
  final String? patientIdOverride;
  final bool showEmbeddedHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authStateProvider).asData?.value?.uid ?? '';
    final effectivePatientId = (patientIdOverride?.isNotEmpty == true)
        ? patientIdOverride!
        : currentUserId;

    if (effectivePatientId.isEmpty) {
      return const Center(
        child: Text('Debes iniciar sesión para ver tus archivos clínicos.'),
      );
    }

    final filesAsync = ref.watch(
      patientClinicalFilesProvider((
        patientId: effectivePatientId,
        treatmentId: null,
        onlyVisibleToPatient: true,
      )),
    );

    final content = Container(
      color: const Color(0xFFF8F5F0),
      child: filesAsync.when(
        loading: () => const Center(
          child: OcgLoadingState(),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              'No se pudieron cargar tus archivos clínicos.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: OcgColors.bronze),
            ),
          ),
        ),
        data: (files) {
          final visibleFiles = files.where((file) {
            return file.patientId == effectivePatientId &&
                file.active &&
                file.visibleToPatient;
          }).toList();

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              embedded ? 12 : 16,
              16,
              embedded ? 110 : 24,
            ),
            itemCount: visibleFiles.isEmpty
                ? (showEmbeddedHeader ? 2 : 1)
                : visibleFiles.length + (showEmbeddedHeader ? 1 : 0),
            separatorBuilder: (_, index) =>
                SizedBox(height: index == 0 ? 12 : 10),
            itemBuilder: (context, index) {
              if (showEmbeddedHeader && index == 0) {
                return const _PatientClinicalFilesHeader();
              }
              if (visibleFiles.isEmpty) {
                return const _PatientClinicalFilesEmptyState();
              }
              final fileIndex = showEmbeddedHeader ? index - 1 : index;
              return _PatientClinicalFileCard(file: visibleFiles[fileIndex]);
            },
          );
        },
      ),
    );

    if (embedded) return content;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: OcgAppBar(title: 'Documentos clínicos', onBack: () => Navigator.of(context).pop()),
      body: content,
    );
  }
}

class _PatientClinicalFilesHeader extends StatelessWidget {
  const _PatientClinicalFilesHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OcgColors.espresso, Color(0xFF4A3628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2C2016),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.folder_shared_outlined, color: OcgColors.ivory, size: 28),
          SizedBox(height: 12),
          Text(
            'Documentos clínicos',
            style: TextStyle(
              color: OcgColors.ivory,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Radiografías, PDFs, imágenes y soportes compartidos por la clínica.',
            style: TextStyle(color: Color(0xDDF8F5F0), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PatientClinicalFilesEmptyState extends StatelessWidget {
  const _PatientClinicalFilesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OcgColors.bronze.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x102C2016),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const OcgEmptyState(
        icon: Icons.folder_shared_outlined,
        title: 'Aún no tienes documentos clínicos compartidos',
        subtitle:
            'Cuando la clínica comparta radiografías, PDFs o imágenes clínicas contigo, aparecerán aquí.',
      ),
    );
  }
}

class _PatientClinicalFileCard extends StatelessWidget {
  const _PatientClinicalFileCard({required this.file});

  final ClinicalFileModel file;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy  HH:mm');
    final treatmentName = file.treatmentNameSnapshot?.trim();
    final notes = file.notes?.trim();
    final accentColor = _fileAccentColor(file);
    final fileIcon = _fileIcon(file);
    final fileLabel = file.isPdf ? 'PDF' : (file.isImage ? 'IMG' : 'DOC');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFCF8), Color(0xFFF7F2E8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C2016).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // File type badge with gradient
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentColor, accentColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(fileIcon, color: Colors.white, size: 24),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(fileLabel,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.displayName.trim().isEmpty ? file.originalName : file.displayName,
                      style: const TextStyle(
                        color: Color(0xFF2C2016),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _categoryLabel(file.category),
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time, size: 12, color: const Color(0xFFA89078)),
                      const SizedBox(width: 4),
                      Text(
                        dateFmt.format(file.uploadedAt),
                        style: const TextStyle(
                          color: Color(0xFFA89078),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
            if (treatmentName != null && treatmentName.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoLine(
                icon: Icons.medical_information_outlined,
                text: 'Tratamiento: $treatmentName',
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoLine(icon: Icons.notes_outlined, text: 'Notas: $notes'),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _openFile(context, file.downloadUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(file.isPdf ? 'Abrir PDF' : 'Ver archivo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2016),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(ClinicalFileModel file) {
    if (file.isPdf) return Icons.picture_as_pdf_outlined;
    if (file.isImage) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color _fileAccentColor(ClinicalFileModel file) {
    if (file.isPdf) return OcgColors.error;
    if (file.isImage) return const Color(0xFF1565C0);
    return OcgColors.bronze;
  }

  String _categoryLabel(String category) => category
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');

  Future<void> _openFile(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo sin URL disponible.')),
      );
      return;
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL de archivo inválida.')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo.')),
      );
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: OcgColors.bronze),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: OcgColors.ink,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
