import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/shopping_item_model.dart';
import 'package:gastoscan_ai/ui/screens/shopping_list_screen.dart';

class FakeShoppingDatabaseHelper extends DatabaseHelper {
  final List<ShoppingItemModel> items = [];
  int _nextId = 1;

  FakeShoppingDatabaseHelper() : super.test();

  @override
  Future<List<ShoppingItemModel>> getAllShoppingItems() async {
    return List.from(items);
  }

  @override
  Future<int> insertShoppingItem(ShoppingItemModel item) async {
    final id = item.id ?? _nextId++;
    final created = item.copyWith(id: id);
    items.add(created);
    return id;
  }

  @override
  Future<int> deleteShoppingItem(int id) async {
    items.removeWhere((it) => it.id == id);
    return 1;
  }

  @override
  Future<void> updateShoppingItemStatus(int id, bool isPurchased, {int? gastoId}) async {
    final idx = items.indexWhere((it) => it.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(isPurchased: isPurchased ? 1 : 0);
    }
  }
}

void main() {
  late FakeShoppingDatabaseHelper fakeDb;

  setUp(() {
    fakeDb = FakeShoppingDatabaseHelper();
  });

  Widget buildTestWidget({VoidCallback? onBack}) {
    return MaterialApp(
      home: ShoppingListScreen(
        showBackButton: true,
        onBack: onBack,
        dbHelper: fakeDb,
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

  testWidgets('ShoppingListScreen deleting item shows standard fixed SnackBar with discreet undo button', (tester) async {
    await fakeDb.insertShoppingItem(
      ShoppingItemModel(name: 'Leche', createdAt: DateTime.now().toIso8601String()),
    );

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    expect(find.text('Leche'), findsOneWidget);

    // Tocar el botón de eliminar
    final deleteBtn = find.byIcon(Icons.delete_outline);
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pump();

    // Verificar SnackBar fijo en la barra inferior (igual a Gasto guardado)
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.behavior, isNot(equals(SnackBarBehavior.floating)));
    expect(snackBar.action, isNull);
    expect(snackBar.duration, equals(const Duration(seconds: 2)));
    expect(snackBar.backgroundColor, equals(AppColors.primaryDark));
    expect(find.text('"Leche" eliminado'), findsOneWidget);
    expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);

    // Avanzar la animación de entrada del SnackBar (250 ms) para que quede en pantalla
    await tester.pump(const Duration(milliseconds: 300));

    // Probar que el botón Deshacer restaura el artículo
    await tester.tap(find.byKey(const Key('shopping_undo_delete_button')));
    await tester.pump();
    expect(find.text('Leche'), findsOneWidget);

    // Drenar el temporizador del SnackBar para cerrar la prueba limpiamente
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('ShoppingListScreen onBack clears active SnackBar', (tester) async {
    await fakeDb.insertShoppingItem(
      ShoppingItemModel(name: 'Café', createdAt: DateTime.now().toIso8601String()),
    );

    bool backCalled = false;
    await tester.pumpWidget(buildTestWidget(onBack: () => backCalled = true));
    await tester.pump();

    // Eliminar para mostrar SnackBar
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);

    // Tocar botón Atrás
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(backCalled, isTrue);
    expect(find.byType(SnackBar), findsNothing);

    // Drenar cualquier temporizador remanente
    await tester.pump(const Duration(seconds: 3));
  });
}
