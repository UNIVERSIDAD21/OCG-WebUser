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
  /** Free-text clinical instructions from the doctor — high priority. */
  doctorOverride?: string;
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

  // Ligature color — instrucción imperativa con referencia visual
  const ligColor = normalizeText(c['ligatureColor'] as string | undefined);
  if (ligColor) {
    instructions.push(
      `The elastic ligatures (o-rings) around each bracket MUST be visibly ${ligColor}-colored. ` +
        `Make the color clearly noticeable in the photo.`,
    );
  }

  // Material (for esthetic braces, veneers)
  const material = normalizeText(c['material'] as string | undefined);
  if (material) {
    const materialLabel = material === 'zafiro' ? 'sapphire-clear' : material;
    instructions.push(
      `The bracket material MUST look like ${materialLabel} — ` +
        `visibly different from standard metal.`,
    );
  }

  // Archwire type
  const archwire = normalizeText(c['archwire'] as string | undefined);
  if (archwire) {
    const wireDesc =
      archwire === 'estetico' ? 'tooth-colored or clear' : 'visible metal';
    instructions.push(
      `The archwire MUST appear as ${wireDesc}, not a standard silver wire.`,
    );
  }

  // Arcada (upper/lower/both)
  const arcada = normalizeText(c['arcada'] as string | undefined);
  if (arcada) {
    const archDesc =
      arcada === 'superior'
        ? 'upper teeth only'
        : arcada === 'inferior'
          ? 'lower teeth only'
          : 'both upper and lower teeth';
    instructions.push(
      `Apply the appliance to the ${archDesc}.`,
    );
  }

  // Aligner-specific
  const attachments = normalizeText(c['attachments'] as string | undefined);
  if (attachments) {
    const attachDesc =
      attachments === 'muchos'
        ? 'multiple visible composite attachments (buttons) on several teeth'
        : attachments === 'pocos'
          ? 'a few small composite attachments on select teeth'
          : 'no attachments';
    instructions.push(
      `The aligner MUST show ${attachDesc}.`,
    );
  }

  const transparency = normalizeText(c['transparency'] as string | undefined);
  if (transparency) {
    const transDesc =
      transparency === 'alto'
        ? 'very transparent — almost invisible plastic'
        : transparency === 'bajo'
          ? 'more opaque — clearly visible plastic tray'
          : 'moderately transparent with a subtle plastic sheen';
    instructions.push(
      `The aligner MUST look ${transDesc}.`,
    );
  }

  // Whitening-specific
  const toneTarget = normalizeText(c['toneTarget'] as string | undefined);
  if (toneTarget) {
    const toneDesc =
      toneTarget === 'alto'
        ? 'significantly whiter (4+ shades lighter)'
        : toneTarget === 'bajo'
          ? 'slightly lighter (1-2 shades)'
          : 'noticeably whiter (2-3 shades)';
    instructions.push(
      `The teeth MUST look ${toneDesc} compared to the original photo.`,
    );
  }

  const naturalness = normalizeText(
    c['naturalness'] as string | undefined,
  );
  if (naturalness) {
    const natDesc =
      naturalness === 'artificial'
        ? 'a bright, perfect white — even if slightly unnatural'
        : naturalness === 'conservador'
          ? 'a very subtle, conservative whitening'
          : 'a natural, believable white appropriate for the patient';
    instructions.push(
      `The whitening result MUST look ${natDesc}.`,
    );
  }

  // Veneer-specific
  const forma = normalizeText(c['forma'] as string | undefined);
  if (forma) {
    const formaDesc =
      forma === 'cuadrada'
        ? 'square, modern tooth shapes'
        : forma === 'redonda'
          ? 'rounded, softer tooth shapes'
          : forma === 'ojival'
            ? 'pointed, ovoid tooth shapes'
            : 'natural, balanced tooth shapes';
    instructions.push(
      `The tooth shapes MUST look ${formaDesc}.`,
    );
  }

  const tono = normalizeText(c['tono'] as string | undefined);
  if (tono) {
    instructions.push(
      `The overall tooth shade MUST be ${tono} — visibly different from the original.`,
    );
  }

  const longitudIncisal = normalizeText(
    c['longitudIncisal'] as string | undefined,
  );
  if (longitudIncisal) {
    const incisalDesc =
      longitudIncisal === 'largo'
        ? 'longer incisal edges — teeth should appear slightly elongated'
        : longitudIncisal === 'corto'
          ? 'shorter incisal edges — teeth should look slightly reduced in length'
          : 'the same incisal edge length as the original';
    instructions.push(
      `The incisal edges MUST look ${incisalDesc}.`,
    );
  }

  const simetria = normalizeText(c['simetria'] as string | undefined);
  if (simetria) {
    const simDesc =
      simetria === 'alta'
        ? 'highly symmetrical — both sides should mirror each other closely'
        : simetria === 'baja'
          ? 'only slightly symmetrical — keep natural asymmetry'
          : 'moderately symmetrical — balanced but not perfectly mirrored';
    instructions.push(
      `The smile MUST look ${simDesc}.`,
    );
  }

  // Smile design-specific
  const estilo = normalizeText(c['estilo'] as string | undefined);
  if (estilo) {
    const estiloDesc =
      estilo === 'juvenil'
        ? 'a youthful, vibrant smile with slightly rounded, bright teeth'
        : estilo === 'elegante'
          ? 'an elegant, refined smile with sophisticated proportions'
          : estilo === 'natural'
            ? 'a natural-looking smile that enhances without appearing done'
            : 'a harmonious, balanced smile';
    instructions.push(
      `The overall smile MUST look ${estiloDesc}.`,
    );
  }

  const alineacionFinal = normalizeText(
    c['alineacionFinal'] as string | undefined,
  );
  if (alineacionFinal) {
    const alineacionDesc =
      alineacionFinal === 'total'
        ? 'perfectly straight — every tooth aligned precisely'
        : alineacionFinal === 'parcial'
          ? 'improved alignment but with minor natural imperfections'
          : 'well-aligned with a natural, healthy look';
    instructions.push(
      `The teeth alignment MUST look ${alineacionDesc}.`,
    );
  }

  const bordeIncisal = normalizeText(
    c['bordeIncisal'] as string | undefined,
  );
  if (bordeIncisal) {
    const bordeDesc =
      bordeIncisal === 'recto'
        ? 'a straight, flat incisal edge line across the smile'
        : bordeIncisal === 'curvo'
          ? 'a curved, smile-following incisal edge line'
          : 'a naturally harmonized incisal edge that follows the lower lip';
    instructions.push(
      `The incisal edge line MUST look ${bordeDesc}.`,
    );
  }

  // Palatal expander-specific
  const tipoVisual = normalizeText(c['tipoVisual'] as string | undefined);
  if (tipoVisual) {
    instructions.push(
      `The expander MUST look like a ${tipoVisual} appliance — ` +
        `accurate to that specific design.`,
    );
  }

  // Retainer-specific
  const tipo = normalizeText(c['tipo'] as string | undefined);
  if (tipo) {
    const retDesc =
      tipo === 'Essix'
        ? 'a thin clear plastic tray (Essix retainer) over the teeth'
        : tipo === 'Hawley'
          ? 'a Hawley retainer with visible metal wire across the front and acrylic behind'
          : 'a fixed lingual wire bonded behind the teeth';
    instructions.push(
      `The retainer MUST look like ${retDesc}.`,
    );
  }

  const visibilidad = normalizeText(c['visibilidad'] as string | undefined);
  if (visibilidad) {
    const visDesc =
      visibilidad === 'alta'
        ? 'clearly visible — the retainer should be obvious in the photo'
        : visibilidad === 'baja'
          ? 'barely noticeable — very subtle presence'
          : 'subtly visible — present but not distracting';
    instructions.push(
      `The retainer MUST be ${visDesc} in the photo.`,
    );
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

  // Layer 3: Doctor parameter instructions (detailed & imperative)
  const configInstructions = doctorConfigToInstructions(input.doctorConfig);
  if (configInstructions.length > 0) {
    sections.push(
      'Doctor-specified configuration parameters:',
      ...configInstructions,
    );
  }

  // Layer 4: Doctor override — free-text clinical instructions (HIGH PRIORITY)
  // Placed near the end so it has more weight in OpenAI's interpretation
  const doctorOverride = normalizeText(input.doctorOverride);
  if (doctorOverride) {
    sections.push(
      'IMPORTANT — Custom clinical instructions from the supervising doctor:\n' +
        `"${doctorOverride}"\n` +
        'These instructions override any conflicting default parameters. Apply them carefully.',
    );
  }

  // Layer 5: Treatment-specific negative instructions
  if (profile.negativeInstructions.length > 0) {
    sections.push(...profile.negativeInstructions);
  }

  // Layer 6: Clinical disclaimer
  sections.push(CLINICAL_DISCLAIMER);

  // Layer 7: Doctor notes (complement only, last — low priority, never overrides)
  const notes = normalizeText(input.notes);
  if (notes) {
    sections.push(
      `Additional context notes from the doctor: ${notes}.`,
    );
  }

  return {
    promptUsed: sections.join(' '),
    promptVersion: PROMPT_VERSION,
    treatmentProfileId: profile.id,
  };
}
