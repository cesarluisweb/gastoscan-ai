import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/ui/screens/scan_screen.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> items = [];
  int _id = 1;

  FakeDatabaseHelper() : super.test();

  @override
  Future<int> insertScanQueueItem(String imagePath) async {
    final id = _id++;
    items.add({'id': id, 'image_path': imagePath, 'status': 'pending'});
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async {
    return List.from(items);
  }

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async {
    return [];
  }
}

class FakeSettingsProvider extends SettingsProvider {
  @override
  Future<void> loadSettings() async {}
}

class FakeImagePicker extends ImagePicker {
  List<XFile> multiImagesToReturn = [];
  XFile? singleImageToReturn;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool? requestFullMetadata = true,
  }) async {
    return multiImagesToReturn;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool? requestFullMetadata = true,
  }) async {
    return singleImageToReturn;
  }
}

void main() {
  group('ScanScreen Multi-Image Selection Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider scanQueueProvider;
    late FakeSettingsProvider fakeSettings;
    late FakeImagePicker fakePicker;

    setUp(() {
      fakeDb = FakeDatabaseHelper();
      scanQueueProvider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      fakeSettings = FakeSettingsProvider();
      fakePicker = FakeImagePicker();
    });

    testWidgets('multi-image selection enqueues all images and pops back to Dashboard', (tester) async {
      fakePicker.multiImagesToReturn = [
        XFile('/tmp/receipt1.jpg'),
        XFile('/tmp/receipt2.jpg'),
        XFile('/tmp/receipt3.jpg'),
      ];

      bool returnedToCaller = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettings),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('launch_btn'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanScreen(imagePicker: fakePicker),
                    ),
                  );
                  returnedToCaller = true;
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );

      // Open ScanScreen
      await tester.tap(find.byKey(const Key('launch_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Digitaliza tus facturas'), findsOneWidget);
      expect(find.text('GalerÃ­a'), findsOneWidget);

      // Tap gallery button to pick multiple images
      await tester.tap(find.text('GalerÃ­a'));
      await tester.pumpAndSettle();

      // Verify that all 3 images were enqueued into ScanQueueProvider
      expect(scanQueueProvider.pendingCount, equals(3));
      expect(scanQueueProvider.pendingItems.map((e) => e['image_path']).toList(), [
        '/tmp/receipt1.jpg',
        '/tmp/receipt2.jpg',
        '/tmp/receipt3.jpg',
      ]);

      // Verify that the UI returned immediately/silently back to Dashboard
      expect(returnedToCaller, isTrue);
      expect(find.byKey(const Key('launch_btn')), findsOneWidget);
      expect(find.text('Digitaliza tus facturas'), findsNothing);
    });

    testWidgets('empty selection from gallery does not enqueue or pop', (tester) async {
      fakePicker.multiImagesToReturn = [];

      bool returnedToCaller = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ScanQueueProvider>.value(value: scanQueueProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: fakeSettings),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('launch_btn'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanScreen(imagePicker: fakePicker),
                    ),
                  );
                  returnedToCaller = true;
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('launch_btn')));
      await tester.pumpAndSettle();

      // Tap gallery with no selection
      await tester.tap(find.text('GalerÃ­a'));
      await tester.pumpAndSettle();

      expect(scanQueueProvider.pendingCount, equals(0));
      expect(returnedToCaller, isFalse);
      expect(find.text('Digitaliza tus facturas'), findsOneWidget);
    });
  });
}
