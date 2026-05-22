/**
 * Builds a treatment-specific prompt for gpt-image-2 images.edit().
 *
 * The prompt is assembled in layers:
 * 1. Identity preservation (shared base)
 * 2. Treatment-specific positive instructions
 * 3. Doctor parameters converted to natural language
 * 4. Treatment-specific negative instructions
 * 5. Clinical disclaimer
 * 6. Doctor notes (complement only, never overrides profile)
 */

import {resolveTreatmentProfile} from './treatment_profiles';
import type {TreatmentPromptProfile} from './treatment_profiles';

// ── Types ───────────────────────────────────────────────

export type BuildDentalTreatmentPromptInput = {
  treatmentProfileId?: string;
  legacyTreatmentType?: string;
  visualGoal?: string;
  doctorConfig?: Record<string, unknown>;
  notes?: string;
};

export type BuildDentalTreatmentPromptResult = {
  promptUsed: string;
  promptVersion: string;
  treatmentProfileId: string;
};

// ── Constants ───────────────────────────────────────────

const PROMPT_VERSION = 'ocg-dental-treatment-v2';

const CLINICAL_DISCLAIMER = [
  'The result is a visual simulation for educational purposes only.',
  'It does not represent a guaranteed clinical outcome.',
  'Actual results depend on diagnosis, biomechanics, treatment time, biological response, and the clinical plan.',
].join(' ');

// ── Identity base ───────────────────────────────────────

const IDENTITY_BASE = [
  'Edit ONLY the visible dental area of the patient.',
  'Preserve the face, lips, skin, facial expression, lighting, framing, age appearance, and identity exactly as they are.',
  'Do not change the shape of the face.',
  'Do not alter eyes, nose, hair, skin, or background.',
  'Do not produce an artificial or cartoonish result.',
  'Keep the image looking like a real clinical photograph.',
].join(' ');

// ── Helpers ─────────────────────────────────────────────

function normalizeText(value?: string): string {
  return (value ?? '').replace(/\s+/g, ' ').trim();
}

function doctorConfigToInstructions(
  config: Record<string, unknown> | undefined,
): string[] {
  if (!config || Object.keys(config).length === 0) return [];

  const instructions: string[] = [];
  const c = config;

  // Ligature color
  const ligColor = normalizeText(c['ligatureColor'] as string | undefined);
  if (ligColor) {
    instructions.push(`Ligature color: ${ligColor}.`);
  }

  // Material (for esthetic braces, veneers)
  const material = normalizeText(c['material'] as string | undefined);
  if (material) {
    const materialLabel = material === 'zafiro' ? 'sapphire' : material;
    instructions.push(`Material: ${materialLabel}.`);
  }

  // Archwire type
  const archwire = normalizeText(c['archwire'] as string | undefined);
  if (archwire) {
    instructions.push(`Archwire appearance: ${archwire}.`);
  }

  // Arcada (upper/lower/both)
  const arcada = normalizeText(c['arcada'] as string | undefined);
  if (arcada) {
    instructions.push(`Target arch: ${arcada}.`);
  }

  // Aligner-specific
  const attachments = normalizeText(c['attachments'] as string | undefined);
  if (attachments) {
    instructions.push(`Aligner attachments: ${attachments}.`);
  }

  const transparency = normalizeText(c['transparency'] as string | undefined);
  if (transparency) {
    instructions.push(`Aligner transparency level: ${transparency}.`);
  }

  // Whitening-specific
  const toneTarget = normalizeText(c['toneTarget'] as string | undefined);
  if (toneTarget) {
    instructions.push(`Whitening intensity: ${toneTarget}.`);
  }

  const naturalness = normalizeText(
    c['naturalness'] as string | undefined,
  );
  if (naturalness) {
    instructions.push(`Naturalness level: ${naturalness}.`);
  }

  // Veneer-specific
  const forma = normalizeText(c['forma'] as string | undefined);
  if (forma) {
    instructions.push(`Tooth shape style: ${forma}.`);
  }

  const tono = normalizeText(c['tono'] as string | undefined);
  if (tono) {
    instructions.push(`Target tooth shade: ${tono}.`);
  }

  const longitudIncisal = normalizeText(
    c['longitudIncisal'] as string | undefined,
  );
  if (longitudIncisal) {
    instructions.push(`Incisal edge length: ${longitudIncisal}.`);
  }

  const simetria = normalizeText(c['simetria'] as string | undefined);
  if (simetria) {
    instructions.push(`Symmetry level: ${simetria}.`);
  }

  // Smile design-specific
  const estilo = normalizeText(c['estilo'] as string | undefined);
  if (estilo) {
    instructions.push(`Smile style: ${estilo}.`);
  }

  const alineacionFinal = normalizeText(
    c['alineacionFinal'] as string | undefined,
  );
  if (alineacionFinal) {
    instructions.push(`Final alignment: ${alineacionFinal}.`);
  }

  const bordeIncisal = normalizeText(
    c['bordeIncisal'] as string | undefined,
  );
  if (bordeIncisal) {
    instructions.push(`Incisal edge harmony: ${bordeIncisal}.`);
  }

  // Palatal expander-specific
  const tipoVisual = normalizeText(c['tipoVisual'] as string | undefined);
  if (tipoVisual) {
    instructions.push(`Expander type: ${tipoVisual}.`);
  }

  // Retainer-specific
  const tipo = normalizeText(c['tipo'] as string | undefined);
  if (tipo) {
    instructions.push(`Retainer type: ${tipo}.`);
  }

  const visibilidad = normalizeText(c['visibilidad'] as string | undefined);
  if (visibilidad) {
    instructions.push(`Retainer visibility: ${visibilidad}.`);
  }

  return instructions;
}

// ── Main builder ────────────────────────────────────────

export function buildDentalTreatmentPrompt(
  input: BuildDentalTreatmentPromptInput,
): BuildDentalTreatmentPromptResult {
  const profile: TreatmentPromptProfile = resolveTreatmentProfile(
    input.treatmentProfileId,
    input.legacyTreatmentType,
  );

  const sections: string[] = [];

  // Layer 1: Identity preservation
  sections.push(IDENTITY_BASE);

  // Layer 2: Treatment-specific positive instructions
  if (profile.positiveInstructions.length > 0) {
    sections.push(...profile.positiveInstructions);
  }

  // Layer 3: Doctor parameter instructions
  const configInstructions = doctorConfigToInstructions(input.doctorConfig);
  if (configInstructions.length > 0) {
    sections.push(
      'Doctor-specified configuration parameters:',
      ...configInstructions,
    );
  }

  // Layer 4: Treatment-specific negative instructions
  if (profile.negativeInstructions.length > 0) {
    sections.push(...profile.negativeInstructions);
  }

  // Layer 5: Clinical disclaimer
  sections.push(CLINICAL_DISCLAIMER);

  // Layer 6: Doctor notes (complement, last)
  const notes = normalizeText(input.notes);
  if (notes) {
    sections.push(
      `Additional clinical notes from the doctor: ${notes}.`,
    );
  }

  return {
    promptUsed: sections.join(' '),
    promptVersion: PROMPT_VERSION,
    treatmentProfileId: profile.id,
  };
}
