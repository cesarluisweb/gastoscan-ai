export function gastoFlutterValido(uuid = 'gasto-1') {
  return {
    uuid,
    fecha: '2026-11-13',
    comercio: 'Automercado Plaza',
    moneda: 'VES',
    total_original: 125000,
    total_usd: 2500,
    total_usdt: 2450,
    total_eur: 2300,
    tasa_cambio: 50.0,
    tasa_usdt: 51.0,
    tasa_eur: 54.3,
    fuente_tasa_cambio: 'BCV',
    fecha_tasa_cambio: '2026-11-13',
    categoria: 'Alimentación',
    items: [
      {
        descripcion: 'Harina PAN',
        cantidad: 2,
        precio_unitario: 62500,
        total: 125000,
        categoria: 'Alimentación',
      },
    ],
    creado_en: '2026-11-13T10:00:00.000Z',
    actualizado_en: '2026-11-13T10:00:00.000Z',
  };
}

export function gastoPanelValido(uuid = 'gasto-web-1') {
  return {
    uuid,
    fecha: '2026-11-13',
    comercio: 'Farmatodo',
    moneda: 'VES',
    total_original: Math.round(12.345 * 100), // 1235 (int)
    total_usd: 2500,
    total_usdt: 2450,
    total_eur: 2300,
    tasa_cambio: 36.5,
    tasa_usdt: 38.0,
    tasa_eur: 40.0,
    metodo_liquidacion: null,
    fuente_tasa_cambio: 'BCV',
    fecha_tasa_cambio: 'Hoy',
    categoria: 'Salud',
    items: [],
    creado_en: '2026-11-13T12:00:00.000Z',
    actualizado_en: '2026-11-13T12:00:00.000Z',
    synced: 1,
  };
}

export function presupuestoValido() {
  return {
    anio: 2026,
    mes: 11,
    presupuesto_general: 500,
    meta_ahorro: 100.5,
    moneda: 'USD',
    categorias: {
      'Alimentación': 250,
      'Transporte': 80,
    },
    actualizado_en: '2026-11-13T10:00:00.000Z',
  };
}
