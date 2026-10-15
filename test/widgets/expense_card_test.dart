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

  group('ExpenseCard Widget Tests (UX-07 & Refinements)', () {
    final baseGastoConItems = GastoModel(
      id: 1,
      uuid: 'test-uuid-plaza-1',
      comercio: 'AUTOMERCADO PLAZA',
      fecha: '2026-10-14',
      moneda: 'USD',
      totalOriginal: 2500, // $25.00
      totalUsd: 2500,
      tasaCambio: 45.0,
      categoria: 'Alimentación',
      creadoEn: '2026-10-14T10:00:00',
      items: [
        ItemGastoModel(descripcion: 'Arroz (G)', cantidad: 2.0, precioUnitario: 150, total: 300, categoria: 'Alimentación'),
        ItemGastoModel(descripcion: 'Jabón', cantidad: 1.0, precioUnitario: 200, total: 200, categoria: 'Higiene'),
        ItemGastoModel(descripcion: 'Leche', cantidad: 2.0, precioUnitario: 250, total: 500, categoria: 'Alimentación'),
        ItemGastoModel(descripcion: 'Pan', cantidad: 1.0, precioUnitario: 100, total: 100, categoria: 'Alimentación'),
        ItemGastoModel(descripcion: 'Café (E)', cantidad: 1.0, precioUnitario: 400, total: 400, categoria: 'Alimentación'),
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

      // Normalizes to Title Case
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

    testWidgets('direct breakdown mode (showDirectItemBreakdown=true) displays top 4 items, cleans (G) suffixes and shows unit price', (tester) async {
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

      // Title Case applied
      expect(find.text('Automercado Plaza'), findsOneWidget);

      // Fiscal suffix (G) is cleaned from 'Arroz (G)' -> '2x Arroz'
      expect(find.text('2x Arroz'), findsOneWidget);
      expect(find.textContaining('Arroz (G)'), findsNothing);

      // Unit price subtitle shown for multi-quantity item
      expect(find.textContaining('2x a \$ 1,50 c/u'), findsOneWidget);

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

      // Fiscal suffix (E) is cleaned from 'Café (E)' -> '1x Café'
      expect(find.text('1x Café'), findsOneWidget);
      expect(find.text('2x Pasta'), findsOneWidget);
      expect(find.text('Ver menos'), findsOneWidget);

      // Tap collapse
      await tester.tap(find.text('Ver menos'));
      await tester.pumpAndSettle();

      expect(find.text('1x Café'), findsNothing);
      expect(find.text('Ver 2 artículos más'), findsOneWidget);
    });

    testWidgets('single item purchase integrates cleanly into header without divider or duplicate bottom row', (tester) async {
      final singleItemGasto = GastoModel(
        id: 2,
        uuid: 'test-uuid-farmatodo-1',
        comercio: 'FARMATODO SAAS C.A.',
        fecha: '2026-10-14',
        moneda: 'USD',
        totalOriginal: 500,
        totalUsd: 500,
        tasaCambio: 45.0,
        categoria: 'Salud',
        creadoEn: '2026-10-14T11:00:00',
        items: [
          ItemGastoModel(descripcion: 'Acetaminofén (G)', cantidad: 1.0, precioUnitario: 500, total: 500, categoria: 'Salud'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: singleItemGasto,
              onDelete: () {},
              onEdit: () {},
              showDirectItemBreakdown: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title Case preserves C.A.
      expect(find.text('Farmatodo Saas C.A.'), findsOneWidget);
      // Item name and rate in header subtitle
      expect(find.textContaining('Acetaminofén • Tasa 45,00'), findsOneWidget);
      // No divider or repeated item row
      expect(find.byType(Divider), findsNothing);
      expect(find.text('Desglose de Ítems:'), findsNothing);
      expect(find.textContaining('artículos más'), findsNothing);
    });

    testWidgets('proportional currency calculation aligns EUR expense items with USD header', (tester) async {
      // 7.00 EUR totalOriginal, 7.84 USD totalUsd (tasa 45)
      final eurGasto = GastoModel(
        id: 3,
        uuid: 'test-uuid-eur-1',
        comercio: 'Pescadería',
        fecha: '2026-10-14',
        moneda: 'EUR',
        totalOriginal: 700, // 7.00 EUR
        totalUsd: 784, // $7.84 USD
        tasaCambio: 45.0,
        categoria: 'Alimentación',
        creadoEn: '2026-10-14T12:00:00',
        items: [
          ItemGastoModel(descripcion: 'Camarones', cantidad: 1.0, precioUnitario: 700, total: 700, categoria: 'Alimentación'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              gasto: eurGasto,
              onDelete: () {},
              onEdit: () {},
              showDirectItemBreakdown: true,
              monedaPrincipal: 'USD',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card displays $ 7,84 in header
      expect(find.text('\$ 7,84'), findsOneWidget);
    });
  });
}
