/**
 * Treatment prompt profiles for OCG dental simulator.
 *
 * Each profile defines what gpt-image-2 should visually produce
 * and what it must avoid, so different treatments look different.
 */

export type TreatmentVisualGoal =
  | 'show_appliance'
  | 'aesthetic_improvement'
  | 'final_result';

export type TreatmentPromptProfile = {
  id: string;
  label: string;
  allowedVisualGoals: TreatmentVisualGoal[];
  defaultConfig: Record<string, unknown>;
  /** What the AI should produce visually */
  positiveInstructions: string[];
  /** What the AI must avoid */
  negativeInstructions: string[];
  /** Photo requirements that must be met */
  photoRequirements: string[];
  /** Safe fallback if profile can't be applied */
  fallbackProfileId: string;
};

// ── Identity preservation (shared by all profiles) ─────

const IDENTITY_BASE = [
  'Edit ONLY the visible dental area of the patient.',
  'Preserve the face, lips, skin, facial expression, lighting, framing, and identity exactly as they are.',
  'Do not change the shape of the face.',
  'Do not alter eyes, nose, hair, skin, or background.',
  'Keep the image looking like a real clinical photo, not an artificial rendering.',
  'The result is an orientative visual simulation, not a clinical promise.',
];

// ── Profiles ────────────────────────────────────────────

const METAL_BRACES: TreatmentPromptProfile = {
  id: 'metal_braces',
  label: 'Brackets metálicos',
  allowedVisualGoals: ['show_appliance'],
  defaultConfig: {
    ligatureColor: 'gris',
    archwire: 'visible',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Add visible metal brackets on the front surfaces of the visible teeth.',
    'Add a thin metal archwire running across the brackets.',
    'Add small elastic ligatures (o-rings) around each bracket.',
  ],
  negativeInstructions: [
    'Do NOT add ceramic, clear, or tooth-colored brackets.',
    'Do NOT add invisible aligners.',
    'Do NOT dramatically whiten the teeth as the primary change.',
    'Do NOT change the shape or position of the teeth dramatically.',
    'Do NOT remove existing dental features.',
  ],
  photoRequirements: [
    'Frontal smile with upper teeth visible.',
    'Sufficient lighting.',
  ],
  fallbackProfileId: 'metal_braces',
};

const ESTHETIC_BRACES: TreatmentPromptProfile = {
  id: 'esthetic_braces',
  label: 'Brackets estéticos',
  allowedVisualGoals: ['show_appliance'],
  defaultConfig: {
    material: 'ceramico',
    ligatureColor: 'transparente',
    archwire: 'estetico',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Add ceramic or sapphire brackets on the visible teeth. They should look clear, translucent, or tooth-colored — discreet, not metallic.',
    'Add a subtle, tooth-colored or clear archwire.',
    'Add clear or pearl-colored elastic ligatures.',
  ],
  negativeInstructions: [
    'Do NOT add dark metal brackets.',
    'Do NOT make the brackets completely invisible like aligners.',
    'Do NOT dramatically whiten the teeth.',
    'Do NOT change tooth shape or position dramatically.',
  ],
  photoRequirements: [
    'Frontal smile with upper teeth visible.',
    'Good lighting to show subtle bracket details.',
  ],
  fallbackProfileId: 'metal_braces',
};

const CLEAR_ALIGNERS: TreatmentPromptProfile = {
  id: 'clear_aligners',
  label: 'Alineadores transparentes',
  allowedVisualGoals: ['show_appliance', 'aesthetic_improvement'],
  defaultConfig: {
    alignerPresent: true,
    attachments: 'pocos',
    arcada: 'superior',
    transparency: 'medio',
  },
  positiveInstructions: [
    'Add a thin transparent plastic aligner tray covering the visible teeth.',
    'Add subtle plastic sheen or light reflection on the tooth surfaces to suggest the aligner material.',
    'Add soft, barely visible tray edges along the gumline.',
  ],
  negativeInstructions: [
    'Do NOT add metal or ceramic brackets.',
    'Do NOT add archwires.',
    'Do NOT make the aligner completely invisible — a subtle sheen must be present.',
    'Do NOT dramatically whiten the teeth.',
  ],
  photoRequirements: [
    'Frontal smile with teeth visible.',
    'Sufficient lighting.',
  ],
  fallbackProfileId: 'smile_design',
};

const WHITENING: TreatmentPromptProfile = {
  id: 'whitening',
  label: 'Blanqueamiento dental',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    toneTarget: 'medio',
    naturalness: 'natural',
    preserveStains: false,
  },
  positiveInstructions: [
    'Lighten the tooth shade by 2-4 shades, achieving a natural, healthy white tone.',
    'Keep the tooth color uniform and believable for the patient\'s age and skin tone.',
    'Maintain natural translucency at the incisal edges — do not make teeth look opaque or chalky.',
  ],
  negativeInstructions: [
    'Do NOT change the shape, size, or position of any tooth.',
    'Do NOT add veneers, crowns, or any dental appliances.',
    'Do NOT make teeth unnaturally white or glowing.',
    'Do NOT change lips, gums, or any facial feature.',
  ],
  photoRequirements: [
    'Frontal smile with teeth visible.',
    'Good lighting for accurate shade perception.',
  ],
  fallbackProfileId: 'smile_design',
};

const VENEERS: TreatmentPromptProfile = {
  id: 'veneers',
  label: 'Carillas / vinillas',
  allowedVisualGoals: ['aesthetic_improvement', 'final_result'],
  defaultConfig: {
    materialVisual: 'ceramica',
    forma: 'natural',
    tono: 'blanco calido',
    longitudIncisal: 'conservar',
    simetria: 'media',
    cerrarDiastemas: false,
  },
  positiveInstructions: [
    'Improve the shape, proportion, symmetry, and color of the visible anterior teeth so they look like natural, well-designed ceramic veneers.',
    'Harmonize the incisal edges for a balanced smile line.',
    'If closing gaps is indicated, close diastemas naturally.',
    'Achieve a warm, natural white tone — not artificial or overly bright.',
  ],
  negativeInstructions: [
    'Do NOT add brackets, archwires, or aligners.',
    'Do NOT aggressively change the gums or lips.',
    'Do NOT create unnaturally square or perfectly uniform teeth.',
    'Do NOT make teeth look like dentures.',
  ],
  photoRequirements: [
    'Frontal smile with anterior teeth clearly visible.',
    'Good lighting.',
  ],
  fallbackProfileId: 'smile_design',
};

const SMILE_DESIGN: TreatmentPromptProfile = {
  id: 'smile_design',
  label: 'Diseño de sonrisa',
  allowedVisualGoals: ['final_result'],
  defaultConfig: {
    estilo: 'armonico',
    alineacionFinal: 'media',
    tono: 'blanco moderado',
    bordeIncisal: 'armonizado',
    simetriaSonrisa: 'media',
  },
  positiveInstructions: [
    'Create the ideal final orthodontic result: perfectly aligned teeth with a harmonious smile arc.',
    'Teeth should look straight, well-proportioned, and naturally beautiful.',
    'Achieve a clean, healthy tooth shade appropriate for the patient\'s appearance.',
    'The smile should look balanced, symmetrical, and confident.',
  ],
  negativeInstructions: [
    'Do NOT show any brackets, wires, aligners, expanders, or retainers.',
    'Do NOT create an unnaturally white or artificial smile.',
    'Do NOT alter face shape, lips, or skin.',
    'Do NOT produce a "Hollywood" smile unless it fits the patient naturally.',
  ],
  photoRequirements: [
    'Frontal smile with teeth clearly visible.',
    'Good lighting.',
  ],
  fallbackProfileId: 'smile_design',
};

const PALATAL_EXPANDER: TreatmentPromptProfile = {
  id: 'palatal_expander',
  label: 'Expansor de paladar',
  allowedVisualGoals: ['show_appliance'],
  defaultConfig: {
    tipoVisual: 'Hyrax',
    arcada: 'superior',
  },
  positiveInstructions: [
    'If the photo shows the upper palate (mouth open or intraoral view), add a palatal expander appliance in the upper palate with a metal framework and central screw.',
    'The expander should look like a real orthodontic Hyrax or Haas appliance.',
  ],
  negativeInstructions: [
    'If the palate is NOT visible in the photo, do NOT invent or add any appliance.',
    'Do NOT place the expander on the front surfaces of teeth like brackets.',
    'Do NOT add brackets or aligners.',
  ],
  photoRequirements: [
    'Intraoral upper photo or open mouth showing palate is strongly recommended.',
    'Frontal smile photos may not be suitable for this treatment.',
  ],
  fallbackProfileId: 'smile_design',
};

const RETAINER: TreatmentPromptProfile = {
  id: 'retainer',
  label: 'Retenedor post-tratamiento',
  allowedVisualGoals: ['show_appliance'],
  defaultConfig: {
    tipo: 'Essix',
    arcada: 'superior',
    visibilidad: 'sutil',
  },
  positiveInstructions: [
    'If Essix type: add a thin, transparent retainer tray over the teeth, similar to an aligner but thinner and simpler, with subtle sheen.',
    'If Hawley type: add a thin visible metal wire across the front teeth with a subtle acrylic base behind the teeth.',
    'If fixed lingual type: barely visible — a very thin wire behind the teeth. From a frontal smile, this should be nearly invisible.',
  ],
  negativeInstructions: [
    'Do NOT add brackets with archwires.',
    'Do NOT add aligner attachments.',
    'Do NOT make the retainer look like full orthodontic braces.',
    'If fixed lingual, do NOT make the wire visible from the front.',
  ],
  photoRequirements: [
    'Frontal smile with teeth visible.',
    'For fixed lingual, no special requirements — the wire is behind the teeth.',
  ],
  fallbackProfileId: 'smile_design',
};

// ── Profile map and resolution ─────────────────────────

export const TREATMENT_PROFILES: Record<string, TreatmentPromptProfile> = {
  metal_braces: METAL_BRACES,
  esthetic_braces: ESTHETIC_BRACES,
  clear_aligners: CLEAR_ALIGNERS,
  whitening: WHITENING,
  veneers: VENEERS,
  smile_design: SMILE_DESIGN,
  palatal_expander: PALATAL_EXPANDER,
  retainer: RETAINER,
};

/** Legacy treatmentType → profileId mapping for backward compatibility */
const LEGACY_TREATMENT_MAP: Record<string, string> = {
  alineadores: 'clear_aligners',
  retenedores: 'retainer',
  estetico: 'esthetic_braces',
  convencional: 'metal_braces',
  autoligado: 'metal_braces',
  ortopedia: 'palatal_expander',
};

export function resolveTreatmentProfile(
  treatmentProfileId?: string,
  legacyTreatmentType?: string,
): TreatmentPromptProfile {
  // Use explicit profile ID if valid
  if (treatmentProfileId) {
    const direct = TREATMENT_PROFILES[treatmentProfileId.trim()];
    if (direct) return direct;
  }

  // Fallback: infer from legacy treatmentType
  if (legacyTreatmentType) {
    const key = LEGACY_TREATMENT_MAP[legacyTreatmentType.trim().toLowerCase()];
    if (key) {
      const inferred = TREATMENT_PROFILES[key];
      if (inferred) return inferred;
    }
  }

  // Ultimate fallback
  return SMILE_DESIGN;
}
