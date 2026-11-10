/// Mercados canónicos de tasas de cambio para Rinde Más.
enum RateMarket {
  usdOficial, // VES / USD (BCV)
  eurOficial, // VES / EUR (BCV)
  usdtP2p,    // VES / USDT (P2P / Paralelo)
}

/// Tres estados canónicos de disponibilidad de tasa por moneda (Decisión D-06).
enum EstadoTasaMoneda {
  actualizada, // Tasa viva validada de la fecha de hoy
  referencia,  // Tasa válida de fecha anterior o manual persistida offline
  sinTasa,     // Sin tasa disponible (<= 1.0, purga fallida o nunca registrada)
}

/// Identificador unívoco del origen y campo de una cotización de tasa.
enum RateSourceId {
  // Mercado USD Oficial (VES/USD)
  gatewayUsdOficial,   // Cloudflare Worker: campo 'usd' / 'bcv'
  dolarApiUsdOficial,  // ve.dolarapi.com/v1/dolares/oficial -> 'promedio'
  yadioUsdOficial,     // api.yadio.io/exrates/ves -> 'VES.official'
  jsdelivrUsd,         // fawazahmed0 currency-api -> usd.json['usd']['ves']

  // Mercado EUR Oficial (VES/EUR)
  gatewayEurOficial,   // Cloudflare Worker: campo 'eur'
  dolarApiEurOficial,  // ve.dolarapi.com/v1/euros/oficial -> 'promedio'
  jsdelivrEur,         // fawazahmed0 currency-api -> eur.json['eur']['ves']
  yadioEurRatio,       // api.yadio.io: official * (VES/EUR)

  // Mercado USDT P2P (VES/USDT)
  gatewayUsdtP2p,      // Cloudflare Worker: campo 'usdt' / 'paralelo'
  yadioUsdtP2p,        // api.yadio.io/exrates/ves -> 'VES.usd' o p2p_usdt
  dolarApiParalelo,    // ve.dolarapi.com/v1/dolares/paralelo -> 'promedio'

  // Ingreso manual explícito del usuario
  manualUsuario,
}

/// Retorna el conjunto de fuentes autorizadas para un mercado determinado.
Set<RateSourceId> allowedSourcesForMarket(RateMarket market) {
  switch (market) {
    case RateMarket.usdOficial:
      return const {
        RateSourceId.gatewayUsdOficial,
        RateSourceId.dolarApiUsdOficial,
        RateSourceId.yadioUsdOficial,
        RateSourceId.jsdelivrUsd,
        RateSourceId.manualUsuario,
      };
    case RateMarket.eurOficial:
      return const {
        RateSourceId.gatewayEurOficial,
        RateSourceId.dolarApiEurOficial,
        RateSourceId.jsdelivrEur,
        RateSourceId.yadioEurRatio,
        RateSourceId.manualUsuario,
      };
    case RateMarket.usdtP2p:
      return const {
        RateSourceId.gatewayUsdtP2p,
        RateSourceId.yadioUsdtP2p,
        RateSourceId.dolarApiParalelo,
        RateSourceId.manualUsuario,
      };
  }
}

/// Predicado canónico de validez numérica de tasa de cambio (Decisión D-08 / Contrato v1.2 §2.3).
///
/// Evalúa si [value] es de tipo [num], finito y estrictamente mayor que `1.0`.
///
/// Retorna `true` únicamente si cumple todas las condiciones:
/// - No nulo y de tipo `num` (int o double).
/// - Finito (`!value.isNaN` y `!value.isInfinite`).
/// - Estrictamente mayor que 1.0 (`value > 1.0`).
///
/// Valores menores o iguales a 1.0 (incluyendo 0.5, 1.0, 0.0 y negativos),
/// valores no finitos (NaN, Infinity, -Infinity) o tipos no numéricos
/// retornan `false`.
bool isValidMonetaryRate(dynamic value) {
  if (value is! num) return false;
  if (!value.isFinite) return false;
  return value > 1.0;
}

