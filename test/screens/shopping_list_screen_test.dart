import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';
import 'package:gastoscan_ai/data/models/shopping_item_model.dart';
import 'package:gastoscan_ai/ui/screens/shopping_list_screen.dart';
import '../helpers/test_database_harness.dart';

void main() {
  final harness = SqliteTestHarness();

  setUp(() async {
    await harness.setUp();
  });

  tearDown(() async {
    await harness.tearDown();
  });

  Widget buildTestWidget({VoidCallback? onBack}) {
    return MaterialApp(
      home: ShoppingListScreen(
        showBackButton: true,
        onBack: onBack,
      ),
    );
  }

  testWidgets('ShoppingListScreen input field has textCapitalization set to sentences', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    final textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.textCapitalization, equals(TextCapitalization.sentences));
  });

  testWidgets('ShoppingListScreen deleting item shows floating SnackBar with correct contrast and duration', (tester) async {
    await harness.dbHelper.insertShoppingItem(
      ShoppingItemModel(name: 'Leche', createdAt: DateTime.now().toIso8601String()),
    );

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Leche'), findsOneWidget);

    // Tocar el botón de eliminar
    final deleteBtn = find.byIcon(Icons.delete_outline);
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verificar SnackBar
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.behavior, equals(SnackBarBehavior.floating));
    expect(snackBar.duration, equals(const Duration(seconds: 2)));
    expect(snackBar.backgroundColor, equals(AppColors.primary));
    expect(find.text('"Leche" eliminado'), findsOneWidget);
  });

  testWidgets('ShoppingListScreen onBack clears active SnackBar', (tester) async {
    await harness.dbHelper.insertShoppingItem(
      ShoppingItemModel(name: 'Café', createdAt: DateTime.now().toIso8601String()),
    );

    bool backCalled = false;
    await tester.pumpWidget(buildTestWidget(onBack: () => backCalled = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Eliminar para mostrar SnackBar
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsOneWidget);

    // Tocar botón Atrás
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(backCalled, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });
}
