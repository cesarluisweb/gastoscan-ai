import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/ui/widgets/summary_card.dart';

void main() {
  group('SummaryCard - FIN-07 Meses Históricos', () {
    testWidgets('muestra mensaje de período finalizado para meses pasados', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 50.0,
              totalVes: 2000.0,
              periodo: 'Febrero 2024',
              monedaPrincipal: 'USD',
              tasaCambio: 40.0,
              presupuestoGeneral: 100.0,
              mes: 2,
              anio: 2024,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No debe mostrar "Faltan X días" de un mes pasado
      expect(find.textContaining('Faltan'), findsNothing);
      expect(find.textContaining('Falta 1 día'), findsNothing);
      // Debe mostrar que sobró presupuesto en el período pasado
      expect(find.textContaining('Te sobraron'), findsOneWidget);
    });

    testWidgets('muestra días restantes para el mes actual', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 50.0,
              totalVes: 2000.0,
              periodo: 'Mes Actual',
              monedaPrincipal: 'USD',
              tasaCambio: 40.0,
              presupuestoGeneral: 100.0,
              mes: now.month,
              anio: now.year,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Para el mes actual sí debe calcular días restantes y monto disponible
      expect(find.textContaining('Disponible:'), findsOneWidget);
      expect(find.textContaining('Ritmo:'), findsOneWidget);
    });

    testWidgets('al presionar botones de lente invoca onMonedaChanged con la moneda correcta', (tester) async {
      String? changedMoneda;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 100.0,
              totalVes: 8000.0,
              periodo: 'Octubre 2026',
              monedaPrincipal: 'USD',
              tasaCambio: 80.0,
              presupuestoGeneral: 500.0,
              onMonedaChanged: (m) => changedMoneda = m,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir selector desplegable y pulsar lente Bs.
      await tester.tap(find.byKey(const Key('summary_card_lens_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lens_switch_ves')));
      await tester.pumpAndSettle();
      expect(changedMoneda, equals('VES'));

      // Abrir selector desplegable y pulsar lente USDT P2P
      await tester.tap(find.byKey(const Key('summary_card_lens_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lens_switch_usdt')));
      await tester.pumpAndSettle();
      expect(changedMoneda, equals('USDT'));

      // Abrir selector desplegable y pulsar lente EUR BCV
      await tester.tap(find.byKey(const Key('summary_card_lens_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lens_switch_eur')));
      await tester.pumpAndSettle();
      expect(changedMoneda, equals('EUR'));

      // Abrir selector desplegable y pulsar lente USD BCV
      await tester.tap(find.byKey(const Key('summary_card_lens_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lens_switch_usd')));
      await tester.pumpAndSettle();
      expect(changedMoneda, equals('USD'));
    });
  });
}
