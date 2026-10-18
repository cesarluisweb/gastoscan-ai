import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/ui/widgets/summary_card.dart';

void main() {
  group('SummaryCard - Rediseño Modelo Mental V2 y FIN-07 Meses Históricos', () {
    testWidgets('muestra Te sobraron para meses pasados y oculta disponible para gastar', (tester) async {
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

      // No debe mostrar Disponible para gastar en un mes pasado
      expect(find.textContaining('Disponible para gastar'), findsNothing);
      // En la cabecera muestra "Te sobraron"
      expect(find.textContaining('Te sobraron'), findsOneWidget);
      // Muestra la fila de contexto Gastado vs Presupuesto
      expect(find.textContaining('Gastado:'), findsOneWidget);
      expect(find.textContaining('Presupuesto:'), findsOneWidget);
    });

    testWidgets('muestra Disponible para gastar y Gastado vs Presupuesto para el mes actual', (tester) async {
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

      // Para el mes actual debe mostrar Disponible para gastar y contexto
      expect(find.textContaining('Disponible para gastar'), findsOneWidget);
      expect(find.textContaining('Gastado:'), findsOneWidget);
      expect(find.textContaining('Presupuesto:'), findsOneWidget);
      expect(find.textContaining('\$ 100,00'), findsWidgets);
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
      expect(find.textContaining('Definir presupuesto'), findsOneWidget);
      expect(find.textContaining('Disponible para gastar'), findsNothing);
      expect(find.textContaining('Ritmo sugerido'), findsNothing);
    });

    testWidgets('con meta de ahorro muestra límite, meta de ahorro y estado protegida', (tester) async {
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

      // Debe mostrar el límite de gasto en la fila de contexto (600 - 100 = 500)
      expect(find.textContaining('Límite:'), findsOneWidget);
      expect(find.textContaining('\$ 500,00'), findsWidgets);
      // Fila inferior con la meta
      expect(find.textContaining('Meta de ahorro:'), findsOneWidget);
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

      expect(find.textContaining('Excedido del límite'), findsOneWidget);
      expect(find.textContaining('- \$ 100,00'), findsOneWidget);
    });
  });
}
