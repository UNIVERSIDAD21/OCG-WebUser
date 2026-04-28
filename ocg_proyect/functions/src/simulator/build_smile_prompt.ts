type BuildSmilePromptInput = {
  treatmentType?: string;
  notes?: string;
};

type BuildSmilePromptResult = {
  promptUsed: string;
  promptVersion: string;
};

const PROMPT_VERSION = 'ocg-smile-v1';

const BASE_PROMPT = [
  'Editar únicamente la zona dental visible del paciente.',
  'Mantener intactos rostro, labios, piel, expresión facial, iluminación, encuadre, edad aparente e identidad.',
  'Mejorar la apariencia dental de manera natural, realista y profesional.',
  'No cambiar la forma del rostro.',
  'No alterar ojos, nariz, cabello, piel ni fondo.',
  'No exagerar el blanqueamiento.',
  'No producir un resultado artificial.',
  'La imagen debe funcionar como simulación visual orientativa, no como promesa clínica.',
].join(' ');

function normalizeText(value?: string): string {
  return (value ?? '').replace(/\s+/g, ' ').trim();
}

export function buildSmilePrompt(
  input: BuildSmilePromptInput,
): BuildSmilePromptResult {
  const sections = [BASE_PROMPT];

  const treatmentType = normalizeText(input.treatmentType);
  if (treatmentType) {
    sections.push(`Tipo de tratamiento de referencia: ${treatmentType}.`);
  }

  const notes = normalizeText(input.notes);
  if (notes) {
    sections.push(`Notas clínicas complementarias: ${notes}.`);
  }

  return {
    promptUsed: sections.join(' '),
    promptVersion: PROMPT_VERSION,
  };
}
