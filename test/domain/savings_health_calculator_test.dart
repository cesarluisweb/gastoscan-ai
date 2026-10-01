import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/domain/finance/savings_health_models.dart';
import 'package:gastoscan_ai/domain/finance/savings_health_calculator.dart';

void main() {
  group('SavingsHealthCalculator Tests', () {
    test('returns sinMeta when metaAhorro is zero or negative', () {
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 500,
        metaAhorro: 0,
        gastoAcumulado: 100,
        diaActual: 10,
        diasTotalesMes: 30,
      );

      expect(snapshot.status, SavingsGoalStatus.sinMeta);
      expect(snapshot.tieneMeta, isFalse);
      expect(snapshot.limiteParaGastar, 500);
      expect(snapshot.disponibleParaGastar, 400);
    });

    test('calculates correct limiteParaGastar when metaAhorro is positive', () {
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 250,
        diaActual: 15,
        diasTotalesMes: 30,
      );

      expect(snapshot.limiteParaGastar, 400);
      expect(snapshot.metaAhorro, 100);
      expect(snapshot.disponibleParaGastar, 150);
      expect(snapshot.tieneMeta, isTrue);
    });

    test('grace period days 1 to 3 does not trigger enRiesgo even if projected is high', () {
      // Dia 2: gasto $150 de $400 limite -> proyeccion = 150/2 * 30 = 2250 (mucho mayor a 400)
      // Pero dia 2 <= 3 dias de gracia, por lo que debe ser protegida
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 150,
        diaActual: 2,
        diasTotalesMes: 30,
        diasGraciaInicioMes: 3,
      );

      expect(snapshot.status, SavingsGoalStatus.protegida);
      expect(snapshot.gastoProyectadoFinDeMes, 2250);
    });

    test('grace period days 1 to 3 triggers comprometida if actual spent exceeds limit', () {
      // Dia 2: gasto $450 supero el limite de $400
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 450,
        diaActual: 2,
        diasTotalesMes: 30,
      );

      expect(snapshot.status, SavingsGoalStatus.comprometida);
    });

    test('day 4 or later triggers enRiesgo if projected exceeds limit', () {
      // Dia 10: gasto $200 de $400 limite -> proyeccion = 200/10 * 30 = 600 > 400
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 200,
        diaActual: 10,
        diasTotalesMes: 30,
      );

      expect(snapshot.status, SavingsGoalStatus.enRiesgo);
      expect(snapshot.gastoDiarioPromedio, 20);
      expect(snapshot.gastoProyectadoFinDeMes, 600);
    });

    test('day 4 or later maintains protegida if projected is within limit', () {
      // Dia 15: gasto $150 de $400 limite -> proyeccion = 150/15 * 30 = 300 <= 400
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 150,
        diaActual: 15,
        diasTotalesMes: 30,
      );

      expect(snapshot.status, SavingsGoalStatus.protegida);
      expect(snapshot.gastoProyectadoFinDeMes, 300);
      expect(snapshot.disponibleParaGastar, 250);
    });

    test('triggers comprometida whenever actual spent exceeds limit', () {
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 500,
        metaAhorro: 100,
        gastoAcumulado: 410,
        diaActual: 20,
        diasTotalesMes: 30,
      );

      expect(snapshot.status, SavingsGoalStatus.comprometida);
      expect(snapshot.disponibleParaGastar, 0);
    });

    test('handles clamp when meta exceeds general budget', () {
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 300,
        metaAhorro: 500,
        gastoAcumulado: 50,
        diaActual: 10,
        diasTotalesMes: 30,
      );

      expect(snapshot.metaAhorro, 300);
      expect(snapshot.limiteParaGastar, 0);
      expect(snapshot.status, SavingsGoalStatus.comprometida);
    });

    test('handles February with 28 days correctly', () {
      final snapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: 280,
        metaAhorro: 56,
        gastoAcumulado: 80,
        diaActual: 10,
        diasTotalesMes: 28,
      );

      // limite = 280 - 56 = 224
      // promedio = 80 / 10 = 8/dia
      // proyectado = 8 * 28 = 224 <= 224 -> protegida
      expect(snapshot.limiteParaGastar, 224);
      expect(snapshot.gastoProyectadoFinDeMes, 224);
      expect(snapshot.status, SavingsGoalStatus.protegida);
    });
  });
}
