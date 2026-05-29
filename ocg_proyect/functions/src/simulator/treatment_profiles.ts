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

const AESTHETIC_FALLBACK_PROFILE_ID = 'carillas';

const RECONSTRUCCION: TreatmentPromptProfile = {
  id: 'reconstruccion',
  label: 'Reconstrucción',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    diente: 'anterior',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Reconstruct the selected damaged or decayed tooth area so it looks restored with natural dental anatomy.',
    'Match the restoration shade and translucency to the neighboring teeth.',
    'Preserve all healthy neighboring teeth exactly; modify only the damaged or decayed tooth structure that needs reconstruction.',
    'Keep the result conservative and clinically believable, as a direct restoration or rebuilding of the visible tooth structure.',
  ],
  negativeInstructions: [
    'Do NOT add orthodontic appliances, brackets, archwires, aligners, retainers, or expanders.',
    'Do NOT redesign the whole smile unless the selected tooth requires local harmony.',
    'Do NOT create oversized crowns or unnaturally perfect teeth.',
  ],
  photoRequirements: [
    'Photo where the target tooth and neighboring teeth are visible.',
    'Good lighting and enough sharpness to see the damaged tooth area.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const LIMPIEZA_ORAL: TreatmentPromptProfile = {
  id: 'limpieza_oral',
  label: 'Limpieza',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    intensidad: 'media',
    arcada: 'ambas',
  },
  positiveInstructions: [
    'Simulate a mild, conservative result after a professional oral cleaning.',
    'Remove only visible plaque, calculus, and superficial extrinsic stains from tooth surfaces and along the gumline.',
    'Keep every tooth with the exact same shape, size, alignment, spacing, incisal edges, anatomy, and natural shade as the original photo.',
    'The result should look like cleaner tooth surfaces, not whitening, veneers, reshaping, or smile design.',
  ],
  negativeInstructions: [
    'Do NOT whiten teeth or change the intrinsic tooth color.',
    'Do NOT change tooth shape, position, size, alignment, spacing, incisal edges, or anatomy.',
    'Do NOT make teeth straighter, more even, larger, smaller, longer, shorter, smoother, or cosmetically redesigned.',
    'Do NOT change lips, gums, face, skin, or facial features beyond removing visible surface debris near the gumline.',
    'Do NOT add veneers, crowns, or any appliances.',
  ],
  photoRequirements: [
    'Frontal or intraoral photo where tooth surfaces and gumline are visible.',
    'Good lighting for stain and plaque visibility.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const REEMPLAZO_DENTAL: TreatmentPromptProfile = {
  id: 'reemplazo_dental',
  label: 'Reemplazo de dientes',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    tipoProtesis: 'corona',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Replace the indicated missing or compromised tooth area with a natural-looking prosthetic dental result.',
    'The replacement must harmonize with neighboring teeth in color, size, contour, and alignment.',
    'Preserve healthy neighboring teeth and all non-target teeth exactly unless they are part of the selected prosthetic replacement.',
    'If the selected type is bridge or partial prosthesis, make it look like a realistic dental restoration, not an appliance display.',
  ],
  negativeInstructions: [
    'Do NOT add orthodontic brackets, archwires, aligners, retainers, or expanders.',
    'Do NOT alter healthy neighboring teeth more than needed for natural harmony.',
    'Do NOT create an artificial denture-like smile.',
  ],
  photoRequirements: [
    'Photo showing the missing tooth area or the area to be replaced.',
    'Neighboring teeth should be visible for shade and proportion matching.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const IMPLANTES_DENTALES: TreatmentPromptProfile = {
  id: 'implantes_dentales',
  label: 'Implantes dentales',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    cantidad: 'unitario',
    zona: 'anterior',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Simulate the final visible crown restoration over dental implant treatment.',
    'Show a natural tooth emerging from the gum with realistic contour, shade, and proportion.',
    'Modify only the missing-tooth or implant-restoration area; preserve all existing teeth exactly.',
    'The visible result should look like a completed implant-supported crown or crowns, not like surgical hardware.',
  ],
  negativeInstructions: [
    'Do NOT show screws, surgical instruments, titanium roots, blood, incisions, or clinical surgery.',
    'Do NOT add orthodontic appliances.',
    'Do NOT change lips, skin, face, or background.',
  ],
  photoRequirements: [
    'Photo showing the edentulous or restoration area.',
    'Gumline and neighboring teeth should be visible.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const BORDES_INCISALES: TreatmentPromptProfile = {
  id: 'bordes_incisales',
  label: 'Bordes dentales',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    ajuste: 'moderado',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Improve worn, fractured, uneven, or short incisal edges on anterior teeth.',
    'Refine the shape and length of the front teeth while keeping natural anatomy and patient-specific character.',
    'Limit changes to the selected incisal edges; preserve all non-target tooth surfaces, shade, alignment, and gums.',
    'Create a balanced smile line that still looks realistic and clinically conservative.',
  ],
  negativeInstructions: [
    'Do NOT add brackets, aligners, retainers, crowns, or full veneers unless explicitly indicated.',
    'Do NOT make all teeth perfectly identical or unnaturally square.',
    'Do NOT alter gums, lips, face, or background.',
  ],
  photoRequirements: [
    'Frontal smile with anterior incisal edges visible.',
    'Good lighting and focus on the front teeth.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const GINGIVECTOMIA: TreatmentPromptProfile = {
  id: 'gingivectomia',
  label: 'Gingivectomía',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    zona: 'sector1',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Simulate a conservative gingivectomy result by reducing excess gingival tissue in the selected area.',
    'Reveal slightly more natural tooth crown length while preserving realistic gum texture and color.',
    'Change only the gingival tissue contour; keep tooth shape, size, shade, alignment, spacing, and incisal edges unchanged.',
    'Keep the gumline healthy, smooth, and clinically plausible.',
  ],
  negativeInstructions: [
    'Do NOT show bleeding, incisions, sutures, surgical instruments, or trauma.',
    'Do NOT overexpose roots or make teeth look unnaturally long.',
    'Do NOT alter the teeth themselves in shape, color, size, alignment, or position.',
    'Do NOT change lips, face, skin, or background.',
  ],
  photoRequirements: [
    'Photo where the gumline and target teeth are clearly visible.',
    'Good lighting to distinguish tooth and gingiva contours.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const GINGIVOPLASTIA: TreatmentPromptProfile = {
  id: 'gingivoplastia',
  label: 'Gingivoplastia',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    zona: 'sector1',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Remodel the visible gingival contour for a more aesthetic and harmonious gum shape.',
    'Improve scalloping and symmetry while preserving a natural gum color and texture.',
    'Change only the gum contour; keep tooth shape, size, shade, alignment, spacing, and incisal edges unchanged.',
    'The result should look like healed aesthetic gum contouring, not a surgical moment.',
  ],
  negativeInstructions: [
    'Do NOT show blood, cuts, sutures, instruments, or fresh surgery.',
    'Do NOT change tooth shade, shape, size, position, alignment, spacing, or add restorative material.',
    'Do NOT alter lips, face, skin, or background.',
  ],
  photoRequirements: [
    'Frontal smile with gumline visible.',
    'Good lighting and enough detail around the gingival margins.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const ALINEACION_MARGENES: TreatmentPromptProfile = {
  id: 'alineacion_margenes',
  label: 'Alineación de márgenes',
  allowedVisualGoals: ['aesthetic_improvement'],
  defaultConfig: {
    zona: 'sector1',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Correct the visible gingival margin contour so gum levels look more symmetrical.',
    'Align the gumline heights between comparable teeth while keeping natural gingival anatomy.',
    'Change only the gingival margins; preserve tooth shape, size, shade, alignment, spacing, and incisal edges exactly.',
    'Create a balanced, healed, aesthetic contour with realistic tissue texture.',
  ],
  negativeInstructions: [
    'Do NOT show surgical trauma, bleeding, cuts, or instruments.',
    'Do NOT make teeth unnaturally long or identical.',
    'Do NOT alter the teeth themselves in shape, color, size, alignment, or position.',
    'Do NOT alter lips, face, skin, or background.',
  ],
  photoRequirements: [
    'Frontal smile where gingival margins are visible.',
    'Good lighting and focus around the gumline.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const METAL_BRACES: TreatmentPromptProfile = {
  id: 'metal_braces',
  label: 'Brackets metálicos',
  allowedVisualGoals: ['show_appliance'],
  defaultConfig: {
    ligatureColor: '#9E9E9E',
    archwire: 'visible',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Add visible metal brackets on the front surfaces of the visible teeth.',
    'Add a thin metal archwire running across the brackets.',
    'Add small elastic ligatures (o-rings) around each bracket.',
    'Only add the appliance; keep tooth shape, size, shade, position, alignment, spacing, and gums unchanged.',
  ],
  negativeInstructions: [
    'Do NOT add ceramic, clear, or tooth-colored brackets.',
    'Do NOT add invisible aligners.',
    'Do NOT dramatically whiten the teeth as the primary change.',
    'Do NOT change the shape or position of the teeth dramatically.',
    'Do NOT straighten, move, resize, reshape, or recolor the teeth.',
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
    archwire: 'estandar',
    arcada: 'superior',
  },
  positiveInstructions: [
    'Add discreet orthodontic brackets on the visible teeth according to the selected material.',
    'Keep the brackets low-profile, clean, and clinically realistic.',
    'Add elastic ligatures and an archwire that match the selected configuration.',
    'Only add the appliance; keep tooth shape, size, shade, position, alignment, spacing, and gums unchanged.',
  ],
  negativeInstructions: [
    'Do NOT add invisible aligners.',
    'Do NOT dramatically whiten the teeth.',
    'Do NOT change tooth shape or position dramatically.',
    'Do NOT straighten, move, resize, reshape, or recolor the teeth.',
    'Do NOT make the appliance look oversized or artificial.',
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
    'Only add the aligner and optional attachments; keep underlying tooth shape, size, shade, position, alignment, spacing, and gums unchanged.',
  ],
  negativeInstructions: [
    'Do NOT add metal or ceramic brackets.',
    'Do NOT add archwires.',
    'Do NOT make the aligner completely invisible; a subtle sheen must be present.',
    'Do NOT dramatically whiten the teeth.',
    'Do NOT straighten, move, resize, reshape, or recolor the teeth.',
  ],
  photoRequirements: [
    'Frontal smile with teeth visible.',
    'Sufficient lighting.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const BLANQUEAMIENTO: TreatmentPromptProfile = {
  id: 'blanqueamiento',
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
    'Change only tooth shade; preserve tooth shape, size, alignment, position, spacing, incisal edges, gums, and restorations unless shade harmonization is necessary.',
    'Maintain natural translucency at the incisal edges; do not make teeth look opaque or chalky.',
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
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const CARILLAS: TreatmentPromptProfile = {
  id: 'carillas',
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
    'Limit cosmetic changes to the visible anterior teeth indicated for veneers; preserve posterior and non-target teeth as much as possible.',
    'If closing gaps is indicated, close diastemas naturally.',
    'Achieve a warm, natural white tone; not artificial or overly bright.',
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
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
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
    'Only add the appliance; keep tooth shape, size, shade, position, alignment, spacing, lips, and gums unchanged.',
  ],
  negativeInstructions: [
    'If the palate is NOT visible in the photo, do NOT invent or add any appliance.',
    'Do NOT place the expander on the front surfaces of teeth like brackets.',
    'Do NOT add brackets or aligners.',
    'Do NOT straighten, move, resize, reshape, or recolor the teeth.',
  ],
  photoRequirements: [
    'Intraoral upper photo or open mouth showing palate is strongly recommended.',
    'Frontal smile photos may not be suitable for this treatment.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

const RETAINER: TreatmentPromptProfile = {
  id: 'retainer',
  label: 'Retenedor post-tratamiento',
  allowedVisualGoals: ['show_appliance'],
  defaultConfig: {
    tipo: 'Essix',
    arcada: 'superior',
    visibilidad: 'media',
  },
  positiveInstructions: [
    'Add the selected orthodontic retainer appliance as the main dental change in the image.',
    'Do not leave the teeth unchanged: the retainer must be identifiable in the generated photo.',
    'For clear removable retainers, show visible tray edges, slight plastic thickness, and glossy reflections on the teeth.',
    'If fixed lingual type: barely visible, a very thin wire behind the teeth. From a frontal smile, this should be nearly invisible.',
    'Only add the retainer; keep tooth shape, size, shade, position, alignment, spacing, and gums unchanged.',
  ],
  negativeInstructions: [
    'Do NOT add brackets with archwires.',
    'Do NOT add aligner attachments.',
    'Do NOT make the retainer look like full orthodontic braces.',
    'If fixed lingual, do NOT make the wire visible from the front.',
    'Do NOT straighten, move, resize, reshape, or recolor the teeth.',
  ],
  photoRequirements: [
    'Frontal smile with teeth visible.',
    'For fixed lingual, no special requirements; the wire is behind the teeth.',
  ],
  fallbackProfileId: AESTHETIC_FALLBACK_PROFILE_ID,
};

// Profile map and resolution

export const TREATMENT_PROFILES: Record<string, TreatmentPromptProfile> = {
  reconstruccion: RECONSTRUCCION,
  limpieza_oral: LIMPIEZA_ORAL,
  reemplazo_dental: REEMPLAZO_DENTAL,
  implantes_dentales: IMPLANTES_DENTALES,
  bordes_incisales: BORDES_INCISALES,
  gingivectomia: GINGIVECTOMIA,
  gingivoplastia: GINGIVOPLASTIA,
  alineacion_margenes: ALINEACION_MARGENES,
  metal_braces: METAL_BRACES,
  esthetic_braces: ESTHETIC_BRACES,
  clear_aligners: CLEAR_ALIGNERS,
  blanqueamiento: BLANQUEAMIENTO,
  carillas: CARILLAS,
  palatal_expander: PALATAL_EXPANDER,
  retainer: RETAINER,
};

const RENAMED_PROFILE_ALIASES: Record<string, string> = {
  whitening: 'blanqueamiento',
  veneers: 'carillas',
};

/** Legacy treatmentType -> profileId mapping for backward compatibility */
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
  if (treatmentProfileId) {
    const requestedId = treatmentProfileId.trim();
    const normalizedId = RENAMED_PROFILE_ALIASES[requestedId] ?? requestedId;
    const direct = TREATMENT_PROFILES[normalizedId];
    if (direct) return direct;
  }

  if (legacyTreatmentType) {
    const key = LEGACY_TREATMENT_MAP[legacyTreatmentType.trim().toLowerCase()];
    if (key) {
      const inferred = TREATMENT_PROFILES[key];
      if (inferred) return inferred;
    }
  }

  return CARILLAS;
}
