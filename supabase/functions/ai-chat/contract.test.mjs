import assert from 'node:assert/strict';
import { readFile, writeFile, mkdtemp } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { join, dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

// Ejecutable con Node >= 22. Sin llamadas a red ni lectura de secretos.
export async function runContractTests(
  base = dirname(fileURLToPath(import.meta.url)),
) {
  let count = 0;
  const testAssert = (actual, expected, message) => {
    assert.equal(actual, expected, message);
    count++;
  };

  const temp = await mkdtemp(join(tmpdir(), 'fitbody-contract-'));
  const source = await readFile(join(base, 'contract.ts'), 'utf8');
  await writeFile(join(temp, 'contract.mjs'), stripTypeScriptTypes(source));
  const { sanitizeResponse } = await import(
    pathToFileURL(join(temp, 'contract.mjs')).href
  );
  const catalog = JSON.parse(
    await readFile(join(base, 'catalog.json'), 'utf8'),
  );
  const index = stripTypeScriptTypes(
    await readFile(join(base, 'index.ts'), 'utf8'),
  )
    .replace(
      "import trainingCatalog from './catalog.json' with { type: 'json' };",
      'const trainingCatalog = ' + JSON.stringify(catalog) + ';',
    )
    .replace("from './contract.ts'", "from './contract.mjs'");
  await writeFile(join(temp, 'index.mjs'), index);
  let handler;
  const original = globalThis.Deno;
  globalThis.Deno = {
    serve: (callback) => {
      handler = callback;
    },
    env: {
      get: () => {
        throw new Error('No se leen variables de entorno en pruebas.');
      },
    },
  };
  try {
    await import(pathToFileURL(join(temp, 'index.mjs')).href);
  } finally {
    globalThis.Deno = original;
  }
  testAssert(typeof handler, 'function', 'Deno handler exportado');
  const action = {
    type: 'propose_workout',
    reply: 'Propuesta',
    payload: {
      expectedVersion: 0,
      expectedPlanId: null,
      plan: {
        id: 'plan_test',
        name: 'Prueba',
        goal: 'Fuerza',
        version: 1,
        createdAt: '2026-09-18T00:00:00Z',
        block: 1,
        week: 1,
        plannedMinutes: 30,
        changeReason: 'Inicial',
        days: [
          {
            dayNumber: 1,
            title: 'Día 1',
            focus: 'General',
            exercises: [
              {
                id: 'dumbbell_row',
                sets: 2,
                restSeconds: 60,
                targetMin: 10,
                targetMax: 12,
                targetRir: 2,
              },
            ],
          },
        ],
      },
    },
  };
  const check = (a, profile = null, current = null) =>
    sanitizeResponse(JSON.stringify(a), catalog, current, profile);
  testAssert(check(action).type, 'propose_workout');
  testAssert(
    check(action).payload.plan.days[0].exercises[0].movementPattern,
    'horizontal_pull',
  );
  for (const [field, value] of [
    ['id', 'unknown'],
    ['sets', 99],
    ['restSeconds', 999],
    ['targetRir', 7],
    ['targetMin', -1],
  ]) {
    const invalid = structuredClone(action);
    invalid.payload.plan.days[0].exercises[0][field] = value;
    testAssert(check(invalid).type, 'answer');
  }
  const duplicate = structuredClone(action);
  duplicate.payload.plan.days[0].exercises.push(
    duplicate.payload.plan.days[0].exercises[0],
  );
  testAssert(check(duplicate).type, 'answer');
  const stale = structuredClone(action);
  stale.payload.expectedVersion = 2;
  testAssert(check(stale).type, 'answer');
  const knee = structuredClone(action);
  knee.payload.plan.days[0].exercises[0].id = 'goblet_squat';
  testAssert(
    check(knee, {
      daysPerWeek: 2,
      minutesPerSession: 30,
      limitations: 'rodilla',
    }).type,
    'answer',
  );

  // Parity Tests
  // 1. Mancuernas + preferencia sin mancuernas -> rechaza
  testAssert(
    check(action, {
      daysPerWeek: 2,
      minutesPerSession: 30,
      preferences: 'sin mancuernas',
    }).type,
    'answer',
    'Rechaza mancuerna con preferencia sin mancuernas',
  );

  // 2. Máquina + preferencia sin máquinas -> rechaza
  const machineAction = structuredClone(action);
  machineAction.payload.plan.days[0].exercises[0].id = 'lat_pulldown';
  testAssert(
    check(machineAction, {
      daysPerWeek: 2,
      minutesPerSession: 30,
      preferences: 'sin maquinas',
    }).type,
    'answer',
    'Rechaza máquina con preferencia sin máquinas',
  );

  // 3. Aire libre + sin equipo -> rechaza mancuerna, acepta bodyweight
  testAssert(
    check(action, {
      daysPerWeek: 2,
      minutesPerSession: 30,
      trainingLocation: 'Aire libre',
      equipment: 'Sin equipo',
    }).type,
    'answer',
    'Rechaza mancuerna al aire libre sin equipo',
  );
  const bwAction = structuredClone(action);
  bwAction.payload.plan.days[0].exercises[0].id = 'calf_raise';
  testAssert(
    check(bwAction, {
      daysPerWeek: 2,
      minutesPerSession: 30,
      trainingLocation: 'Aire libre',
      equipment: 'Sin equipo',
    }).type,
    'propose_workout',
    'Acepta bodyweight al aire libre sin equipo',
  );

  // 4. Casa con equipamiento incompatible (máquina en casa con mancuernas) -> rechaza
  testAssert(
    check(machineAction, {
      daysPerWeek: 2,
      minutesPerSession: 30,
      trainingLocation: 'Casa',
      equipment: 'Mancuernas y bandas',
    }).type,
    'answer',
    'Rechaza máquina en casa',
  );

  testAssert(
    sanitizeResponse('{broken', catalog, null, null).type,
    'answer',
  );
  testAssert(
    sanitizeResponse('Hola', catalog, null, null).reply,
    'Hola',
  );

  return `${count} comprobaciones de contrato y sintaxis TypeScript correctas`;
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  runContractTests()
    .then((summary) => {
      console.log(summary);
      process.exit(0);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
