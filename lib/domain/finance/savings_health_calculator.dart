import 'savings_health_models.dart';

class SavingsHealthCalculator {
  static SavingsHealthSnapshot calculate({
    required double presupuestoGeneral,
    required double metaAhorro,
    required double gastoAcumulado,
    required int diaActual,
    required int diasTotalesMes,
    String moneda = 'USD',
    int diasGraciaInicioMes = 3,
  }) {
    final gen = presupuestoGeneral >= 0 ? presupuestoGeneral : 0.0;
    final metaClamped = metaAhorro >= 0 ? (metaAhorro > gen ? gen : metaAhorro) : 0.0;
    final limite = (gen - metaClamped).clamp(0.0, double.infinity);
    final gasto = gastoAcumulado >= 0 ? gastoAcumulado : 0.0;
    final disponible = (limite - gasto).clamp(0.0, double.infinity);

    final totalDias = diasTotalesMes > 0 ? diasTotalesMes : 30;
    final diasValidos = diaActual.clamp(1, totalDias);

    final gastoDiario = diasValidos > 0 ? (gasto / diasValidos) : 0.0;
    final gastoProyectado = gastoDiario * totalDias;

    SavingsGoalStatus status;
    if (metaClamped <= 0) {
      status = SavingsGoalStatus.sinMeta;
    } else if (gasto > limite) {
      status = SavingsGoalStatus.comprometida;
    } else if (diasValidos <= diasGraciaInicioMes) {
      // Periodo de gracia para evitar falsas alarmas por compras de inicio de mes
      status = SavingsGoalStatus.protegida;
    } else if (gastoProyectado > limite) {
      status = SavingsGoalStatus.enRiesgo;
    } else {
      status = SavingsGoalStatus.protegida;
    }

    return SavingsHealthSnapshot(
      presupuestoGeneral: gen,
      metaAhorro: metaClamped,
      limiteParaGastar: limite,
      gastoAcumulado: gasto,
      disponibleParaGastar: disponible,
      diasTranscurridos: diasValidos,
      diasTotalesMes: totalDias,
      gastoDiarioPromedio: gastoDiario,
      gastoProyectadoFinDeMes: gastoProyectado,
      status: status,
      moneda: moneda,
    );
  }
}
