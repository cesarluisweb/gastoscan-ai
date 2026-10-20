import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/ui/widgets/daily_evolution_card.dart';

void main() {
  testWidgets('DailyEvolutionCard no solapa d30 con d31 en meses de 31 dias', (tester) async {
    // Octubre tiene 31 dias
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyEvolutionCard(
            gastosMes: [],
            totalGastadoMes: 50.0,
            limitePresupuesto: 100.0,
            anio: 2026,
            mes: 10,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('d1'), findsOneWidget);
    expect(find.text('d25'), findsOneWidget);
    expect(find.text('d31'), findsOneWidget);
    // En mes de 31 dias d30 debe omitirse para no solapar visualmente "d30d31"
    expect(find.text('d30'), findsNothing);
  });

  testWidgets('DailyEvolutionCard muestra d30 en meses de 30 dias', (tester) async {
    // Noviembre tiene 30 dias
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyEvolutionCard(
            gastosMes: [],
            totalGastadoMes: 50.0,
            limitePresupuesto: 100.0,
            anio: 2026,
            mes: 11,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('d1'), findsOneWidget);
    expect(find.text('d25'), findsOneWidget);
    expect(find.text('d30'), findsOneWidget);
  });
}
