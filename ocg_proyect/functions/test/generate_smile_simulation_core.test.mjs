import test from 'node:test';
import assert from 'node:assert/strict';

import {processGenerateSmileSimulation} from '../lib/simulator/generate_smile_simulation_core.js';
import {buildDentalTreatmentPrompt} from '../lib/simulator/build_dental_treatment_prompt.js';

// ── Mock Firestore ──────────────────────────────────────

class MockDocSnapshot {
  constructor(path, data) {
    this.path = path;
    this._data = data;
    this.exists = data !== undefined;
  }
  data() { return this._data; }
}
class MockDocRef {
  constructor(db, path) { this.db = db; this.path = path; }
  collection(name) { return new MockCollectionRef(this.db, `${this.path}/${name}`); }
  async get() { return new MockDocSnapshot(this.path, this.db.store.get(this.path)); }
  async set(data, options = {}) {
    const material = materialize(data);
    const prev = this.db.store.get(this.path);
    this.db.store.set(this.path, options.merge && prev ? deepMerge(prev, material) : material);
  }
}
class MockCollectionRef {
  constructor(db, path) { this.db = db; this.path = path; }
  doc(id) { return new MockDocRef(this.db, `${this.path}/${id}`); }
}
class MockFirestore {
  constructor(seed = {}) { this.store = new Map(Object.entries(seed)); }
  collection(path) { return new MockCollectionRef(this, path); }
}
function materialize(value) {
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = typeof v === 'function' ? '[FieldValue]' : materialize(v);
    return out;
  }
  return value;
}
function deepMerge(a, b) {
  const out = {...a};
  for (const [k, v] of Object.entries(b)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && a[k] && typeof a[k] === 'object' && !Array.isArray(a[k])) out[k] = deepMerge(a[k], v);
    else out[k] = v;
  }
  return out;
}
function baseConfig(overrides = {}) {
  return {
    openAiApiKey: 'sk-test',
    openAiImageModel: 'gpt-image-2',
    openAiImageQuality: 'medium',
    openAiImageSize: '1024x1024',
    aiSimulatorEnabled: true,
    maxSimulationAttempts: 3,
    ...overrides,
  };
}
function baseSeed(overrides = {}) {
  return {
    'patients/p1': {id: 'p1', nombre: 'Paciente Demo'},
    'patients/p1/simulations/s1': {
      id: 's1',
      patientId: 'p1',
      originalPath: 'simulations/p1/s1/original.jpg',
      status: 'draft',
      notes: 'demo',
      treatmentType: 'convencional',
      attemptCount: 0,
      generationProvider: 'openai',
      modelUsed: 'gpt-image-2',
      ...overrides,
    },
  };
}
function deps({seed, config, auth, adminRole = null, downloadBytes, generatedBytes, downloadImpl} = {}) {
  const db = new MockFirestore(seed ?? baseSeed());
  const calls = {openAi: 0, downloadedPath: null};
  return {
    db,
    calls,
    value: {
      db,
      storage: {
        download: async (path) => {
          calls.downloadedPath = path;
          if (downloadImpl) return downloadImpl(path);
          return downloadBytes ?? Buffer.from('original');
        },
        save: async (path, bytes) => { db.store.set(`storage:${path}`, {bytes: bytes.toString('hex')}); },
      },
      config: config ?? baseConfig(),
      auth: auth ?? {uid: 'admin-1', role: 'admin'},
      loadAdminRole: async () => adminRole,
      createOpenAiClient: () => ({
        generateEditedImage: async () => {
          calls.openAi += 1;
          return generatedBytes ?? Buffer.from('result-image');
        },
      }),
    },
  };
}

// ── Existing tests ──────────────────────────────────────

test('simulación sin API KEY termina en error controlado', async () => {
  const d = deps({config: baseConfig({openAiApiKey: ''})});
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {patientId: 'p1', simulationId: 's1'}),
    /API KEY/,
  );
  assert.equal(d.db.store.get('patients/p1/simulations/s1').status, 'draft');
  assert.equal(d.calls.openAi, 0);
});

test('simulador deshabilitado no intenta llamar OpenAI', async () => {
  const d = deps({config: baseConfig({aiSimulatorEnabled: false})});
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {patientId: 'p1', simulationId: 's1'}),
    /desactivado/,
  );
  assert.equal(d.calls.openAi, 0);
});

test('simulación sin originalPath falla con error claro', async () => {
  const d = deps({seed: baseSeed({originalPath: ''})});
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {patientId: 'p1', simulationId: 's1'}),
    /originalPath/,
  );
});

test('intentos máximos superados bloquea generación', async () => {
  const d = deps({seed: baseSeed({attemptCount: 3})});
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {patientId: 'p1', simulationId: 's1'}),
    /máximo de intentos/,
  );
  assert.equal(d.calls.openAi, 0);
});

test('usuario no admin no puede generar', async () => {
  const d = deps({auth: {uid: 'patient-1'}});
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {patientId: 'p1', simulationId: 's1'}),
    /Solo administradores/,
  );
});

test('flujo exitoso mockeado guarda resultPath y deja status ready', async () => {
  const d = deps();
  const result = await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    treatmentType: 'convencional',
    notes: 'alineación estética',
  });

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(result.status, 'ready');
  assert.equal(sim.status, 'ready');
  assert.equal(sim.resultPath, 'simulations/p1/s1/result.jpg');
  assert.equal(sim.modelUsed, 'gpt-image-2');
  assert.equal(sim.generationProvider, 'openai');
  assert.ok(typeof sim.promptUsed === 'string' && sim.promptUsed.length > 0);
  assert.ok(typeof sim.promptVersion === 'string' && sim.promptVersion.length > 0);
  assert.equal(d.calls.downloadedPath, 'simulations/p1/s1/original.jpg');
  assert.equal(d.calls.openAi, 1);
});

test('descarga desde originalPath guardado y no reconstruye otra ruta', async () => {
  const d = deps({
    seed: baseSeed({
      originalPath: 'simulations/p1/storage-id-distinto/original.jpg',
    }),
  });

  await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
  });

  assert.equal(d.calls.downloadedPath, 'simulations/p1/storage-id-distinto/original.jpg');
});

test('si storage download devuelve not found la simulación queda failed con mensaje amigable', async () => {
  const d = deps({
    downloadImpl: async () => {
      throw new Error('No such object: simulations/p1/s1/original.jpg');
    },
  });

  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {patientId: 'p1', simulationId: 's1'}),
    /No se encontró la imagen original de esta simulación/,
  );

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.status, 'failed');
  assert.equal(
    sim.errorMessage,
    'No se encontró la imagen original de esta simulación. Toma la foto nuevamente o crea una nueva simulación.',
  );
});

test('si OpenAI falla, la simulación termina en failed con mensaje seguro', async () => {
  const d = deps();
  d.value.createOpenAiClient = () => ({
    generateEditedImage: async () => { throw new Error('OPENAI_API_KEY=secreta rota y stack interno muy largo'); },
  });
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {patientId: 'p1', simulationId: 's1'}),
    /API KEY/,
  );
  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.status, 'failed');
  assert.match(sim.errorMessage, /API KEY/);
  assert.doesNotMatch(sim.errorMessage, /secreta/);
});

// ── New tests: Bloque 02 — Treatment profiles ───────────

test('flujo con treatmentProfileId guarda el perfil en Firestore', async () => {
  const d = deps();
  await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    treatmentProfileId: 'metal_braces',
    visualGoal: 'show_appliance',
    doctorConfig: {ligatureColor: 'gris', arcada: 'superior'},
    photoQuality: {status: 'valid', score: 0.9},
  });

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.status, 'ready');
  assert.equal(sim.treatmentProfileId, 'metal_braces');
  assert.equal(sim.visualGoal, 'show_appliance');
  assert.equal(sim.doctorConfig.ligatureColor, 'gris');
  assert.equal(sim.photoQuality.status, 'valid');
  assert.equal(sim.generationProvider, 'openai');
  assert.equal(sim.modelUsed, 'gpt-image-2');
});

test('flujo legacy sin treatmentProfileId infiere perfil desde treatmentType', async () => {
  const d = deps({seed: baseSeed({treatmentType: 'alineadores'})});
  await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    treatmentType: 'alineadores',
  });

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.treatmentProfileId, 'clear_aligners');
  assert.equal(sim.promptVersion, 'ocg-dental-treatment-v2');
});

test('treatmentType desconocido usa smile_design como fallback', async () => {
  const d = deps({seed: baseSeed({treatmentType: 'desconocido'})});
  await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    treatmentType: 'desconocido',
  });

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.treatmentProfileId, 'smile_design');
});

test('prompt de metal_braces contiene palabras clave distintivas', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'metal_braces',
  });
  assert.match(result.promptUsed, /metal/);
  assert.match(result.promptUsed, /brackets/);
  assert.match(result.promptUsed, /archwire/);
  assert.equal(result.promptVersion, 'ocg-dental-treatment-v2');
  assert.equal(result.treatmentProfileId, 'metal_braces');
});

test('prompt de esthetic_braces contiene ceramic/sapphire', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'esthetic_braces',
  });
  assert.match(result.promptUsed, /ceramic|sapphire/);
  // Positive instructions should NOT describe metal brackets
  const posEnd = result.promptUsed.indexOf('Do NOT');
  const positivePart = posEnd > 0 ? result.promptUsed.slice(0, posEnd) : result.promptUsed;
  assert.doesNotMatch(positivePart, /metal bracket/);
});

test('prompt de clear_aligners contiene aligner tray', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'clear_aligners',
  });
  assert.match(result.promptUsed, /aligner/);
  assert.match(result.promptUsed, /plastic|transparent/);
  assert.doesNotMatch(result.promptUsed, /metal brackets/);
});

test('prompt de whitening contiene tooth shade', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'whitening',
  });
  assert.match(result.promptUsed, /shade/i);
  assert.match(result.promptUsed, /lighten/i);
  // Positive part should NOT mention brackets
  const posEnd = result.promptUsed.indexOf('Do NOT');
  const positivePart = posEnd > 0 ? result.promptUsed.slice(0, posEnd) : result.promptUsed;
  assert.doesNotMatch(positivePart, /brackets/);
});

test('prompt de veneers contiene veneers', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'veneers',
  });
  assert.match(result.promptUsed, /veneer/i);
  assert.match(result.promptUsed, /shape/i);
  // Positive part should NOT mention brackets or aligners
  const posEnd = result.promptUsed.indexOf('Do NOT');
  const positivePart = posEnd > 0 ? result.promptUsed.slice(0, posEnd) : result.promptUsed;
  assert.doesNotMatch(positivePart, /brackets|aligner/);
});

test('prompt de smile_design contiene no visible appliances', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'smile_design',
  });
  assert.match(result.promptUsed, /no.*brackets|no.*appliance|no.*aligner/);
  assert.doesNotMatch(result.promptUsed, /metal brackets/);
});

test('prompt de palatal_expander contiene palatal expander', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'palatal_expander',
  });
  assert.match(result.promptUsed, /palatal expander/);
  assert.match(result.promptUsed, /Hyrax|Haas/);
});

test('prompt de retainer contiene retainer', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'retainer',
  });
  assert.match(result.promptUsed, /retainer/);
  assert.match(result.promptUsed, /Essix|Hawley|fixed/);
});

test('doctorConfig se convierte en instrucciones en el prompt', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'metal_braces',
    doctorConfig: {
      ligatureColor: 'azul',
      arcada: 'superior',
    },
  });
  assert.match(result.promptUsed, /azul/);
  assert.match(result.promptUsed, /superior/);
});

test('notas del doctor se incluyen sin reemplazar el perfil', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'whitening',
    notes: 'El paciente tiene sensibilidad dental previa',
  });
  assert.match(result.promptUsed, /sensibilidad dental/);
  // Must still contain whitening instructions
  assert.match(result.promptUsed, /shade/);
});

test('payload con treatmentProfileId inválido usa smile_design', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'perfil_inventado',
  });
  assert.equal(result.treatmentProfileId, 'smile_design');
});

test('prompts son distintos entre sí — no colisionan palabras clave', () => {
  const profiles = [
    'metal_braces',
    'esthetic_braces',
    'clear_aligners',
    'whitening',
    'veneers',
    'smile_design',
    'palatal_expander',
    'retainer',
  ];

  const prompts = profiles.map(id =>
    buildDentalTreatmentPrompt({treatmentProfileId: id}).promptUsed,
  );

  // All prompts must be different strings
  const unique = new Set(prompts);
  assert.equal(unique.size, 8, 'Cada perfil debe producir un prompt único');
});
