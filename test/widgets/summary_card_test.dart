import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/ui/widgets/summary_card.dart';

void main() {
  group('SummaryCard - Rediseño Modelo Mental y FIN-07 Meses Históricos', () {
    testWidgets('muestra mensaje de período finalizado y Te sobraron para meses pasados', (tester) async {
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

      // No debe mostrar días restantes de un mes pasado
      expect(find.textContaining('Faltan'), findsNothing);
      expect(find.textContaining('Falta 1 día'), findsNothing);
      // En el Bloque 2 muestra "Te sobraron"
      expect(find.textContaining('Te sobraron'), findsOneWidget);
      // En la Fila 2 del pie muestra "Período finalizado"
      expect(find.textContaining('Período finalizado'), findsOneWidget);
    });

    testWidgets('muestra Disponible por gastar y Ritmo sugerido para el mes actual', (tester) async {
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

      // Para el mes actual debe mostrar Disponible por gastar y Ritmo sugerido
      expect(find.textContaining('Disponible por gastar'), findsOneWidget);
      expect(find.textContaining('Ritmo sugerido'), findsOneWidget);
      expect(find.text('Total gastado'), findsOneWidget);
      expect(find.text('Presupuesto del mes'), findsOneWidget);
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

    testWidgets('cuando no hay presupuesto muestra botón para definirlo y oculta disponible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 45.0,
              totalVes: 1800.0,
              periodo: 'Mes Actual',
              monedaPrincipal: 'USD',
              presupuestoGeneral: 0.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('summary_card_set_budget_btn')), findsOneWidget);
      expect(find.text('+ Definir presupuesto del mes'), findsOneWidget);
      expect(find.textContaining('Disponible por gastar'), findsNothing);
      expect(find.textContaining('Ritmo sugerido'), findsNothing);
    });

    testWidgets('con meta de ahorro muestra Límite del mes, Meta de ahorro y estado', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 150.0,
              totalVes: 6000.0,
              periodo: 'Mes Actual',
              monedaPrincipal: 'USD',
              presupuestoGeneral: 600.0,
              metaAhorro: 100.0,
              mes: now.month,
              anio: now.year,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar Límite del mes en vez de Presupuesto del mes
      expect(find.text('Límite del mes'), findsOneWidget);
      expect(find.text('Presupuesto del mes'), findsNothing);
      // Fila 3 con la meta
      expect(find.text('Meta de ahorro'), findsOneWidget);
      expect(find.textContaining('Protegida'), findsOneWidget);
    });

    testWidgets('cuando se supera el límite muestra estado excedido en rojo', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 550.0,
              totalVes: 22000.0,
              periodo: 'Mes Actual',
              monedaPrincipal: 'USD',
              presupuestoGeneral: 500.0,
              metaAhorro: 50.0,
              mes: now.month,
              anio: now.year,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Excedido'), findsWidgets);
      expect(find.textContaining('Límite superado'), findsOneWidget);
    });
  });
}
