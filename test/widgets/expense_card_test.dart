import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/ui/widgets/expense_card.dart';

void main() {
  group('AppConstants.getCategoryIcon Canonical Tests', () {
    test('returns canonical icons for all standard categories', () {
      expect(AppConstants.getCategoryIcon('Alimentación'), Icons.restaurant);
      expect(AppConstants.getCategoryIcon('Educación'), Icons.school_outlined);
      expect(AppConstants.getCategoryIcon('Salud'), Icons.favorite_border);
      expect(AppConstants.getCategoryIcon('Hogar'), Icons.home_outlined);
      expect(AppConstants.getCategoryIcon('Higiene'), Icons.clean_hands_outlined);
      expect(AppConstants.getCategoryIcon('Servicios'), Icons.bolt);
      expect(AppConstants.getCategoryIcon('Transporte'), Icons.directions_car_outlined);
      expect(AppConstants.getCategoryIcon('Otros'), Icons.more_horiz);
    });

    test('normalizes synonyms to canonical icons', () {
      expect(AppConstants.getCategoryIcon('alimentos'), Icons.restaurant);
      expect(AppConstants.getCategoryIcon('aseo'), Icons.clean_hands_outlined);
      expect(AppConstants.getCategoryIcon('farmacia'), Icons.favorite_border);
      expect(AppConstants.getCategoryIcon('casa'), Icons.home_outlined);
      expect(AppConstants.getCategoryIcon('gasolina'), Icons.directions_car_outlined);
    });
  });

  group('ExpenseCard Widget Tests (UX-07)', () {
    final baseGastoConItems = GastoModel(
      id: 1,
      uuid: 'test-uuid-plaza-1',
      comercio: 'Automercado Plaza',
      fecha: '2026-10-14',
      moneda: 'USD',
      totalOriginal: 2500, // $25.00
      totalUsd: 2500,
      tasaCambio: 45.0,
      categoria: 'Alimentación',
      creadoEn: '2026-10-14T10:00:00',
      items: [
        ItemGastoModel(descripcion: 'Arroz', cantidad: 2.0, precioUnitario: 150, total: 300, categoria: 'Alimentación'),
        ItemGastoModel(descripcion: 'Jabón', cantidad: 1.0, precioUnitario: 200, total: 200, categoria: 'Higiene'),
        ItemGastoModel(descripcion: 'Leche', cantidad: 2.0, precioUnitario: 250, total: 500, categoria: 'Alimentación'),
        ItemGastoModel(descripcion: 'Pan', cantidad: 1.0, precioUnitario: 100, total: 100, categoria: 'Alimentación'),
        ItemGastoModel(descripcion: 'Café', cantidad: 1.0, precioUnitario: 400, total: 400, categoria: 'Alimentación'),
        ItemGastoModel(descripcion: 'Pasta', cantidad: 2.0, precioUnitario: 200, total: 400, categoria: 'Alimentación'),
      ],
    );

    testWidgets('compact mode (showDirectItemBreakdown=false) hides breakdown initially and shows item count in subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: baseGastoConItems,
              onDelete: () {},
              onEdit: () {},
              showDirectItemBreakdown: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Automercado Plaza'), findsOneWidget);
      expect(find.textContaining('6 artículos'), findsOneWidget);
      // Items not visible initially in compact mode
      expect(find.text('2x Arroz'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('Automercado Plaza'));
      await tester.pumpAndSettle();

      // Now items are visible
      expect(find.text('2x Arroz'), findsOneWidget);
    });

    testWidgets('direct breakdown mode (showDirectItemBreakdown=true) displays top 4 items and expander button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: baseGastoConItems,
              onDelete: () {},
              onEdit: () {},
              showDirectItemBreakdown: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Items 1 to 4 are directly visible without tapping header
      expect(find.text('2x Arroz'), findsOneWidget);
      expect(find.text('1x Jabón'), findsOneWidget);
      expect(find.text('2x Leche'), findsOneWidget);
      expect(find.text('1x Pan'), findsOneWidget);

      // Item 5 is hidden behind expander
      expect(find.text('1x Café'), findsNothing);

      // Expander button visible
      expect(find.text('Ver 2 artículos más'), findsOneWidget);

      // Tap expander button
      await tester.tap(find.text('Ver 2 artículos más'));
      await tester.pumpAndSettle();

      // Now all items are visible
      expect(find.text('1x Café'), findsOneWidget);
      expect(find.text('2x Pasta'), findsOneWidget);
      expect(find.text('Ver menos'), findsOneWidget);

      // Tap collapse
      await tester.tap(find.text('Ver menos'));
      await tester.pumpAndSettle();

      expect(find.text('1x Café'), findsNothing);
      expect(find.text('Ver 2 artículos más'), findsOneWidget);
    });
  });
}
