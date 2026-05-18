import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/consultation_model.dart';
import '../../clinical_files/data/models/clinical_file_model.dart';
import '../../patients/data/models/patient_model.dart';
import '../../treatment/data/models/patient_treatment.dart';

/// Servicio que genera un PDF tipo reporte clinico de un dictamen.
///
/// Usa el paquete `pdf` (MVP del Bloque 07).
/// El PDF se genera desde los datos ya cargados de:
/// - ConsultationModel
/// - PatientModel
/// - PatientTreatment
/// - ClinicalFileModel (adjuntos)
class ConsultationPdfService {
  ConsultationPdfService({this.logoBytes});

  /// Logo de la clinica en bytes (PNG). Opcional.
  final Uint8List? logoBytes;

  // ─── Entrada principal ──────────────────────────────────────────────────

  /// Genera el PDF completo del dictamen.
  Future<Uint8List> generate({
    required ConsultationModel consultation,
    required PatientModel patient,
    PatientTreatment? treatment,
    List<ClinicalFileModel> clinicalFiles = const [],
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          top: 40,
          bottom: 40,
          left: 30,
          right: 30,
        ),
        build: (context) => [
          _buildHeader(consultation),
          pw.SizedBox(height: 24),
          _buildPatientSection(patient, consultation),
          pw.SizedBox(height: 18),
          _buildTreatmentSection(treatment, consultation),
          pw.SizedBox(height: 18),
          _buildClinicalSummarySection(consultation),
          if (consultation.signatureUrl != null &&
              consultation.signatureUrl!.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _buildSignatureSection(consultation),
          ],
          if (clinicalFiles.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _buildAttachmentsSection(clinicalFiles),
          ],
          pw.Spacer(),
          _buildFooter(consultation),
        ],
        footer: (context) => _buildPageFooter(context),
      ),
    );

    return pdf.save();
  }

  // ─── Encabezado ─────────────────────────────────────────────────────────

  pw.Widget _buildHeader(ConsultationModel consultation) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final code = consultation.id.length > 8
        ? consultation.id.substring(0, 8)
        : consultation.id;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildLogoBox(),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ORAL CARE GLOBAL BIONICS',
                    style: _titleStyle,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Dictamen Clinico',
                    style: _subtitleStyle,
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _smallLabel('Fecha de generacion'),
                pw.Text(
                  dateFmt.format(DateTime.now()),
                  style: _smallBoldStyle,
                ),
                pw.SizedBox(height: 4),
                _smallLabel('Codigo dictamen'),
                pw.Text(
                  code,
                  style: _smallBoldStyle,
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: _ocgBronzePdf, thickness: 2),
      ],
    );
  }

  pw.Widget _buildLogoBox() {
    if (logoBytes != null) {
      return pw.Container(
        width: 56,
        height: 56,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(12),
          color: PdfColors.grey200,
        ),
        child: pw.Center(
          child: pw.Text(
            'OCG',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _ocgBronzePdf,
            ),
          ),
        ),
      );
    }
    return pw.Container(
      width: 56,
      height: 56,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _ocgBronzePdf, width: 1.5),
      ),
      child: pw.Center(
        child: pw.Text(
          'OCG',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _ocgBronzePdf,
          ),
        ),
      ),
    );
  }

  // ─── Datos del paciente ─────────────────────────────────────────────────

  pw.Widget _buildPatientSection(
    PatientModel patient,
    ConsultationModel consultation,
  ) {
    final dateFmt = DateFormat('dd/MM/yyyy');

    return _buildSectionCard(
      title: 'Datos del paciente',
      rows: [
        _row('Nombre', patient.nombre),
        if (patient.email.isNotEmpty) _row('Email', patient.email),
        if (patient.telefono.isNotEmpty) _row('Telefono', patient.telefono),
        _row(
          'Fecha de la cita/dictamen',
          dateFmt.format(consultation.date),
        ),
      ],
    );
  }

  // ─── Datos del tratamiento ──────────────────────────────────────────────

  pw.Widget _buildTreatmentSection(
    PatientTreatment? treatment,
    ConsultationModel consultation,
  ) {
    final treatmentName = consultation.treatmentNameSnapshot ??
        treatment?.displayName ??
        'Sin tratamiento';
    final treatmentStatus = treatment?.estado ?? 'N/A';
    final isPrimary = treatment?.isPrimary ?? false;

    String? etapaAntes;
    if (consultation.phaseSnapshot != null) {
      final prev = consultation.phaseSnapshot!.previousStage;
      etapaAntes = stageNames[prev] ?? prev.name;
    }
    String? etapaDespues;
    if (consultation.stageId != null) {
      etapaDespues = stageNames[consultation.stageId!];
    }
    etapaDespues ??= consultation.stageNameSnapshot ?? 'N/A';

    return _buildSectionCard(
      title: 'Datos del tratamiento',
      rows: [
        _row('Tratamiento', treatmentName),
        _row('Estado', treatmentStatus),
        _row('Etapa antes', etapaAntes ?? 'N/A'),
        _row('Etapa despues', etapaDespues),
        _row(
          'Tipo',
          isPrimary ? 'Tratamiento principal' : 'Tratamiento secundario',
        ),
      ],
    );
  }

  // ─── Resumen clinico ────────────────────────────────────────────────────

  pw.Widget _buildClinicalSummarySection(ConsultationModel consultation) {
    final notes = (consultation.clinicalNotes ?? '').trim();

    final children = <pw.Widget>[
      pw.Text(
        'Resumen clinico',
        style: _sectionTitleStyle,
      ),
      pw.SizedBox(height: 8),
    ];

    if (notes.isNotEmpty) {
      children.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            notes,
            style: _bodyTextStyle,
          ),
        ),
      );
    }

    children.add(pw.SizedBox(height: 6));
    children.add(
      pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: 'Doctor(a): ',
              style: _labelStyle,
            ),
            pw.TextSpan(
              text: consultation.doctorName,
              style: _bodyTextStyle,
            ),
          ],
        ),
      ),
    );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ─── Firma ──────────────────────────────────────────────────────────────

  pw.Widget _buildSignatureSection(ConsultationModel consultation) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final sigDate = consultation.signatureCapturedAt ?? consultation.date;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Firma del paciente',
          style: _sectionTitleStyle,
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          height: 100,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Center(
            child: pw.Text(
              'Firma capturada el ${dateFmt.format(sigDate)}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'El paciente firma como constancia de haber recibido la informacion '
          'clinica descrita en este dictamen. Este documento no sustituye el '
          'consentimiento informado cuando aplique.',
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // ─── Adjuntos ───────────────────────────────────────────────────────────

  pw.Widget _buildAttachmentsSection(List<ClinicalFileModel> files) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Documentos adjuntos al dictamen',
          style: _sectionTitleStyle,
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _th('Archivo'),
                _th('Categoria'),
                _th('Visibilidad'),
              ],
            ),
            for (final file in files)
              pw.TableRow(
                children: [
                  _td(file.displayName),
                  _td(file.category.replaceAll('_', ' ')),
                  _td(file.visibleToPatient ? 'Paciente' : 'Solo admin'),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ─── Pie de pagina ──────────────────────────────────────────────────────

  pw.Widget _buildFooter(ConsultationModel consultation) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: _ocgBronzePdf, thickness: 1.5),
        pw.SizedBox(height: 6),
        pw.Text(
          'Oral Care Global Bionics',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _ocgEspressoPdf,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Documento confidencial. Uso exclusivo del personal autorizado.',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'v1.0 | '
          'Paciente: ${consultation.patientId} | '
          'Tratamiento: ${consultation.treatmentId ?? 'N/A'} | '
          'Cita: ${consultation.appointmentId ?? 'N/A'} | '
          'Dictamen: ${consultation.id}',
          style: pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey500,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Pagina ${context.pageNumber} de ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  pw.Widget _buildSectionCard({
    required String title,
    required List<pw.Widget> rows,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _sectionTitleStyle),
          pw.SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label: ', style: _labelStyle),
            pw.TextSpan(text: value, style: _bodyTextStyle),
          ],
        ),
      ),
    );
  }

  pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _ocgEspressoPdf,
        ),
      ),
    );
  }

  pw.Widget _td(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9)),
    );
  }

  pw.Widget _smallLabel(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    );
  }

  // ─── Text styles ────────────────────────────────────────────────────────

  static pw.TextStyle get _titleStyle => pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: _ocgEspressoPdf,
      );

  static pw.TextStyle get _subtitleStyle => pw.TextStyle(
        fontSize: 14,
        color: _ocgBronzePdf,
      );

  static pw.TextStyle get _sectionTitleStyle => pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: _ocgEspressoPdf,
      );

  static pw.TextStyle get _labelStyle => pw.TextStyle(
        fontSize: 10,
        color: PdfColors.grey700,
      );

  static pw.TextStyle get _smallBoldStyle => pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _ocgEspressoPdf,
      );

  static pw.TextStyle get _bodyTextStyle => pw.TextStyle(
        fontSize: 10,
        color: PdfColors.grey800,
      );

  // OCG Colors
  static const PdfColor _ocgBronzePdf = PdfColor.fromInt(0xFF8B5E25);
  static const PdfColor _ocgEspressoPdf = PdfColor.fromInt(0xFF5C5550);
}
