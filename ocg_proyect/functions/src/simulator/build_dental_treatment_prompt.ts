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

export type BuildDentalTreatmentPromptInput = {
  treatmentProfileId?: string;
  legacyTreatmentType?: string;
  visualGoal?: string;
  doctorConfig?: Record<string, unknown>;
  /** Free-text clinical instructions from the doctor - high priority. */
  doctorOverride?: string;
  notes?: string;
};

export type BuildDentalTreatmentPromptResult = {
  promptUsed: string;
  promptVersion: string;
  treatmentProfileId: string;
};

const PROMPT_VERSION = 'ocg-dental-treatment-v3';

const CLINICAL_DISCLAIMER = [
  'The result is a visual simulation for educational purposes only.',
  'It does not represent a guaranteed clinical outcome.',
  'Actual results depend on diagnosis, biomechanics, treatment time, biological response, and the clinical plan.',
].join(' ');

const IDENTITY_BASE = [
  'Edit ONLY the visible dental area of the patient.',
  'Preserve the face, lips, skin, facial expression, lighting, framing, age appearance, and identity exactly as they are.',
  'Do not change the shape of the face.',
  'Do not alter eyes, nose, hair, skin, or background.',
  'Do not produce an artificial or cartoonish result.',
  'Keep the image looking like a real clinical photograph.',
].join(' ');

function normalizeText(value?: string): string {
  return (value ?? '').replace(/\s+/g, ' ').trim();
}

function describeLigatureColor(value: string): string {
  const normalized = value.trim().toUpperCase();
  const colorMap: Record<string, string> = {
    '#9E9E9E': 'gray',
    '#2196F3': 'blue',
    '#F44336': 'red',
    '#673AB7': 'purple',
    '#FF9800': 'orange',
    '#FFEB3B': 'yellow',
    '#4CAF50': 'green',
    '#00BCD4': 'cyan',
    '#E91E63': 'pink',
    '#0D47A1': 'dark blue',
    '#009688': 'teal',
    '#795548': 'brown',
    '#607D8B': 'blue gray',
    '#FFFFFF': 'white',
    '#000000': 'black',
    '#8BC34A': 'light green',
    '#FFC107': 'amber',
    '#CDDC39': 'lime',
    '#E65100': 'dark orange',
    '#757575': 'medium gray',
    '#9C27B0': 'purple',
    '#03A9F4': 'light blue',
    '#D500F9': 'fuchsia',
    '#39FF14': 'neon green',
    '#FF5F1F': 'neon orange',
    '#81D4FA': 'sky blue',
    '#B39DDB': 'lavender',
    '#F8BBD0': 'light pink',
    '#BBDEFB': 'baby blue',
  };
  const legacyMap: Record<string, string> = {
    gris: 'gray',
    azul: 'blue',
    rojo: 'red',
    morado: 'purple',
    naranja: 'orange',
    amarillo: 'yellow',
    verde: 'green',
    cyan: 'cyan',
    rosa: 'pink',
  };
  const lower = value.trim().toLowerCase();
  if (lower === 'transparente') return 'clear/transparent';
  return colorMap[normalized] ?? legacyMap[lower] ?? value;
}

function doctorConfigToInstructions(
  config: Record<string, unknown> | undefined,
): string[] {
  if (!config || Object.keys(config).length === 0) return [];

  const instructions: string[] = [];
  const c = config;

  const ligColor = normalizeText(c['ligatureColor'] as string | undefined);
  if (ligColor) {
    const ligColorDesc = describeLigatureColor(ligColor);
    instructions.push(
      `The elastic ligatures (o-rings) around each bracket MUST be visibly ${ligColorDesc}. ` +
        'Make the color clearly noticeable in the photo.',
    );
  }

  const material = normalizeText(c['material'] as string | undefined);
  if (material) {
    const materialLabel =
      material === 'ceramico'
        ? 'ceramic or tooth-colored'
        : material === 'metalico'
          ? 'polished metallic'
          : material === 'zafiro'
            ? 'sapphire-clear'
            : material;
    instructions.push(
      `The bracket material MUST look like ${materialLabel}, accurate to the selected material.`,
    );
  }

  const archwire = normalizeText(c['archwire'] as string | undefined);
  if (archwire) {
    const wireDesc = archwire === 'fino'
      ? 'a fine, thin metal wire'
      : archwire === 'reforzado'
        ? 'a slightly thicker reinforced archwire'
        : archwire === 'estetico'
          ? 'tooth-colored or clear'
          : 'a standard visible metal archwire';
    instructions.push(`The archwire MUST appear as ${wireDesc}.`);
  }

  const arcada = normalizeText(c['arcada'] as string | undefined);
  if (arcada) {
    const archDesc =
      arcada === 'superior'
        ? 'upper teeth only'
        : arcada === 'inferior'
          ? 'lower teeth only'
          : 'both upper and lower teeth';
    instructions.push(`Apply the treatment to the ${archDesc}.`);
  }

  const diente = normalizeText(c['diente'] as string | undefined);
  if (diente) {
    const toothDesc =
      diente === 'posterior'
        ? 'posterior tooth area'
        : diente === 'individual'
          ? 'one individual target tooth'
          : 'anterior tooth area';
    instructions.push(`Focus the restoration change on the ${toothDesc}.`);
  }

  const intensidad = normalizeText(c['intensidad'] as string | undefined);
  if (intensidad) {
    const intensityDesc =
      intensidad === 'profunda'
        ? 'deep and clearly visible cleaning, removing heavy deposits while staying realistic'
        : intensidad === 'leve'
          ? 'light cleaning with subtle stain and plaque reduction'
          : 'moderate professional cleaning with visible but natural improvement';
    instructions.push(`The oral cleaning result MUST look like a ${intensityDesc}.`);
  }

  const tipoProtesis = normalizeText(c['tipoProtesis'] as string | undefined);
  if (tipoProtesis) {
    const prosthesisDesc =
      tipoProtesis === 'puente'
        ? 'fixed dental bridge'
        : tipoProtesis === 'protesis_parcial'
          ? 'natural-looking partial prosthetic replacement'
          : tipoProtesis === 'protesis_total'
            ? 'full-arch prosthetic replacement'
            : 'single crown restoration';
    instructions.push(`The replacement MUST look like a ${prosthesisDesc}.`);
  }

  const cantidad = normalizeText(c['cantidad'] as string | undefined);
  if (cantidad) {
    instructions.push(
      cantidad === 'multiple'
        ? 'Apply the implant restoration concept to multiple missing teeth where visible.'
        : 'Apply the implant restoration concept to one single missing tooth where visible.',
    );
  }

  const zona = normalizeText(c['zona'] as string | undefined);
  if (zona) {
    const zoneDesc =
      zona === 'posterior'
        ? 'posterior zone'
        : zona === 'generalizada'
          ? 'generalized visible area'
          : zona.startsWith('sector')
            ? `selected dental ${zona}`
            : 'anterior zone';
    instructions.push(`Apply the treatment to the ${zoneDesc}.`);
  }

  const ajuste = normalizeText(c['ajuste'] as string | undefined);
  if (ajuste) {
    const adjustmentDesc =
      ajuste === 'significativo'
        ? 'significant but still clinically believable incisal edge reshaping'
        : ajuste === 'conservador'
          ? 'conservative and subtle incisal edge refinement'
          : 'moderate incisal edge improvement';
    instructions.push(`The incisal edge adjustment MUST be ${adjustmentDesc}.`);
  }

  const attachments = normalizeText(c['attachments'] as string | undefined);
  if (attachments) {
    const attachDesc =
      attachments === 'muchos' || attachments === 'varios'
        ? 'multiple visible composite attachments (buttons) on several teeth'
        : attachments === 'pocos'
          ? 'a few small composite attachments on select teeth'
          : 'no attachments';
    instructions.push(`The aligner MUST show ${attachDesc}.`);
  }

  const transparency = normalizeText(c['transparency'] as string | undefined);
  if (transparency) {
    const transDesc =
      transparency === 'alto'
        ? 'very transparent, almost invisible plastic'
        : transparency === 'bajo'
          ? 'more opaque, clearly visible plastic tray'
          : 'moderately transparent with a subtle plastic sheen';
    instructions.push(`The aligner MUST look ${transDesc}.`);
  }

  const toneTarget = normalizeText(c['toneTarget'] as string | undefined);
  if (toneTarget) {
    const toneDesc =
      toneTarget === 'alto'
        ? 'significantly whiter (4+ shades lighter)'
        : toneTarget === 'leve' || toneTarget === 'bajo'
          ? 'slightly lighter (1-2 shades)'
          : 'noticeably whiter (2-3 shades)';
    instructions.push(`The teeth MUST look ${toneDesc} compared to the original photo.`);
  }

  const naturalness = normalizeText(c['naturalness'] as string | undefined);
  if (naturalness) {
    const natDesc =
      naturalness === 'artificial' || naturalness === 'brillante'
        ? 'a bright but still controlled white'
        : naturalness === 'conservador'
          ? 'a very subtle, conservative whitening'
          : 'a natural, believable white appropriate for the patient';
    instructions.push(`The whitening result MUST look ${natDesc}.`);
  }

  const materialVisual = normalizeText(c['materialVisual'] as string | undefined);
  if (materialVisual) {
    const visualMaterialDesc =
      materialVisual === 'resina' ? 'direct composite resin' : 'natural ceramic';
    instructions.push(
      `The veneer material appearance MUST look like ${visualMaterialDesc}.`,
    );
  }

  const forma = normalizeText(c['forma'] as string | undefined);
  if (forma) {
    const formaDesc =
      forma === 'cuadrada' || forma === 'cuadrada-suave'
        ? 'soft square, modern tooth shapes'
        : forma === 'redonda' || forma === 'ovalada'
          ? 'rounded, softer tooth shapes'
          : forma === 'ojival'
            ? 'pointed, ovoid tooth shapes'
            : 'natural, balanced tooth shapes';
    instructions.push(`The tooth shapes MUST look ${formaDesc}.`);
  }

  const tono = normalizeText(c['tono'] as string | undefined);
  if (tono) {
    instructions.push(
      `The overall tooth shade MUST be ${tono}, visibly different from the original.`,
    );
  }

  const longitudIncisal = normalizeText(c['longitudIncisal'] as string | undefined);
  if (longitudIncisal) {
    const incisalDesc =
      longitudIncisal === 'largo' || longitudIncisal === 'alargar medio'
        ? 'longer incisal edges; teeth should appear slightly elongated'
        : longitudIncisal === 'alargar leve'
          ? 'slightly longer incisal edges'
          : longitudIncisal === 'corto'
            ? 'shorter incisal edges; teeth should look slightly reduced in length'
            : 'the same incisal edge length as the original';
    instructions.push(`The incisal edges MUST look ${incisalDesc}.`);
  }

  const simetria = normalizeText(c['simetria'] as string | undefined);
  if (simetria) {
    const simDesc =
      simetria === 'alta'
        ? 'highly symmetrical, both sides should mirror each other closely'
        : simetria === 'baja'
          ? 'only slightly symmetrical, keeping natural asymmetry'
          : 'moderately symmetrical, balanced but not perfectly mirrored';
    instructions.push(`The smile MUST look ${simDesc}.`);
  }

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
    instructions.push(`The overall smile MUST look ${estiloDesc}.`);
  }

  const alineacionFinal = normalizeText(c['alineacionFinal'] as string | undefined);
  if (alineacionFinal) {
    const alineacionDesc =
      alineacionFinal === 'total'
        ? 'perfectly straight, every tooth aligned precisely'
        : alineacionFinal === 'parcial'
          ? 'improved alignment but with minor natural imperfections'
          : 'well-aligned with a natural, healthy look';
    instructions.push(`The teeth alignment MUST look ${alineacionDesc}.`);
  }

  const bordeIncisal = normalizeText(c['bordeIncisal'] as string | undefined);
  if (bordeIncisal) {
    const bordeDesc =
      bordeIncisal === 'recto'
        ? 'a straight, flat incisal edge line across the smile'
        : bordeIncisal === 'curvo'
          ? 'a curved, smile-following incisal edge line'
          : 'a naturally harmonized incisal edge that follows the lower lip';
    instructions.push(`The incisal edge line MUST look ${bordeDesc}.`);
  }

  const tipoVisual = normalizeText(c['tipoVisual'] as string | undefined);
  if (tipoVisual) {
    instructions.push(
      `The expander MUST look like a ${tipoVisual} appliance, accurate to that specific design.`,
    );
  }

  const tipo = normalizeText(c['tipo'] as string | undefined);
  if (tipo) {
    const tipoKey = tipo.toLowerCase();
    const retDesc =
      tipoKey === 'essix'
        ? 'a thin clear plastic Essix retainer tray covering the selected teeth, with visible tray edges along the gumline and incisal edges, slight plastic thickness, and glossy highlights'
        : tipoKey === 'hawley'
          ? 'a Hawley retainer with a visible metal labial bow wire across the front teeth and subtle acrylic behind the teeth'
          : 'a fixed lingual wire bonded behind the teeth, visible only as small bonding points or subtle wire glimpses where clinically plausible';
    instructions.push(
      `The retainer MUST look like ${retDesc}.`,
      `Use the ${tipo} retainer style only; do not mix it with other retainer styles unless explicitly requested.`,
      'Do not output a normal unchanged smile; the generated image MUST clearly show that a retainer appliance is present.',
    );
  }

  const visibilidad = normalizeText(c['visibilidad'] as string | undefined);
  if (visibilidad) {
    const visDesc =
      visibilidad === 'alta'
        ? 'clearly visible, the retainer should be obvious in the photo'
        : visibilidad === 'baja'
          ? 'barely noticeable, very subtle presence'
          : 'subtly visible, present but not distracting';
    const reinforcedVisDesc =
      visibilidad === 'media'
        ? 'clearly visible enough to confirm the retainer is present, without looking exaggerated'
        : visibilidad === 'sutil'
          ? 'subtle but still identifiable: visible tray edges, reflections, or wire must confirm it is present'
          : visDesc;
    instructions.push(`The retainer MUST be ${reinforcedVisDesc} in the photo.`);
  }

  return instructions;
}

export function buildDentalTreatmentPrompt(
  input: BuildDentalTreatmentPromptInput,
): BuildDentalTreatmentPromptResult {
  const profile: TreatmentPromptProfile = resolveTreatmentProfile(
    input.treatmentProfileId,
    input.legacyTreatmentType,
  );

  const sections: string[] = [];
  const effectiveDoctorConfig = {
    ...profile.defaultConfig,
    ...(input.doctorConfig ?? {}),
  };

  sections.push(IDENTITY_BASE);

  if (profile.positiveInstructions.length > 0) {
    sections.push(...profile.positiveInstructions);
  }

  const configInstructions = doctorConfigToInstructions(effectiveDoctorConfig);
  if (configInstructions.length > 0) {
    sections.push(
      'Doctor-specified configuration parameters:',
      ...configInstructions,
    );
  }

  const doctorOverride = normalizeText(input.doctorOverride);
  if (doctorOverride) {
    sections.push(
      'IMPORTANT - Custom clinical instructions from the supervising doctor:\n' +
        `"${doctorOverride}"\n` +
        'These instructions override any conflicting default parameters. Apply them carefully.',
    );
  }

  if (profile.negativeInstructions.length > 0) {
    sections.push(...profile.negativeInstructions);
  }

  sections.push(CLINICAL_DISCLAIMER);

  const notes = normalizeText(input.notes);
  if (notes) {
    sections.push(`Additional context notes from the doctor: ${notes}.`);
  }

  return {
    promptUsed: sections.join(' '),
    promptVersion: PROMPT_VERSION,
    treatmentProfileId: profile.id,
  };
}
