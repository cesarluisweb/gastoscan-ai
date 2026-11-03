import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';
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
      // Fila inferior con la meta limpia (sin texto redundante 'Protegida')
      expect(find.textContaining('Meta de ahorro:'), findsOneWidget);
      expect(find.textContaining('Protegida'), findsNothing);

      // Barra de progreso en estado normal (Tanque que se vacía): 75% disponible en verde
      final progressFinder = find.byKey(const Key('summary_card_progress_indicator'));
      expect(progressFinder, findsOneWidget);
      final progressBar = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(progressBar.backgroundColor, equals(Colors.transparent));
      expect((progressBar.valueColor as AlwaysStoppedAnimation<Color>).value, equals(AppColors.balancePositive));
      expect(progressBar.value, closeTo(0.75, 0.001));

      // Marcador vertical de ahorro posicionado a la izquierda
      expect(find.byKey(const Key('summary_card_savings_marker')), findsOneWidget);
    });

    testWidgets('cuando el gasto supera el 85% del límite muestra barra en ámbar', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 430.0,
              totalVes: 17200.0,
              periodo: 'Mes Actual',
              monedaPrincipal: 'USD',
              presupuestoGeneral: 500.0,
              metaAhorro: 0.0,
              mes: now.month,
              anio: now.year,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 430 / 500 = 86% (> 85%), tanque al 14%, debe mostrar color ámbar de precaución
      final progressFinder = find.byKey(const Key('summary_card_progress_indicator'));
      expect(progressFinder, findsOneWidget);
      final progressBar = tester.widget<LinearProgressIndicator>(progressFinder);
      expect((progressBar.valueColor as AlwaysStoppedAnimation<Color>).value, equals(AppColors.caution));
      expect(progressBar.value, closeTo(0.14, 0.001));
    });

    testWidgets('cuando se supera el límite muestra estado excedido en rojo y carril en rojo suave al agotarse', (tester) async {
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

      // Barra de progreso en estado excedido/agotado: valor 0.0, color rojo y carril rojo suave
      final progressFinder = find.byKey(const Key('summary_card_progress_indicator'));
      expect(progressFinder, findsOneWidget);
      final progressBar = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(progressBar.value, equals(0.0));
      expect((progressBar.valueColor as AlwaysStoppedAnimation<Color>).value, equals(AppColors.errorStrong));
      expect(progressBar.backgroundColor, equals(AppColors.errorTint));
    });

    testWidgets('cuando se invade el ahorro parcialmente muestra rojo fuerte y zona de reserva teñida', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 450.0,
              totalVes: 18000.0,
              periodo: 'Mes Actual',
              monedaPrincipal: 'USD',
              presupuestoGeneral: 500.0,
              metaAhorro: 100.0,
              mes: now.month,
              anio: now.year,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Excedido del límite'), findsOneWidget);
      expect(find.textContaining('- \$ 50,00'), findsOneWidget);

      final progressFinder = find.byKey(const Key('summary_card_progress_indicator'));
      expect(progressFinder, findsOneWidget);
      final progressBar = tester.widget<LinearProgressIndicator>(progressFinder);
      // Queda 10% de ahorro vivo ((500 - 450) / 500)
      expect(progressBar.value, closeTo(0.10, 0.001));
      expect((progressBar.valueColor as AlwaysStoppedAnimation<Color>).value, equals(AppColors.errorStrong));

      // La zona de reserva invadida se tiñe en rojo suave
      expect(find.byKey(const Key('summary_card_savings_invaded_tint')), findsOneWidget);
      expect(find.byKey(const Key('summary_card_savings_marker')), findsOneWidget);
    });

    testWidgets('sin meta de ahorro no renderiza el marcador vertical', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalUsd: 100.0,
              totalVes: 4000.0,
              periodo: 'Mes Actual',
              monedaPrincipal: 'USD',
              presupuestoGeneral: 500.0,
              metaAhorro: 0.0,
              mes: now.month,
              anio: now.year,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('summary_card_savings_marker')), findsNothing);
    });
  });
}
