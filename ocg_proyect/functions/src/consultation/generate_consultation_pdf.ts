import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import PDFDocument from 'pdfkit';
import type {Response as ExpressResponse} from 'express';
import {HttpsError, Request, onRequest} from 'firebase-functions/v2/https';

type GenerateConsultationPdfData = {
  patientId?: string;
  consultationId?: string;
  treatmentId?: string;
  shareWithPatient?: boolean;
};

type CallerAuthorization = {
  uid: string;
  role: 'admin' | 'patient';
  token: admin.auth.DecodedIdToken;
};

type DocData = admin.firestore.DocumentData;

type ClinicalFileSummary = {
  displayName: string;
  originalName: string;
  active: boolean;
  visibleToPatient: boolean;
};

type PdfContext = {
  patient: DocData;
  consultation: DocData;
  treatment: DocData | null;
  clinicalFiles: ClinicalFileSummary[];
  signatureBytes: Buffer | null;
  dictamenCode: string;
  appointmentDate: Date;
  dictamenDate: Date;
  generatedAt: Date;
};

const TIME_ZONE = 'America/Bogota';
const MARGIN = 42;
const PAGE_WIDTH = 595.28;
const CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2;
const MAX_SIGNATURE_BYTES = 5 * 1024 * 1024;

const COLORS = {
  espresso: '#3D2B1F',
  bronze: '#8B5E25',
  ink: '#5C5550',
  muted: '#77706A',
  border: '#D8CEC3',
  soft: '#F8F5F0',
  white: '#FFFFFF',
};

const STAGE_NAMES: Record<string, string> = {
  valoracionInicial: 'Valoracion inicial',
  estudioPlaneacion: 'Estudio y planeacion',
  instalacion: 'Instalacion',
  controles: 'Controles',
  retencion: 'Retencion',
  alta: 'Alta',
  diagnostico: 'Valoracion inicial',
  planificacion: 'Estudio y planeacion',
  seguimientoActivo: 'Controles',
  ajusteFinal: 'Controles',
};

export const generateConsultationPdf = onRequest(
  {region: 'us-central1', timeoutSeconds: 120},
  async (request, response) => {
    setCorsHeaders(request, response);
    if (request.method === 'OPTIONS') {
      response.status(204).send('');
      return;
    }
    if (request.method !== 'POST') {
      response.status(405).json({
        ok: false,
        code: 'method-not-allowed',
        message: 'Usa POST para generar el dictamen.',
      });
      return;
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    try {
      const data = requestBodyData(request);
      const patientId = normalizeString(data.patientId);
      const consultationId = normalizeString(data.consultationId);
      const requestedTreatmentId = normalizeString(data.treatmentId);
      const shareWithPatient = data.shareWithPatient === true;

      if (!patientId || !consultationId) {
        throw new HttpsError(
          'invalid-argument',
          'Debes enviar patientId y consultationId validos.',
        );
      }

      const authorization = await authorizePatientAccess(db, request, patientId);
      if (shareWithPatient && authorization.role !== 'admin') {
        throw new HttpsError(
          'permission-denied',
          'Solo un administrador puede compartir el dictamen con el paciente.',
        );
      }
      const patientRef = db.collection('patients').doc(patientId);
      const consultationRef = patientRef
        .collection('consultations')
        .doc(consultationId);
      const [patientSnap, consultationSnap] = await Promise.all([
        patientRef.get(),
        consultationRef.get(),
      ]);

      if (!patientSnap.exists) {
        throw new HttpsError('not-found', 'No se encontro el paciente.');
      }
      if (!consultationSnap.exists) {
        throw new HttpsError('not-found', 'No se encontro el dictamen.');
      }

      const patient = patientSnap.data() ?? {};
      const consultation = consultationSnap.data() ?? {};
      const treatmentId =
        requestedTreatmentId || normalizeString(consultation['treatmentId']);
      const treatment = await loadTreatment(patientRef, treatmentId);
      const dictamenDate = toDate(consultation['date'], new Date());
      const appointmentDate =
        (await loadAppointmentDate(db, consultation)) ?? dictamenDate;
      const dictamenCode = dictamenIdCode(consultationId);
      const signatureUrl = normalizeString(consultation['signatureUrl']);
      const signatureBytes = signatureUrl
        ? await downloadSignatureBytes(signatureUrl)
        : null;
      const clinicalFiles = await loadClinicalFiles({
        patientRef,
        consultation,
        consultationId,
        role: authorization.role,
      });

      const pdfBytes = await buildConsultationPdf({
        patient,
        consultation: {...consultation, id: consultationId},
        treatment,
        clinicalFiles,
        signatureBytes,
        dictamenCode,
        appointmentDate,
        dictamenDate,
        generatedAt: new Date(),
      });

      const fileName = dictamenPdfFileName(patient, consultation, consultationId);
      const storagePath = `patients/${patientId}/dictamenes/${consultationId}/${fileName}`;
      const token = crypto.randomUUID();
      const file = bucket.file(storagePath);

      await file.save(pdfBytes, {
        resumable: false,
        metadata: {
          contentType: 'application/pdf',
          contentDisposition: contentDispositionFor(fileName),
          cacheControl: 'private, max-age=0, no-transform',
          metadata: {
            firebaseStorageDownloadTokens: token,
            generatedBy: 'generateConsultationPdf',
            consultationId,
          },
        },
      });

      const downloadUrl =
        `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket.name)}` +
        `/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
      const clinicalFileId = `dictamen_pdf_${consultationId}`;
      const visibleToPatient = await saveDictamenClinicalFile({
        patientRef,
        clinicalFileId,
        patientId,
        treatmentId,
        treatment,
        consultation,
        consultationId,
        authorization,
        fileName,
        storagePath,
        downloadUrl,
        sizeBytes: pdfBytes.length,
        shareWithPatient,
      });

      await consultationRef.set(
        {
          reportPdfFileId: storagePath,
          reportPdfUrl: downloadUrl,
          reportPdfClinicalFileId: clinicalFileId,
          reportPdfVisibleToPatient: visibleToPatient,
          reportPdfGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      response.status(200).json({
        ok: true,
        fileName,
        downloadUrl,
        storagePath,
        clinicalFileId,
        visibleToPatient,
        sizeBytes: pdfBytes.length,
      });
    } catch (error) {
      sendErrorResponse(response, error);
    }
  },
);

async function authorizePatientAccess(
  db: admin.firestore.Firestore,
  request: Request,
  patientId: string,
): Promise<CallerAuthorization> {
  const token = await verifyBearerToken(request);
  const uid = token.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }

  if (token.role === 'admin' || token.admin === true) {
    return {uid, role: 'admin', token};
  }

  const adminDoc = await db.collection('admins').doc(uid).get();
  if (adminDoc.exists && adminDoc.data()?.['role'] !== 'patient') {
    return {uid, role: 'admin', token};
  }

  if (uid === patientId) {
    return {uid, role: 'patient', token};
  }

  throw new HttpsError(
    'permission-denied',
    'No tienes permisos para generar este dictamen.',
  );
}

async function loadTreatment(
  patientRef: admin.firestore.DocumentReference<DocData>,
  treatmentId: string,
): Promise<DocData | null> {
  if (!treatmentId || treatmentId.startsWith('legacy-')) return null;
  const snap = await patientRef.collection('treatments').doc(treatmentId).get();
  return snap.exists ? snap.data() ?? null : null;
}

async function loadAppointmentDate(
  db: admin.firestore.Firestore,
  consultation: DocData,
): Promise<Date | null> {
  const storedDate = toOptionalDate(consultation['appointmentDate']);
  if (storedDate) return storedDate;

  const appointmentId = normalizeString(consultation['appointmentId']);
  if (!appointmentId || appointmentId.startsWith('dictamen-')) return null;

  const snap = await db.collection('appointments').doc(appointmentId).get();
  if (!snap.exists) return null;
  return toOptionalDate(snap.data()?.['fechaHora']);
}

async function loadClinicalFiles(params: {
  patientRef: admin.firestore.DocumentReference<DocData>;
  consultation: DocData;
  consultationId: string;
  role: 'admin' | 'patient';
}): Promise<ClinicalFileSummary[]> {
  const snapshot = await params.patientRef
    .collection('clinicalFiles')
    .where('consultationId', '==', params.consultationId)
    .get();

  let files = snapshot.docs.map((doc) => clinicalFileFromData(doc.data()));
  const ids = Array.isArray(params.consultation['clinicalFileIds'])
    ? params.consultation['clinicalFileIds']
        .map((value: unknown) => normalizeString(value))
        .filter((value: string) => value.length > 0)
    : [];

  if (files.length === 0 && ids.length > 0) {
    const docs = await Promise.all(
      ids.map((id: string) => params.patientRef.collection('clinicalFiles').doc(id).get()),
    );
    files = docs
      .filter((doc) => doc.exists)
      .map((doc) => clinicalFileFromData(doc.data() ?? {}));
  }

  return files.filter((file) => {
    if (!file.active) return false;
    if (params.role === 'patient' && !file.visibleToPatient) return false;
    return true;
  });
}

async function saveDictamenClinicalFile(params: {
  patientRef: admin.firestore.DocumentReference<DocData>;
  clinicalFileId: string;
  patientId: string;
  treatmentId: string;
  treatment: DocData | null;
  consultation: DocData;
  consultationId: string;
  authorization: CallerAuthorization;
  fileName: string;
  storagePath: string;
  downloadUrl: string;
  sizeBytes: number;
  shareWithPatient: boolean;
}): Promise<boolean> {
  const fileRef = params.patientRef
    .collection('clinicalFiles')
    .doc(params.clinicalFileId);
  const existing = await fileRef.get();
  const wasVisible = existing.data()?.['visibleToPatient'] === true;
  const visibleToPatient = params.shareWithPatient || wasVisible;
  const treatmentName =
    normalizeString(params.consultation['treatmentNameSnapshot']) ||
    treatmentDisplayName(params.treatment);
  const stageId = normalizeString(params.consultation['stageId']);
  const stageName =
    normalizeString(params.consultation['stageNameSnapshot']) ||
    stageLabel(stageId);
  const uploadedAt =
    existing.exists && existing.data()?.['uploadedAt']
      ? existing.data()?.['uploadedAt']
      : admin.firestore.FieldValue.serverTimestamp();

  await fileRef.set(
    {
      id: params.clinicalFileId,
      patientId: params.patientId,
      treatmentId: params.treatmentId || null,
      consultationId: params.consultationId,
      sourceType: 'consultation_pdf',
      sourceId: params.consultationId,
      treatmentNameSnapshot: treatmentName || null,
      stageId: stageId || null,
      stageNameSnapshot: stageName || null,
      originalName: params.fileName,
      displayName: params.fileName,
      storagePath: params.storagePath,
      downloadUrl: params.downloadUrl,
      mimeType: 'application/pdf',
      extension: 'pdf',
      sizeBytes: params.sizeBytes,
      category: 'dictamen_pdf',
      notes: 'Dictamen clinico generado desde el historial.',
      uploadedBy: params.authorization.uid,
      uploadedAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      active: true,
      visibleToPatient,
    },
    {merge: true},
  );

  return visibleToPatient;
}

function clinicalFileFromData(data: DocData): ClinicalFileSummary {
  return {
    displayName: normalizeString(data['displayName']),
    originalName: normalizeString(data['originalName']),
    active: data['active'] !== false,
    visibleToPatient: data['visibleToPatient'] === true,
  };
}

async function downloadSignatureBytes(url: string): Promise<Buffer> {
  let response: Response;
  try {
    response = await fetch(url);
  } catch (error) {
    console.error('[generateConsultationPdf] signature fetch failed', error);
    throw new HttpsError(
      'failed-precondition',
      'No se pudo cargar la firma capturada para el PDF.',
    );
  }

  if (!response.ok) {
    throw new HttpsError(
      'failed-precondition',
      'No se pudo cargar la firma capturada para el PDF.',
    );
  }

  const contentType = response.headers.get('content-type') ?? '';
  if (contentType && !contentType.toLowerCase().startsWith('image/')) {
    throw new HttpsError(
      'failed-precondition',
      'La firma capturada no es una imagen valida.',
    );
  }

  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length === 0 || bytes.length > MAX_SIGNATURE_BYTES) {
    throw new HttpsError(
      'failed-precondition',
      'La firma capturada no se pudo procesar para el PDF.',
    );
  }
  return bytes;
}

function buildConsultationPdf(ctx: PdfContext): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    const doc = new PDFDocument({
      size: 'A4',
      margin: MARGIN,
      info: {
        Title: 'Dictamen clinico',
        Author: 'Oral Care Global Bionics',
      },
    });

    doc.on('data', (chunk: Buffer) => chunks.push(Buffer.from(chunk)));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    try {
      renderPdf(doc, ctx);
      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}

function renderPdf(doc: PDFKit.PDFDocument, ctx: PdfContext): void {
  renderHeader(doc, ctx);
  addVerticalSpace(doc, 18);
  renderPatientSection(doc, ctx);
  renderTreatmentSection(doc, ctx);
  renderClinicalSummary(doc, ctx);
  if (ctx.signatureBytes) {
    renderSignature(doc, ctx);
  }
  if (ctx.clinicalFiles.length > 0) {
    renderAttachments(doc, ctx.clinicalFiles);
  }
  renderDocumentFooter(doc, ctx);
}

function renderHeader(doc: PDFKit.PDFDocument, ctx: PdfContext): void {
  const startY = doc.y;
  doc
    .roundedRect(MARGIN, startY, 56, 56, 10)
    .lineWidth(1.5)
    .strokeColor(COLORS.bronze)
    .stroke();

  doc
    .font('Helvetica-Bold')
    .fontSize(16)
    .fillColor(COLORS.bronze)
    .text('OCG', MARGIN, startY + 20, {width: 56, align: 'center'});

  doc
    .font('Helvetica-Bold')
    .fontSize(18)
    .fillColor(COLORS.espresso)
    .text('ORAL CARE GLOBAL BIONICS', MARGIN + 72, startY + 8, {
      width: 290,
    });
  doc
    .font('Helvetica')
    .fontSize(14)
    .fillColor(COLORS.bronze)
    .text('Dictamen Clinico', MARGIN + 72, startY + 33, {width: 260});

  doc
    .font('Helvetica')
    .fontSize(8)
    .fillColor(COLORS.muted)
    .text('Fecha de generacion', MARGIN + 365, startY + 4, {
      width: 146,
      align: 'right',
    });
  doc
    .font('Helvetica-Bold')
    .fontSize(10)
    .fillColor(COLORS.espresso)
    .text(formatDateTime(ctx.generatedAt), MARGIN + 365, startY + 16, {
      width: 146,
      align: 'right',
    });
  doc
    .font('Helvetica')
    .fontSize(8)
    .fillColor(COLORS.muted)
    .text('Codigo dictamen', MARGIN + 365, startY + 34, {
      width: 146,
      align: 'right',
    });
  doc
    .font('Helvetica-Bold')
    .fontSize(10)
    .fillColor(COLORS.espresso)
    .text(ctx.dictamenCode, MARGIN + 365, startY + 46, {
      width: 146,
      align: 'right',
    });

  doc.y = startY + 72;
  doc
    .moveTo(MARGIN, doc.y)
    .lineTo(MARGIN + CONTENT_WIDTH, doc.y)
    .lineWidth(2)
    .strokeColor(COLORS.bronze)
    .stroke();
}

function renderPatientSection(doc: PDFKit.PDFDocument, ctx: PdfContext): void {
  const rows: Array<[string, string]> = [
    ['Nombre', displayPatientName(ctx.patient, ctx.consultation)],
  ];
  const email = normalizeString(ctx.patient['email']);
  const phone = normalizeString(ctx.patient['telefono']);
  if (email) rows.push(['Email', email]);
  if (phone) rows.push(['Telefono', phone]);
  rows.push(['Fecha de la cita', formatDate(ctx.appointmentDate)]);
  rows.push(['Fecha del dictamen', formatDate(ctx.dictamenDate)]);
  renderRowsSection(doc, 'Datos del paciente', rows);
}

function renderTreatmentSection(doc: PDFKit.PDFDocument, ctx: PdfContext): void {
  const treatment = ctx.treatment;
  const treatmentName =
    normalizeString(ctx.consultation['treatmentNameSnapshot']) ||
    treatmentDisplayName(treatment) ||
    'Sin tratamiento';
  const status =
    normalizeString(treatment?.['status']) ||
    normalizeString(treatment?.['estado']) ||
    'N/A';
  const phaseSnapshot = (ctx.consultation['phaseSnapshot'] ?? {}) as DocData;
  const previousStage = stageLabel(normalizeString(phaseSnapshot['previousStage']));
  const currentStage =
    normalizeString(ctx.consultation['stageNameSnapshot']) ||
    stageLabel(normalizeString(ctx.consultation['stageId'])) ||
    'N/A';
  const isPrimary = treatment?.['isPrimary'] === true;

  renderRowsSection(doc, 'Datos del tratamiento', [
    ['Tratamiento', treatmentName],
    ['Estado', status],
    ['Etapa antes', previousStage || 'N/A'],
    ['Etapa despues', currentStage],
    ['Tipo', isPrimary ? 'Tratamiento principal' : 'Tratamiento secundario'],
  ]);
}

function renderClinicalSummary(doc: PDFKit.PDFDocument, ctx: PdfContext): void {
  renderSectionTitle(doc, 'Resumen clinico');
  const notes = normalizeString(ctx.consultation['clinicalNotes']);
  if (notes) {
    renderTextBox(doc, notes);
  }
  addRow(doc, 'Doctor(a)', normalizeString(ctx.consultation['doctorName']) || 'N/A');
  addVerticalSpace(doc, 12);
}

function renderSignature(doc: PDFKit.PDFDocument, ctx: PdfContext): void {
  renderSectionTitle(doc, 'Firma del paciente');
  const boxHeight = 112;
  ensureSpace(doc, boxHeight + 70);
  const boxY = doc.y;

  doc
    .roundedRect(MARGIN, boxY, CONTENT_WIDTH, boxHeight, 8)
    .lineWidth(1)
    .strokeColor('#AAAAAA')
    .fillColor(COLORS.white)
    .fillAndStroke(COLORS.white, '#AAAAAA');

  try {
    doc.image(ctx.signatureBytes!, MARGIN + 10, boxY + 10, {
      fit: [CONTENT_WIDTH - 20, boxHeight - 20],
      align: 'center',
      valign: 'center',
    });
  } catch (error) {
    console.error('[generateConsultationPdf] signature embed failed', error);
    throw new HttpsError(
      'failed-precondition',
      'No se pudo insertar la firma capturada en el PDF.',
    );
  }

  const signatureDate =
    toOptionalDate(ctx.consultation['signatureCapturedAt']) ?? ctx.dictamenDate;
  doc.y = boxY + boxHeight + 4;
  doc
    .font('Helvetica')
    .fontSize(8)
    .fillColor(COLORS.muted)
    .text(`Firma capturada el ${formatDateTime(signatureDate)}`, MARGIN, doc.y, {
      width: CONTENT_WIDTH,
    });
  addVerticalSpace(doc, 6);
  doc
    .font('Helvetica-Oblique')
    .fontSize(9)
    .fillColor(COLORS.muted)
    .text(
      'El paciente firma como constancia de haber recibido la informacion clinica descrita en este dictamen. Este documento no sustituye el consentimiento informado cuando aplique.',
      MARGIN,
      doc.y,
      {width: CONTENT_WIDTH},
    );
  addVerticalSpace(doc, 14);
}

function renderAttachments(
  doc: PDFKit.PDFDocument,
  files: ClinicalFileSummary[],
): void {
  renderSectionTitle(doc, 'Documentos adjuntos al dictamen');
  ensureSpace(doc, 26);

  const headerY = doc.y;
  doc
    .rect(MARGIN, headerY, CONTENT_WIDTH, 22)
    .fillAndStroke('#EFEAE3', COLORS.border);
  doc
    .font('Helvetica-Bold')
    .fontSize(9)
    .fillColor(COLORS.espresso)
    .text('Archivo', MARGIN + 8, headerY + 7, {width: CONTENT_WIDTH - 16});
  doc.y = headerY + 22;

  for (const file of files) {
    const name = file.displayName || file.originalName || 'Archivo';
    const rowHeight = Math.max(
      22,
      doc.heightOfString(name, {width: CONTENT_WIDTH - 16}) + 10,
    );
    ensureSpace(doc, rowHeight);
    const y = doc.y;
    doc.rect(MARGIN, y, CONTENT_WIDTH, rowHeight).strokeColor(COLORS.border).stroke();
    doc
      .font('Helvetica')
      .fontSize(9)
      .fillColor(COLORS.ink)
      .text(name, MARGIN + 8, y + 6, {width: CONTENT_WIDTH - 16});
    doc.y = y + rowHeight;
  }
  addVerticalSpace(doc, 14);
}

function renderDocumentFooter(doc: PDFKit.PDFDocument, ctx: PdfContext): void {
  ensureSpace(doc, 44);
  doc
    .moveTo(MARGIN, doc.y)
    .lineTo(MARGIN + CONTENT_WIDTH, doc.y)
    .lineWidth(1.5)
    .strokeColor(COLORS.bronze)
    .stroke();
  addVerticalSpace(doc, 6);
  const patientName = displayPatientName(ctx.patient, ctx.consultation);
  doc
    .font('Helvetica')
    .fontSize(8)
    .fillColor(COLORS.muted)
    .text(
      `Paciente: ${patientName} | Dia de la cita: ${formatDate(ctx.appointmentDate)} | Dia del dictamen: ${formatDate(ctx.dictamenDate)}`,
      MARGIN,
      doc.y,
      {width: CONTENT_WIDTH},
    );
}

function renderRowsSection(
  doc: PDFKit.PDFDocument,
  title: string,
  rows: Array<[string, string]>,
): void {
  renderSectionTitle(doc, title);
  for (const [label, value] of rows) {
    addRow(doc, label, value);
  }
  addVerticalSpace(doc, 12);
}

function renderSectionTitle(doc: PDFKit.PDFDocument, title: string): void {
  ensureSpace(doc, 36);
  doc
    .font('Helvetica-Bold')
    .fontSize(14)
    .fillColor(COLORS.espresso)
    .text(title, MARGIN, doc.y, {width: CONTENT_WIDTH});
  addVerticalSpace(doc, 8);
}

function renderTextBox(doc: PDFKit.PDFDocument, text: string): void {
  const height = doc.heightOfString(text, {width: CONTENT_WIDTH - 20}) + 20;
  ensureSpace(doc, height + 6);
  const y = doc.y;
  doc
    .roundedRect(MARGIN, y, CONTENT_WIDTH, height, 6)
    .fillAndStroke(COLORS.soft, COLORS.border);
  doc
    .font('Helvetica')
    .fontSize(10)
    .fillColor(COLORS.ink)
    .text(text, MARGIN + 10, y + 10, {width: CONTENT_WIDTH - 20});
  doc.y = y + height + 8;
}

function addRow(doc: PDFKit.PDFDocument, label: string, value: string): void {
  const labelWidth = 125;
  const valueWidth = CONTENT_WIDTH - labelWidth;
  const cleanValue = value || 'N/A';
  const valueHeight = doc.heightOfString(cleanValue, {width: valueWidth});
  const rowHeight = Math.max(16, valueHeight + 3);
  ensureSpace(doc, rowHeight);
  const y = doc.y;

  doc
    .font('Helvetica-Bold')
    .fontSize(10)
    .fillColor(COLORS.muted)
    .text(`${label}:`, MARGIN, y, {width: labelWidth});
  doc
    .font('Helvetica')
    .fontSize(10)
    .fillColor(COLORS.ink)
    .text(cleanValue, MARGIN + labelWidth, y, {width: valueWidth});
  doc.y = y + rowHeight;
}

function ensureSpace(doc: PDFKit.PDFDocument, requiredHeight: number): void {
  const bottom = doc.page.height - MARGIN;
  if (doc.y + requiredHeight > bottom) {
    doc.addPage();
  }
}

function addVerticalSpace(doc: PDFKit.PDFDocument, height: number): void {
  doc.y += height;
}

function setCorsHeaders(request: Request, response: ExpressResponse): void {
  const origin = normalizeHeader(request.headers.origin);
  response.set('Access-Control-Allow-Origin', origin || '*');
  response.set('Vary', 'Origin');
  response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.set(
    'Access-Control-Allow-Headers',
    'Authorization, Content-Type, X-Requested-With',
  );
  response.set('Access-Control-Max-Age', '3600');
}

function requestBodyData(request: Request): GenerateConsultationPdfData {
  const body = request.body as unknown;
  if (body && typeof body === 'object') {
    const data = (body as {data?: unknown}).data;
    if (data && typeof data === 'object') {
      return data as GenerateConsultationPdfData;
    }
    return body as GenerateConsultationPdfData;
  }
  return {};
}

async function verifyBearerToken(
  request: Request,
): Promise<admin.auth.DecodedIdToken> {
  const authorization = normalizeHeader(request.headers.authorization);
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion.');
  }

  try {
    return await admin.auth().verifyIdToken(match[1]);
  } catch (error) {
    console.error('[generateConsultationPdf] invalid auth token', error);
    throw new HttpsError('unauthenticated', 'La sesion no es valida.');
  }
}

function normalizeHeader(value: string | string[] | undefined): string {
  if (Array.isArray(value)) return value[0]?.trim() ?? '';
  return value?.trim() ?? '';
}

function sendErrorResponse(response: ExpressResponse, error: unknown): void {
  if (error instanceof HttpsError) {
    response.status(httpStatusForHttpsError(error.code)).json({
      ok: false,
      code: error.code,
      message: error.message,
    });
    return;
  }

  console.error('[generateConsultationPdf] internal error', error);
  response.status(500).json({
    ok: false,
    code: 'internal',
    message: 'Error interno generando el PDF.',
  });
}

function httpStatusForHttpsError(code: string): number {
  switch (code) {
    case 'invalid-argument':
      return 400;
    case 'unauthenticated':
      return 401;
    case 'permission-denied':
      return 403;
    case 'not-found':
      return 404;
    case 'failed-precondition':
      return 412;
    case 'resource-exhausted':
      return 429;
    default:
      return 500;
  }
}

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : String(value ?? '').trim();
}

function displayPatientName(patient: DocData, consultation: DocData): string {
  return (
    normalizeString(patient['nombre']) ||
    normalizeString(patient['displayName']) ||
    normalizeString(patient['fullName']) ||
    normalizeString(patient['name']) ||
    normalizeString(consultation['patientName']) ||
    'Paciente'
  );
}

function treatmentDisplayName(treatment: DocData | null): string {
  if (!treatment) return '';
  const name =
    normalizeString(treatment['name']) ||
    normalizeString(treatment['nombre']) ||
    normalizeString(treatment['visibleName']) ||
    normalizeString(treatment['clinicalTreatmentName']) ||
    normalizeString(treatment['baseType']) ||
    normalizeString(treatment['tipoBase']);
  const subtype =
    normalizeString(treatment['subtype']) || normalizeString(treatment['subtipo']);
  if (!name) return '';
  if (!subtype) return titleize(name);
  return `${titleize(name)} - ${titleize(subtype)}`;
}

function stageLabel(raw: string): string {
  if (!raw) return '';
  return STAGE_NAMES[raw] ?? titleize(raw.replace(/_/g, ' '));
}

function titleize(value: string): string {
  return value
    .trim()
    .split(/\s+/)
    .filter((part) => part.length > 0)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
}

function dictamenIdCode(consultationId: string): string {
  const clean = consultationId.trim();
  if (!clean) return 'SIN-CODIGO';
  return clean.length > 8 ? clean.substring(0, 8) : clean;
}

function dictamenPdfFileName(
  patient: DocData,
  consultation: DocData,
  consultationId: string,
): string {
  const patientName = sanitizeFileNameToken(displayPatientName(patient, consultation));
  return `DIC-${patientName}-${dictamenIdCode(consultationId)}.pdf`;
}

function sanitizeFileNameToken(value: string): string {
  const clean = value
    .trim()
    .replace(/[\\/:*?"<>|\r\n\t]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return (clean || 'PACIENTE').toUpperCase();
}

function contentDispositionFor(fileName: string): string {
  const asciiFallback = fileName.replace(/[^\x20-\x7E]+/g, '_').replace(/"/g, '');
  return `attachment; filename="${asciiFallback}"; filename*=UTF-8''${encodeRFC5987ValueChars(fileName)}`;
}

function encodeRFC5987ValueChars(value: string): string {
  return encodeURIComponent(value)
    .replace(/['()]/g, escape)
    .replace(/\*/g, '%2A')
    .replace(/%(7C|60|5E)/g, (_match, hex) => `%${hex.toLowerCase()}`);
}

function toDate(value: unknown, fallback: Date): Date {
  return toOptionalDate(value) ?? fallback;
}

function toOptionalDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  const maybeTimestamp = value as {toDate?: () => Date};
  if (typeof maybeTimestamp.toDate === 'function') {
    return maybeTimestamp.toDate();
  }
  return null;
}

function formatDate(value: Date): string {
  return formatDateParts(value, false);
}

function formatDateTime(value: Date): string {
  return formatDateParts(value, true);
}

function formatDateParts(value: Date, includeTime: boolean): string {
  const formatter = new Intl.DateTimeFormat('es-CO', {
    timeZone: TIME_ZONE,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: includeTime ? '2-digit' : undefined,
    minute: includeTime ? '2-digit' : undefined,
    hour12: false,
  });
  const parts = formatter.formatToParts(value);
  const byType = new Map(parts.map((part) => [part.type, part.value]));
  const date = `${byType.get('day')}/${byType.get('month')}/${byType.get('year')}`;
  if (!includeTime) return date;
  return `${date} ${byType.get('hour')}:${byType.get('minute')}`;
}
