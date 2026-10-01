enum SavingsGoalStatus {
  sinMeta,
  protegida,
  enRiesgo,
  comprometida,
}

class SavingsHealthSnapshot {
  final double presupuestoGeneral;
  final double metaAhorro;
  final double limiteParaGastar;
  final double gastoAcumulado;
  final double disponibleParaGastar;
  final int diasTranscurridos;
  final int diasTotalesMes;
  final double gastoDiarioPromedio;
  final double gastoProyectadoFinDeMes;
  final SavingsGoalStatus status;
  final String moneda;

  const SavingsHealthSnapshot({
    required this.presupuestoGeneral,
    required this.metaAhorro,
    required this.limiteParaGastar,
    required this.gastoAcumulado,
    required this.disponibleParaGastar,
    required this.diasTranscurridos,
    required this.diasTotalesMes,
    required this.gastoDiarioPromedio,
    required this.gastoProyectadoFinDeMes,
    required this.status,
    this.moneda = 'USD',
  });

  bool get tieneMeta => metaAhorro > 0;

  double get porcentajeConsumido {
    if (limiteParaGastar <= 0) return 0.0;
    return (gastoAcumulado / limiteParaGastar).clamp(0.0, 1.0);
  }

  double get porcentajeReal {
    if (limiteParaGastar <= 0) return 0.0;
    return gastoAcumulado / limiteParaGastar;
  }
}
