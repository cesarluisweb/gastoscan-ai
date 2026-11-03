/// Modalidad de liquidación del gasto al momento de registrarse.
enum MetodoLiquidacion {
  /// Pago directo en divisa dura (efectivo, Zelle, etc.) o Bolívares directos en VES.
  divisa,

  /// Pago en Bolívares (VES) indexado al valor oficial del BCV.
  bsBcv,

  /// Pago en Bolívares (VES) indexado al valor P2P / paralelo de USDT.
  bsUsdt,
}
