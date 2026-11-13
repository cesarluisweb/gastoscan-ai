import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import { gastoFlutterValido, gastoPanelValido, presupuestoValido } from './fixtures.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RULES_PATH = resolve(__dirname, '../../firestore.rules');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-rindemas',
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('B1: Reglas de Firestore (RT-01..RT-24)', () => {
  it('RT-01: Dueño crea un gasto válido -> permitido', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertSucceeds(setDoc(doc(db, 'users/user-1/gastos/g1'), gastoFlutterValido('g1')));
  });

  it('RT-02: Otro uid intenta escribir -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-2').firestore();
    await assertFails(setDoc(doc(db, 'users/user-1/gastos/g1'), gastoFlutterValido('g1')));
  });

  it('RT-03: Sin autenticación -> denegado', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, 'users/user-1/gastos/g1'), gastoFlutterValido('g1')));
  });

  it('RT-04: Campo extra no listado en create -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertFails(
      setDoc(doc(db, 'users/user-1/gastos/g1'), {
        ...gastoFlutterValido('g1'),
        campo_extra: 'malicioso',
      }),
    );
  });

  it('RT-05: total_usd como texto -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertFails(
      setDoc(doc(db, 'users/user-1/gastos/g1'), {
        ...gastoFlutterValido('g1'),
        total_usd: '2500',
      }),
    );
  });

  it('RT-06: total_original negativo -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertFails(
      setDoc(doc(db, 'users/user-1/gastos/g1'), {
        ...gastoFlutterValido('g1'),
        total_original: -100,
      }),
    );
  });

  it('RT-07: ocr_text de 100001 caracteres en update -> denegado; 100000 -> permitido', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    const ref = doc(db, 'users/user-1/gastos/g1');
    await assertSucceeds(setDoc(ref, gastoFlutterValido('g1')));
    await assertFails(updateDoc(ref, { ocr_text: 'a'.repeat(100001) }));
    await assertSucceeds(updateDoc(ref, { ocr_text: 'a'.repeat(100000) }));
  });

  it('RT-08: items con 501 elementos -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    const tooMany = Array.from({ length: 501 }, (_, i) => ({ descripcion: `Item ${i}`, total: 100 }));
    await assertFails(
      setDoc(doc(db, 'users/user-1/gastos/g1'), {
        ...gastoFlutterValido('g1'),
        items: tooMany,
      }),
    );
  });

  it('RT-09: Borrado lógico set(merge) de 3 campos (Flutter) -> permitido', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    const ref = doc(db, 'users/user-1/gastos/g1');
    await assertSucceeds(setDoc(ref, gastoFlutterValido('g1')));
    await assertSucceeds(
      setDoc(
        ref,
        {
          uuid: 'g1',
          eliminado_en: '2026-11-13T15:00:00.000Z',
          actualizado_en: '2026-11-13T15:00:00.000Z',
        },
        { merge: true },
      ),
    );
  });

  it('RT-10: Borrado lógico updateDoc({eliminado_en}) (panel) -> permitido', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    const ref = doc(db, 'users/user-1/gastos/g1');
    await assertSucceeds(setDoc(ref, gastoPanelValido('g1')));
    await assertSucceeds(updateDoc(ref, { eliminado_en: '2026-11-13T15:00:00.000Z' }));
  });

  it('RT-11: uuid distinto del id del documento en create -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertFails(setDoc(doc(db, 'users/user-1/gastos/g1'), gastoFlutterValido('otro-id')));
  });

  it('RT-12: Presupuesto válido -> permitido', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertSucceeds(setDoc(doc(db, 'users/user-1/presupuestos/2026_11'), presupuestoValido()));
  });

  it('RT-13: Presupuesto mes = 13 -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertFails(
      setDoc(doc(db, 'users/user-1/presupuestos/2026_13'), {
        ...presupuestoValido(),
        mes: 13,
      }),
    );
  });

  it('RT-14: Presupuesto con clave de categoría inválida -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertFails(
      setDoc(doc(db, 'users/user-1/presupuestos/2026_11'), {
        ...presupuestoValido(),
        categorias: { Comida: 100 },
      }),
    );
  });

  it('RT-15: Presupuesto con presupuestoId fuera de YYYY_MM -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertFails(setDoc(doc(db, 'users/user-1/presupuestos/noviembre'), presupuestoValido()));
  });

  it('RT-16: /config/recordatorios lectura autenticada -> permitido; escritura -> denegado', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'config/recordatorios'), { mensajes: ['Hola'] });
    });
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertSucceeds(getDoc(doc(db, 'config/recordatorios')));
    await assertFails(setDoc(doc(db, 'config/recordatorios'), { mensajes: ['Hack'] }));
  });

  it('RT-17a..d: Payload real del panel, int vs float y tasas', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    // RT-17a: Math.round(12.345 * 100) -> 1235 (int) -> permitido
    await assertSucceeds(setDoc(doc(db, 'users/user-1/gastos/w1'), gastoPanelValido('w1')));
    // RT-17b: total_original decimal -> denegado
    await assertFails(
      setDoc(doc(db, 'users/user-1/gastos/w2'), {
        ...gastoPanelValido('w2'),
        total_original: 1234.5,
      }),
    );
    // RT-17c: tasa_cambio decimal 36.5 -> permitido (ya incluido en w1)
    // RT-17d: presupuesto_general int y float -> ambos permitidos
    await assertSucceeds(
      setDoc(doc(db, 'users/user-1/presupuestos/2026_10'), {
        ...presupuestoValido(),
        mes: 10,
        presupuesto_general: 500.75,
      }),
    );
  });

  it('RT-18: Edición de metadatos del panel -> permitido', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    const ref = doc(db, 'users/user-1/gastos/w1');
    await assertSucceeds(setDoc(ref, gastoPanelValido('w1')));
    await assertSucceeds(
      updateDoc(ref, {
        comercio: 'Farmatodo Las Mercedes',
        fecha: '2026-11-12',
        categoria: 'Higiene',
        items: [],
        actualizado_en: '2026-11-13T16:00:00.000Z',
      }),
    );
  });

  it('RT-19 y RT-20: Categoría con acento permitida; fuera de catálogo denegada', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users/user-1/gastos/g-edu'), {
        ...gastoFlutterValido('g-edu'),
        categoria: 'Educación',
      }),
    );
    await assertFails(
      setDoc(doc(db, 'users/user-1/gastos/g-bad'), {
        ...gastoFlutterValido('g-bad'),
        categoria: 'Comida',
      }),
    );
  });

  it('RT-21: Documento legacy con campo extra y sin creado_en permite actualizar comercio', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/user-1/gastos/legacy-1'), {
        uuid: 'legacy-1',
        fecha: '2025-05-01',
        comercio: 'Viejo Comercio',
        moneda: 'VES',
        total_original: 1000,
        total_usd: 25,
        tasa_cambio: 1.0,
        categoria: 'Otros',
        items: [],
        legacy_extra_field: 'antiguo',
      });
    });
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users/user-1/gastos/legacy-1'), {
        comercio: 'Comercio Actualizado',
      }),
    );
  });

  it('RT-22: Intento de cambiar creado_en -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    const ref = doc(db, 'users/user-1/gastos/g1');
    await assertSucceeds(setDoc(ref, gastoFlutterValido('g1')));
    await assertFails(updateDoc(ref, { creado_en: '2020-01-01T00:00:00.000Z' }));
  });

  it('RT-23: Intento de escribir uuid distinto en update -> denegado', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    const ref = doc(db, 'users/user-1/gastos/g1');
    await assertSucceeds(setDoc(ref, gastoFlutterValido('g1')));
    await assertFails(updateDoc(ref, { uuid: 'otro-uuid' }));
  });

  it('RT-24: tasa_cambio = 1.0 (legacy) reenviada por sync -> permitido', async () => {
    const db = testEnv.authenticatedContext('user-1').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users/user-1/gastos/g-leg'), {
        ...gastoFlutterValido('g-leg'),
        tasa_cambio: 1.0,
      }),
    );
  });
});
