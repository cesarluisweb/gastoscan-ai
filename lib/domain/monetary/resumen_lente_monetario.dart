import '../../data/models/gasto_model.dart';
import 'monetary_resolution.dart';

/// Agregador de lectura contable por lente sin mezclar totales verificados y no verificados.
class ResumenLenteMonetario {
  final String monedaLente;
  final int totalVerificadoOrigenCentavos; // Suma exclusiva de identidadOrigen
  final int totalNoVerificadoCentavos;     // Suma de persistidoNoVerificado + calculadoNoVerificado (solo VES)
  final int noVerificadosCount;            // Cantidad de gastos en persistidoNoVerificado o calculadoNoVerificado
  final int pendientesCount;               // Cantidad de gastos en EstadoValorMonetario.pendiente
  final int incoherentesCount;             // Cantidad de gastos en EstadoValorMonetario.incoherente

  const ResumenLenteMonetario({
    required this.monedaLente,
    this.totalVerificadoOrigenCentavos = 0,
    this.totalNoVerificadoCentavos = 0,
    this.noVerificadosCount = 0,
    this.pendientesCount = 0,
    this.incoherentesCount = 0,
  });

  int get totalMostradoCentavos =>
      totalVerificadoOrigenCentavos + totalNoVerificadoCentavos;

  double get totalVerificadoOrigenDisplay =>
      totalVerificadoOrigenCentavos / 100.0;

  double get totalNoVerificadoDisplay =>
      totalNoVerificadoCentavos / 100.0;

  double get totalMostradoDisplay =>
      totalMostradoCentavos / 100.0;

  bool get tieneAdvertenciaCalidad =>
      pendientesCount > 0 || incoherentesCount > 0;

  /// Agrega una lista de gastos para la lente dada separando montos verificados y no verificados.
  static ResumenLenteMonetario calcular({
    required String monedaLente,
    required Iterable<GastoModel> gastos,
  }) {
    int verificado = 0;
    int noVerificado = 0;
    int noVerificadosC = 0;
    int pendientesC = 0;
    int incoherentesC = 0;

    for (final g in gastos) {
      final res = resolvePersistedExpense(gasto: g, lente: monedaLente);
      switch (res.estado) {
        case EstadoValorMonetario.identidadOrigen:
          verificado += res.centavos ?? 0;
          break;
        case EstadoValorMonetario.persistidoNoVerificado:
        case EstadoValorMonetario.calculadoNoVerificado:
          noVerificado += res.centavos ?? 0;
          noVerificadosC++;
          break;
        case EstadoValorMonetario.pendiente:
          pendientesC++;
          break;
        case EstadoValorMonetario.incoherente:
          incoherentesC++;
          break;
      }
    }

    return ResumenLenteMonetario(
      monedaLente: monedaLente,
      totalVerificadoOrigenCentavos: verificado,
      totalNoVerificadoCentavos: noVerificado,
      noVerificadosCount: noVerificadosC,
      pendientesCount: pendientesC,
      incoherentesCount: incoherentesC,
    );
  }
}
