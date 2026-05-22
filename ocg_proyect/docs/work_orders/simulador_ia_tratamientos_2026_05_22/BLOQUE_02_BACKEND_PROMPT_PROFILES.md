# BLOQUE 02 - Backend prompt profiles por tratamiento

## Objetivo

Hacer que `gpt-image-2` genere resultados diferentes por tratamiento usando perfiles de prompt y parametros estructurados.

Este bloque ataca el problema principal: el prompt actual es generico y siempre produce "dientes mejorados".

## Estado actual

Archivo actual:

- `functions/src/simulator/build_smile_prompt.ts`

Comportamiento actual:

```text
BASE_PROMPT + treatmentType + notes
```

Eso no basta para diferenciar:

- brackets metalicos;
- brackets esteticos;
- alineadores;
- blanqueamiento;
- carillas;
- diseno de sonrisa;
- expansor;
- retenedor.

## Archivos a tocar

- `functions/src/simulator/build_smile_prompt.ts`
- `functions/src/simulator/generate_smile_simulation_core.ts`
- `functions/src/simulator/generate_smile_simulation.ts`
- `functions/src/simulator/simulator_config.ts` solo si hace falta una variable no sensible.

Archivos nuevos sugeridos:

- `functions/src/simulator/treatment_profiles.ts`
- `functions/src/simulator/build_dental_treatment_prompt.ts`

## Contrato backend nuevo

Extender `GenerateSmileSimulationData`:

```ts
export type GenerateSmileSimulationData = {
  patientId?: string;
  simulationId?: string;
  treatmentType?: string; // legacy
  treatmentProfileId?: string;
  visualGoal?: string;
  doctorConfig?: Record<string, unknown>;
  photoQuality?: Record<string, unknown>;
  notes?: string;
};
```

## Perfiles requeridos

Crear IDs canonicos:

```text
metal_braces
esthetic_braces
clear_aligners
whitening
veneers
smile_design
palatal_expander
retainer
```

Cada perfil debe definir:

- label legible;
- objetivos visuales permitidos;
- configuracion por defecto;
- instrucciones positivas;
- instrucciones negativas;
- restricciones de foto;
- fallback seguro.

## Reglas visuales por perfil

### `metal_braces`

Debe pedir:

- brackets metalicos visibles sobre dientes;
- arco metalico;
- ligas si `doctorConfig.ligatureColor` existe;
- no blanquear como objetivo principal.

Debe prohibir:

- alineadores;
- brackets transparentes;
- cambio fuerte de forma dental.

### `esthetic_braces`

Debe pedir:

- brackets ceramicos o zafiro;
- apariencia clara/translucida;
- arco discreto si aplica.

Debe prohibir:

- metal dominante;
- alineadores invisibles.

### `clear_aligners`

Debe pedir:

- cubeta transparente;
- brillo plastico sutil;
- bordes suaves;
- attachments si aplica.

Debe prohibir:

- brackets;
- blanqueamiento exagerado.

### `whitening`

Debe pedir:

- cambio de tono dental natural;
- conservar forma, posicion y tamano.

Debe prohibir:

- carillas;
- aparatos;
- dientes artificiales.

### `veneers`

Debe pedir:

- cambio controlado de forma;
- borde incisal armonizado;
- tono segun configuracion;
- simetria anterior.

Debe prohibir:

- brackets;
- alineadores;
- encia o labios alterados agresivamente.

### `smile_design`

Debe pedir:

- resultado final ideal sin aparatos;
- alineacion y armonia dental;
- tono natural claro.

Debe prohibir:

- cualquier aparato visible;
- sonrisa artificial.

### `palatal_expander`

Debe pedir:

- expansor palatino solo si la foto permite verlo;
- aparato superior tipo Hyrax/Haas/removible segun configuracion.

Debe prohibir:

- inventar paladar si no se ve;
- poner expansor sobre dientes frontales como brackets.

### `retainer`

Debe pedir:

- tipo Essix, Hawley o fijo lingual segun config;
- visibilidad realista segun foto.

Debe prohibir:

- brackets;
- alineadores si el tipo no es Essix;
- mostrar retenedor fijo lingual si la foto no lo permite.

## Funcion de resolucion de perfil

Implementar:

```ts
export function resolveTreatmentProfile(
  treatmentProfileId?: string,
  legacyTreatmentType?: string,
): TreatmentPromptProfile
```

Fallbacks recomendados:

- `alineadores` -> `clear_aligners`
- `retenedores` -> `retainer`
- `estetico` -> `esthetic_braces`
- `convencional` -> `metal_braces`
- `autoligado` -> `metal_braces`
- `ortopedia` -> `palatal_expander` solo si el objetivo/foto lo permite; si no, usar `smile_design` o pedir config explicita.
- desconocido -> `smile_design`

## Prompt builder

Crear `buildDentalTreatmentPrompt(input)` que devuelva:

```ts
{
  promptUsed: string;
  promptVersion: 'ocg-dental-treatment-v2';
  treatmentProfileId: string;
}
```

Estructura del prompt:

```text
1. Instrucciones base de preservacion de identidad
2. Perfil de tratamiento
3. Parametros del doctor
4. Instrucciones negativas
5. Restricciones clinicas de simulacion orientativa
6. Notas complementarias del doctor
```

La nota del doctor nunca debe reemplazar el perfil.

## Actualizacion del core

En `generate_smile_simulation_core.ts`:

- Leer `treatmentProfileId`, `visualGoal`, `doctorConfig`, `photoQuality`.
- Resolver perfil.
- Construir prompt v2.
- Guardar en Firestore:
  - `treatmentProfileId`
  - `visualGoal`
  - `doctorConfig`
  - `photoQuality`
  - `promptVersion`
  - `promptUsed`

Mantener compatibilidad:

- Si Flutter viejo solo manda `treatmentType`, debe seguir generando.

## Restricciones

- No cambiar `gpt-image-2`.
- No agregar otra IA.
- No meter API key en logs.
- No loguear prompt completo si puede incluir notas sensibles; si se loguea, que sea solo `promptVersion` y `treatmentProfileId`.
- No marcar `shared` desde backend.

## Validacion minima

Desde `ocg_proyect/functions`:

```bash
npm run build
```

Ademas, revisar manualmente que el prompt generado para cada perfil contenga palabras distintivas:

- metal braces: `metal brackets`, `archwire`
- esthetic braces: `ceramic` o `sapphire`
- aligners: `transparent aligner`
- whitening: `tooth shade`
- veneers: `veneers`
- smile design: `no visible appliances`
- palatal expander: `palatal expander`
- retainer: `retainer`

## Criterios de cierre

- `npm run build` pasa.
- `generateSmileSimulation` acepta payload viejo y nuevo.
- Cada tratamiento genera un prompt claramente distinto.
- Firestore conserva `generationProvider = openai` y `modelUsed = gpt-image-2`.
- No se imprime ni expone la API key.

## Resultado esperado

La IA deja de recibir una instruccion generica y empieza a recibir una instruccion clinico-visual especifica por tratamiento.
