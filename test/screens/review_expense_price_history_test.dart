import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/review_expense_screen.dart';

class _FakeDbHelper extends DatabaseHelper {
  _FakeDbHelper() : super.test();

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async => [];

  @override
  Future<int> resetStaleProcessingScanQueueItems() async => 0;
}

class _FakeGastoProvider extends GastoProvider {
  _FakeGastoProvider({required this.mockHistory}) : super(autoLoad: false);

  final Map<String, PriceHistory> mockHistory;

  @override
  Future<void> cargarDatos() async {}

  @override
  Future<Map<String, PriceHistory>> buscarHistorialPrecios(
    List<String> descripcionesNormalizadas, {
    int? excludeGastoId,
    String? comercioActual,
    int diasVentana = 60,
    DateTime? referenceDate,
  }) async {
    return mockHistory;
  }
}

class _FakeSettingsProvider extends SettingsProvider {
  _FakeSettingsProvider() : super(autoLoad: false);

  @override
  double get tasaCambioVesUsd => 50.0;

  @override
  double get tasaCambioVesEur => 54.0;

  @override
  double get tasaCambioVesUsdt => 52.0;
}

void main() {
  final fixedNow = DateTime(2026, 11, 13);

  late _FakeDbHelper fakeDb;
  late _FakeSettingsProvider fakeSettings;
  late ScanQueueProvider scanQueueProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeDb = _FakeDbHelper();
    fakeSettings = _FakeSettingsProvider();
    scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
  });

  tearDown(() {
    scanQueueProvider.dispose();
    fakeSettings.dispose();
  });

  Widget buildTestApp({
    required GeminiExtractionResult extracted,
    required Map<String, PriceHistory> history,
  }) {
    final provider = _FakeGastoProvider(mockHistory: history);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GastoProvider>.value(value: provider),
        ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettings),
        ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
      ],
      child: MaterialApp(
        home: ReviewExpenseScreen(
          extractedData: extracted,
          currentDate: fixedNow,
        ),
      ),
    );
  }

  group('ReviewExpenseScreen - Comparador de Precios v2', () {
    test('Etiquetas de fecha relativa: hoy, ayer, hace N dias, hace N semanas, hace N meses', () {
      expect(
        DatabaseHelper.formatRelativePriceDate('2026-11-13', referenceDate: fixedNow),
        equals('hoy'),
      );
      expect(
        DatabaseHelper.formatRelativePriceDate('2026-11-12', referenceDate: fixedNow),
        equals('ayer'),
      );
      expect(
        DatabaseHelper.formatRelativePriceDate('2026-11-08', referenceDate: fixedNow),
        equals('hace 5 días'),
      );
      expect(
        DatabaseHelper.formatRelativePriceDate('2026-10-30', referenceDate: fixedNow),
        equals('hace 2 semanas'),
      );
      expect(
        DatabaseHelper.formatRelativePriceDate('2026-10-09', referenceDate: fixedNow),
        equals('hace 1 mes'),
      );
      expect(
        DatabaseHelper.formatRelativePriceDate('2026-09-14', referenceDate: fixedNow),
        equals('hace 2 meses'),
      );
    });

    testWidgets('1. Prioridad 1 (mismo comercio 0-30d) y Prioridad 2 (mercado 0-30d) muestran textos exactos y colores correctos', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final history = <String, PriceHistory>{
        // Item 1: Mismo comercio (Farmatodo), hace 5 dias a $2.00 -> hoy $2.40 (+20% mas caro en Farmatodo)
        'cafe molido': const PriceHistory(
          descripcionNorm: 'cafe molido',
          registros: 2,
          mismoComercio: UnitPriceRef(
            precioUsd: 2.00,
            fecha: '2026-11-08',
            comercio: 'Farmatodo',
            comercioNorm: 'farmatodo',
            cantidad: 1.0,
          ),
          mejorPrecio: UnitPriceRef(
            precioUsd: 1.80,
            fecha: '2026-11-01',
            comercio: 'Gama',
            comercioNorm: 'gama',
            cantidad: 1.0,
          ),
          entradas: [
            UnitPriceRef(
              precioUsd: 2.00,
              fecha: '2026-11-08',
              comercio: 'Farmatodo',
              comercioNorm: 'farmatodo',
              cantidad: 1.0,
            ),
            UnitPriceRef(
              precioUsd: 1.80,
              fecha: '2026-11-01',
              comercio: 'Gama',
              comercioNorm: 'gama',
              cantidad: 1.0,
            ),
          ],
        ),
        // Item 2: Sin coincidencia en Farmatodo, mejor precio en Gama hace 14 dias a $5.00 -> hoy $4.00 (20% mas economico que en Gama)
        'arroz premium': const PriceHistory(
          descripcionNorm: 'arroz premium',
          registros: 1,
          mismoComercio: null,
          mejorPrecio: UnitPriceRef(
            precioUsd: 5.00,
            fecha: '2026-10-30',
            comercio: 'Gama',
            comercioNorm: 'gama',
            cantidad: 1.0,
          ),
          entradas: [
            UnitPriceRef(
              precioUsd: 5.00,
              fecha: '2026-10-30',
              comercio: 'Gama',
              comercioNorm: 'gama',
              cantidad: 1.0,
            ),
          ],
        ),
      };

      final extracted = GeminiExtractionResult(
        comercio: 'Farmatodo, C.A.',
        fecha: '2026-11-13',
        moneda: 'USD',
        totalOriginal: 6.40,
        items: [
          ItemGastoModel(
            descripcion: 'Café Molido',
            cantidad: 1.0,
            precioUnitario: 240,
            total: 240,
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: 'Arroz Premium',
            cantidad: 1.0,
            precioUnitario: 400,
            total: 400,
            categoria: 'Alimentación',
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(extracted: extracted, history: history));
      await tester.pumpAndSettle();

      final msg1Finder = find.text('🔺 Está 20% más caro por unidad en Farmatodo (hace 5 días)');
      expect(msg1Finder, findsOneWidget);
      final msg1Widget = tester.widget<Text>(msg1Finder);
      expect(msg1Widget.style?.color, equals(AppColors.error));

      final msg2Finder = find.text('🟢 Te salió un 20% más económico por unidad que en Gama (hace 2 semanas)');
      expect(msg2Finder, findsOneWidget);
      final msg2Widget = tester.widget<Text>(msg2Finder);
      expect(msg2Widget.style?.color, equals(AppColors.textPrimary));
    });

    testWidgets('2. Silencio bajo 5% y linea gris de referencia entre 31 y 60 dias sin porcentaje', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final history = <String, PriceHistory>{
        // Item 1: Diferencia de +3% (< 5%) -> silencio
        'leche entera': const PriceHistory(
          descripcionNorm: 'leche entera',
          registros: 1,
          mejorPrecio: UnitPriceRef(
            precioUsd: 2.00,
            fecha: '2026-11-10',
            comercio: 'Plaza',
            comercioNorm: 'plaza',
            cantidad: 1.0,
          ),
          entradas: [
            UnitPriceRef(
              precioUsd: 2.00,
              fecha: '2026-11-10',
              comercio: 'Plaza',
              comercioNorm: 'plaza',
              cantidad: 1.0,
            ),
          ],
        ),
        // Item 2: Dato de hace 40 dias (31..60d) -> referencia gris sin porcentaje
        'aceite vegetal': const PriceHistory(
          descripcionNorm: 'aceite vegetal',
          registros: 1,
          mejorPrecio: UnitPriceRef(
            precioUsd: 3.50,
            fecha: '2026-10-04',
            comercio: 'Unicasa',
            comercioNorm: 'unicasa',
            cantidad: 1.0,
          ),
          entradas: [
            UnitPriceRef(
              precioUsd: 3.50,
              fecha: '2026-10-04',
              comercio: 'Unicasa',
              comercioNorm: 'unicasa',
              cantidad: 1.0,
            ),
          ],
        ),
      };

      final extracted = GeminiExtractionResult(
        comercio: 'Farmatodo',
        fecha: '2026-11-13',
        moneda: 'USD',
        totalOriginal: 7.06,
        items: [
          ItemGastoModel(
            descripcion: 'Leche Entera',
            cantidad: 1.0,
            precioUnitario: 206, // $2.06 vs $2.00 (+3%)
            total: 206,
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: 'Aceite Vegetal',
            cantidad: 1.0,
            precioUnitario: 500,
            total: 500,
            categoria: 'Alimentación',
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(extracted: extracted, history: history));
      await tester.pumpAndSettle();

      // Leche Entera no debe mostrar aviso por estar bajo el umbral del 5%
      expect(find.textContaining('Plaza'), findsNothing);

      // Aceite Vegetal (40 dias) muestra linea gris de referencia sin porcentaje
      final refFinder = find.text('Referencia: \$3.50/ud en Unicasa (hace 1 mes)');
      expect(refFinder, findsOneWidget);
      final refText = tester.widget<Text>(refFinder);
      expect(refText.style?.color, equals(AppColors.textMuted));
    });

    testWidgets('3. Regresion de alineacion: borrar el primer item mantiene intacto el aviso del segundo item por clientKey', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final history = <String, PriceHistory>{
        'harina pan': const PriceHistory(
          descripcionNorm: 'harina pan',
          registros: 1,
          mejorPrecio: UnitPriceRef(
            precioUsd: 1.00,
            fecha: '2026-11-12',
            comercio: 'Comercio Uno',
            comercioNorm: 'comercio uno',
            cantidad: 1.0,
          ),
          entradas: [
            UnitPriceRef(
              precioUsd: 1.00,
              fecha: '2026-11-12',
              comercio: 'Comercio Uno',
              comercioNorm: 'comercio uno',
              cantidad: 1.0,
            ),
          ],
        ),
        'pasta larga': const PriceHistory(
          descripcionNorm: 'pasta larga',
          registros: 1,
          mejorPrecio: UnitPriceRef(
            precioUsd: 2.00,
            fecha: '2026-11-10',
            comercio: 'Comercio Dos',
            comercioNorm: 'comercio dos',
            cantidad: 1.0,
          ),
          entradas: [
            UnitPriceRef(
              precioUsd: 2.00,
              fecha: '2026-11-10',
              comercio: 'Comercio Dos',
              comercioNorm: 'comercio dos',
              cantidad: 1.0,
            ),
          ],
        ),
      };

      final extracted = GeminiExtractionResult(
        comercio: 'Tienda Actual',
        fecha: '2026-11-13',
        moneda: 'USD',
        totalOriginal: 4.50,
        items: [
          ItemGastoModel(
            descripcion: 'Harina PAN',
            cantidad: 1.0,
            precioUnitario: 150, // +50% que en Comercio Uno (ayer)
            total: 150,
            categoria: 'Alimentación',
          ),
          ItemGastoModel(
            descripcion: 'Pasta Larga',
            cantidad: 1.0,
            precioUnitario: 300, // +50% que en Comercio Dos (hace 3 días)
            total: 300,
            categoria: 'Alimentación',
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(extracted: extracted, history: history));
      await tester.pumpAndSettle();

      expect(find.text('🔺 Está 50% más caro por unidad que en Comercio Uno (ayer)'), findsOneWidget);
      expect(find.text('🔺 Está 50% más caro por unidad que en Comercio Dos (hace 3 días)'), findsOneWidget);

      // Eliminar el primer item (Harina PAN)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // El aviso del primer item desaparece y el segundo conserva su propio aviso sin desfasarse
      expect(find.textContaining('Comercio Uno'), findsNothing);
      expect(find.text('🔺 Está 50% más caro por unidad que en Comercio Dos (hace 3 días)'), findsOneWidget);
    });
  });
}
