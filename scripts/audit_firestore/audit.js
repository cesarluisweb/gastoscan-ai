import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const ALLOWED_GASTO_KEYS = new Set([
  'uuid', 'fecha', 'comercio', 'moneda', 'total_original', 'total_usd',
  'total_usdt', 'total_eur', 'tasa_cambio', 'tasa_usdt', 'tasa_eur',
  'metodo_liquidacion', 'fuente_tasa_cambio', 'fecha_tasa_cambio',
  'categoria', 'items', 'creado_en', 'actualizado_en', 'eliminado_en',
  'ocr_text', 'synced',
]);

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const stats = {
  users: 0,
  gastos: 0,
  extraKeys: 0,
  uuidMismatch: 0,
  missingCore: 0,
  tasaUno: 0,
  negativeAmounts: 0,
  nonIsoFechaTasa: 0,
  presupuestos: 0,
  presupuestosBadId: 0,
  extraKeyNames: {},
  presupuestoBadIdTypes: {},
};

const isoRe = /^\d{4}-\d{2}-\d{2}$/;
const pidRe = /^\d{4}_\d{2}$/;

const usersSnap = await db.collection('users').listDocuments();
stats.users = usersSnap.length;

for (const userRef of usersSnap) {
  const gastosSnap = await userRef.collection('gastos').get();
  for (const docSnap of gastosSnap.docs) {
    stats.gastos++;
    const d = docSnap.data();
    const extra = Object.keys(d).filter((k) => !ALLOWED_GASTO_KEYS.has(k));
    if (extra.length > 0) {
      stats.extraKeys++;
      for (const k of extra) {
        stats.extraKeyNames[k] = (stats.extraKeyNames[k] || 0) + 1;
      }
    }
    if (d.uuid !== docSnap.id) stats.uuidMismatch++;
    if (!d.fecha || !d.creado_en || typeof d.total_usd !== 'number') stats.missingCore++;
    if (d.tasa_cambio === 1 || d.tasa_cambio === 1.0) stats.tasaUno++;
    if ((d.total_original ?? 0) < 0 || (d.total_usd ?? 0) < 0) stats.negativeAmounts++;
    if (typeof d.fecha_tasa_cambio === 'string' && !isoRe.test(d.fecha_tasa_cambio)) {
      stats.nonIsoFechaTasa++;
    }
  }

  const presSnap = await userRef.collection('presupuestos').get();
  for (const pSnap of presSnap.docs) {
    stats.presupuestos++;
    if (!pidRe.test(pSnap.id)) {
      stats.presupuestosBadId++;
      const kind = pSnap.id === 'user_settings'
        ? 'user_settings'
        : (/^\d{4}_\d$/.test(pSnap.id) ? 'YYYY_M' : `OTHER_LEN_${pSnap.id.length}`);
      stats.presupuestoBadIdTypes[kind] = (stats.presupuestoBadIdTypes[kind] || 0) + 1;
    }
  }
}

console.log(JSON.stringify({ ok: true, readOnly: true, stats }, null, 2));
