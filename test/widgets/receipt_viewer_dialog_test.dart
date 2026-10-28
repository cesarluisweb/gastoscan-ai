import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/ui/widgets/receipt_viewer_dialog.dart';

void main() {
  group('ReceiptViewerDialog Tests', () {
    testWidgets('renders title, share action and non-existing image fallback gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiptViewerDialog(
            imagePath: '/non/existent/path/receipt.jpg',
            title: 'Farmatodo',
            subtitle: '07/10/2026',
            amount: '\$ 15.00',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Farmatodo'), findsOneWidget);
      expect(find.text('07/10/2026 • \$ 15.00'), findsOneWidget);
      expect(find.text('No se encontró el archivo de imagen.'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
    });

    testWidgets('shows bottom bar with edit button and only share icon on top bar', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('viewer_test_top_');
      final tempFile = File('${tempDir.path}/test_rec_top.jpg')..writeAsBytesSync([1, 2, 3]);

      bool editCalled = false;
      final dummyGasto = GastoModel(
        id: 1,
        uuid: 'gasto-123',
        fecha: '2026-10-28',
        creadoEn: '2026-10-28T12:00:00Z',
        comercio: 'Automercado Plaza',
        moneda: 'USD',
        totalOriginal: 2500,
        totalUsd: 2500,
        tasaCambio: 1.0,
        categoria: 'Alimentación',
        items: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptViewerDialog(
            imagePath: tempFile.path,
            title: 'Automercado Plaza',
            amount: '\$ 25.00',
            gasto: dummyGasto,
            onEdit: () {
              editCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar only has share icon (no download, no redundant edit/delete on top)
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNothing);

      // Bottom bar has "Ver o editar gasto" and delete
      expect(find.text('Ver o editar gasto'), findsOneWidget);
      expect(find.byKey(const Key('btn_eliminar_foto_viewer_bottom')), findsOneWidget);

      await tester.tap(find.text('Ver o editar gasto'));
      await tester.pumpAndSettle();

      expect(editCalled, isTrue);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('delete button displays confirmation dialog explaining expense is kept', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('viewer_test_');
      final tempFile = File('${tempDir.path}/test_rec.jpg')..writeAsBytesSync([1, 2, 3]);

      bool deleteCalled = false;
      final dummyGasto = GastoModel(
        id: 1,
        uuid: 'gasto-456',
        fecha: '2026-10-28',
        creadoEn: '2026-10-28T12:00:00Z',
        comercio: 'Traki',
        moneda: 'USD',
        totalOriginal: 1000,
        totalUsd: 1000,
        tasaCambio: 1.0,
        categoria: 'Hogar',
        items: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptViewerDialog(
            imagePath: tempFile.path,
            title: 'Traki',
            amount: '\$ 10.00',
            gasto: dummyGasto,
            onDelete: () {
              deleteCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete button in bottom bar
      final btnDelete = find.byKey(const Key('btn_eliminar_foto_viewer_bottom'));
      expect(btnDelete, findsOneWidget);
      await tester.tap(btnDelete);
      await tester.pumpAndSettle();

      // Check dialog explanation
      expect(find.text('¿Eliminar foto del comprobante?'), findsOneWidget);
      expect(
        find.textContaining('El registro del gasto, sus montos y detalles se conservarán intactos'),
        findsOneWidget,
      );

      // Confirm deletion
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar foto'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
