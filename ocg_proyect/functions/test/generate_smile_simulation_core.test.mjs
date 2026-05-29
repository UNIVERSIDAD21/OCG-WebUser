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
  assert.equal(sim.resultPath, 'simulations/p1/s1/attempts/attempt_1/result.jpg');
  assert.equal(sim.activeResultPath, 'simulations/p1/s1/result.jpg');
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
  assert.equal(sim.promptVersion, 'ocg-dental-treatment-v3');
});

test('flujo legacy de retenedores usa prompt Essix visible por defecto', async () => {
  const d = deps({seed: baseSeed({treatmentType: 'retenedores'})});
  await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    treatmentType: 'retenedores',
  });

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.treatmentProfileId, 'retainer');
  assert.match(sim.promptUsed, /Essix retainer tray/);
  assert.match(sim.promptUsed, /visible tray edges/);
  assert.match(sim.promptUsed, /clearly show that a retainer appliance is present/);
});

test('treatmentType desconocido usa carillas como fallback', async () => {
  const d = deps({seed: baseSeed({treatmentType: 'desconocido'})});
  await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    treatmentType: 'desconocido',
  });

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.treatmentProfileId, 'carillas');
});

test('prompt de metal_braces contiene palabras clave distintivas', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'metal_braces',
  });
  assert.match(result.promptUsed, /metal/);
  assert.match(result.promptUsed, /brackets/);
  assert.match(result.promptUsed, /archwire/);
  assert.equal(result.promptVersion, 'ocg-dental-treatment-v3');
  assert.equal(result.treatmentProfileId, 'metal_braces');
});

test('prompt de esthetic_braces contiene brackets discretos', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'esthetic_braces',
  });
  assert.match(result.promptUsed, /ceramic|bracket/i);
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

test('prompt de limpieza_oral conserva dientes y solo limpia superficies', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'limpieza_oral',
  });
  assert.match(result.promptUsed, /plaque|calculus|superficial/i);
  assert.match(result.promptUsed, /same shape, size, alignment/i);
  assert.match(result.promptUsed, /Do NOT whiten teeth/i);
  assert.match(result.promptUsed, /Do NOT change tooth shape, position, size/i);
});

test('prompt de blanqueamiento contiene tooth shade', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'blanqueamiento',
  });
  assert.match(result.promptUsed, /shade/i);
  assert.match(result.promptUsed, /lighten/i);
  // Positive part should NOT mention brackets
  const posEnd = result.promptUsed.indexOf('Do NOT');
  const positivePart = posEnd > 0 ? result.promptUsed.slice(0, posEnd) : result.promptUsed;
  assert.doesNotMatch(positivePart, /brackets/);
});

test('prompt de carillas contiene veneers', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'carillas',
  });
  assert.match(result.promptUsed, /veneer/i);
  assert.match(result.promptUsed, /shape/i);
  // Positive part should NOT mention brackets or aligners
  const posEnd = result.promptUsed.indexOf('Do NOT');
  const positivePart = posEnd > 0 ? result.promptUsed.slice(0, posEnd) : result.promptUsed;
  assert.doesNotMatch(positivePart, /brackets|aligner/);
});

test('prompt de bordes_incisales contiene incisal edges', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'bordes_incisales',
  });
  assert.match(result.promptUsed, /incisal edges/i);
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
  assert.match(result.promptUsed, /Essix retainer tray/);
  assert.match(result.promptUsed, /visible tray edges/);
  assert.match(result.promptUsed, /Do not output a normal unchanged smile/);
  assert.match(result.promptUsed, /clearly show that a retainer appliance is present/);
});

test('doctorConfig se convierte en instrucciones en el prompt', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'metal_braces',
    doctorConfig: {
      ligatureColor: 'azul',
      arcada: 'superior',
    },
  });
  assert.match(result.promptUsed, /blue|azul/);
  assert.match(result.promptUsed, /upper teeth only|superior/);
});

test('notas del doctor se incluyen sin reemplazar el perfil', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'blanqueamiento',
    notes: 'El paciente tiene sensibilidad dental previa',
  });
  assert.match(result.promptUsed, /sensibilidad dental/);
  // Must still contain whitening instructions
  assert.match(result.promptUsed, /shade/);
});

test('payload con treatmentProfileId inválido usa carillas', () => {
  const result = buildDentalTreatmentPrompt({
    treatmentProfileId: 'perfil_inventado',
  });
  assert.equal(result.treatmentProfileId, 'carillas');
});

test('prompts son distintos entre sí — no colisionan palabras clave', () => {
  const profiles = [
    'reconstruccion',
    'limpieza_oral',
    'reemplazo_dental',
    'implantes_dentales',
    'bordes_incisales',
    'gingivectomia',
    'gingivoplastia',
    'alineacion_margenes',
    'metal_braces',
    'esthetic_braces',
    'clear_aligners',
    'blanqueamiento',
    'carillas',
    'palatal_expander',
    'retainer',
  ];

  const prompts = profiles.map(id =>
    buildDentalTreatmentPrompt({treatmentProfileId: id}).promptUsed,
  );

  // All prompts must be different strings
  const unique = new Set(prompts);
  assert.equal(unique.size, 15, 'Cada perfil debe producir un prompt único');
});

// ── Bloque 04: Photo quality / preflight tests ──────────

test('backend rechaza photoQuality.status = rejected', async () => {
  const d = deps();
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {
      patientId: 'p1',
      simulationId: 's1',
      photoQuality: {
        status: 'rejected',
        score: 0,
        warnings: [],
        blockingReasons: ['No se detectó un rostro.'],
        metadata: {hasFace: false},
      },
    }),
    /no es apta/,
  );
  // El status no debe haber cambiado a generating
  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.status, 'draft');
  assert.equal(d.calls.openAi, 0);
});

test('backend rechaza palatal_expander con photoType frontal_smile', async () => {
  const d = deps();
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {
      patientId: 'p1',
      simulationId: 's1',
      treatmentProfileId: 'palatal_expander',
      photoQuality: {
        status: 'valid',
        score: 0.9,
        warnings: [],
        blockingReasons: [],
        metadata: {hasFace: true, photoType: 'frontal_smile'},
      },
    }),
    /intraoral superior/,
  );
  assert.equal(d.calls.openAi, 0);
});

test('photoQuality usable_with_warning permite generar', async () => {
  const d = deps();
  const result = await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    photoQuality: {
      status: 'usable_with_warning',
      score: 0.72,
      warnings: ['La imagen tiene baja resolución.'],
      blockingReasons: [],
      metadata: {hasFace: true},
    },
  });

  assert.equal(result.status, 'ready');
  assert.equal(d.calls.openAi, 1);
});

test('photoQuality válida permite generar normalmente', async () => {
  const d = deps();
  const result = await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    photoQuality: {
      status: 'valid',
      score: 1.0,
      warnings: [],
      blockingReasons: [],
      metadata: {hasFace: true},
    },
  });

  assert.equal(result.status, 'ready');
  assert.equal(d.calls.openAi, 1);
});

// ── Bloque 05: Attempts and doctor review ───────────────

test('generación exitosa crea attempt con status ready', async () => {
  const d = deps();
  const result = await processGenerateSmileSimulation(d.value, {
    patientId: 'p1',
    simulationId: 's1',
    treatmentProfileId: 'metal_braces',
  });

  // Main doc updated
  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.status, 'ready');
  assert.equal(sim.resultPath, 'simulations/p1/s1/attempts/attempt_1/result.jpg');
  assert.equal(sim.activeResultPath, 'simulations/p1/s1/result.jpg');
  assert.equal(sim.doctorReviewStatus, 'pending');
  assert.equal(sim.approvedAttemptId, null);
  assert.equal(sim.attemptCount, 1);

  // Attempt doc created
  const attempt = d.db.store.get('patients/p1/simulations/s1/attempts/attempt_1');
  assert.ok(attempt, 'attempt debe existir');
  assert.equal(attempt.status, 'ready');
  assert.equal(attempt.attemptNumber, 1);
  assert.equal(attempt.treatmentProfileId, 'metal_braces');
  assert.equal(attempt.generationProvider, 'openai');
  assert.equal(attempt.modelUsed, 'gpt-image-2');
  assert.equal(attempt.reviewStatus, 'pending');

  // Result saved to both paths
  assert.ok(d.db.store.get('storage:simulations/p1/s1/result.jpg'));
  assert.ok(d.db.store.get('storage:simulations/p1/s1/attempts/attempt_1/result.jpg'));
});

test('fallo de OpenAI marca attempt y simulation como failed', async () => {
  const d = deps();
  d.value.createOpenAiClient = () => ({
    generateEditedImage: async () => { throw new Error('timeout'); },
  });

  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {patientId: 'p1', simulationId: 's1'}),
  );

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.status, 'failed');
  assert.equal(sim.attemptCount, 1);

  const attempt = d.db.store.get('patients/p1/simulations/s1/attempts/attempt_1');
  assert.ok(attempt);
  assert.equal(attempt.status, 'failed');
  assert.ok(attempt.errorMessage && attempt.errorMessage.length > 0);
});

test('preflight rejected no crea attempt ni incrementa count', async () => {
  const d = deps();
  await assert.rejects(
    () => processGenerateSmileSimulation(d.value, {
      patientId: 'p1',
      simulationId: 's1',
      photoQuality: {status: 'rejected', score: 0, warnings: [], blockingReasons: ['No apta'], metadata: {}},
    }),
    /no es apta/,
  );

  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.attemptCount, 0, 'attemptCount no debe incrementar en preflight');

  const attempt = d.db.store.get('patients/p1/simulations/s1/attempts/attempt_1');
  assert.ok(!attempt, 'no debe existir attempt cuando el preflight rechaza');
});

test('segundo intento crea attempt_2 y conserva attempt_1', async () => {
  const d = deps({seed: baseSeed({attemptCount: 1})});

  // Pre-seed attempt_1
  d.db.store.set('patients/p1/simulations/s1/attempts/attempt_1', {
    id: 'attempt_1', attemptNumber: 1, status: 'ready',
    resultPath: 'simulations/p1/s1/attempts/attempt_1/result.jpg',
    treatmentProfileId: 'metal_braces', generationProvider: 'openai',
    modelUsed: 'gpt-image-2', reviewStatus: 'approved',
  });

  const result = await processGenerateSmileSimulation(d.value, {
    patientId: 'p1', simulationId: 's1',
  });

  assert.equal(result.status, 'ready');

  // attempt_1 preserved
  const a1 = d.db.store.get('patients/p1/simulations/s1/attempts/attempt_1');
  assert.equal(a1.status, 'ready');
  assert.equal(a1.reviewStatus, 'approved');

  // attempt_2 created
  const a2 = d.db.store.get('patients/p1/simulations/s1/attempts/attempt_2');
  assert.equal(a2.status, 'ready');
  assert.equal(a2.attemptNumber, 2);
  assert.equal(a2.resultPath, 'simulations/p1/s1/attempts/attempt_2/result.jpg');

  // Main doc updated
  const sim = d.db.store.get('patients/p1/simulations/s1');
  assert.equal(sim.attemptCount, 2);
  assert.equal(sim.resultPath, 'simulations/p1/s1/attempts/attempt_2/result.jpg');
  assert.equal(sim.activeResultPath, 'simulations/p1/s1/result.jpg');
  assert.equal(sim.doctorReviewStatus, 'pending');
  assert.equal(sim.approvedAttemptId, null);
});
