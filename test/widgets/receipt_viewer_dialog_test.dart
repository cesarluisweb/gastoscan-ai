import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/ui/widgets/receipt_viewer_dialog.dart';

void main() {
  group('ReceiptViewerDialog Tests', () {
    testWidgets('renders title and non-existing image fallback gracefully', (tester) async {
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
    });
  });
}
