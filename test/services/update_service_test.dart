import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('detects available update when remote version is higher or remote build number is greater', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == UpdateService.versionCheckUrl) {
          return http.Response(
            jsonEncode({
              'version': '1.0.4',
              'buildNumber': 309,
              'isMajor': true,
              'releaseNotes': 'Nuevas funciones de presupuesto.',
              'apkUrl': 'https://rindemas.cesarluis.com/rindemas.apk',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final updateService = UpdateService(client: mockClient);
      final result = await updateService.checkForUpdate(
        force: true,
        currentVersion: '1.0.3',
        currentBuildNumber: 308,
      );

      expect(result, isNotNull);
      expect(result!.hasUpdate, isTrue);
      expect(result.isMajor, isTrue);
      expect(result.version, equals('1.0.4'));
      expect(result.buildNumber, equals(309));
      expect(result.apkUrl, equals('https://rindemas.cesarluis.com/rindemas.apk'));
      expect(result.releaseNotes, contains('presupuesto'));
    });

    test('reports no update when local version and build number are equal or higher', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'version': '1.0.3',
            'buildNumber': 308,
            'isMajor': false,
            'releaseNotes': 'Sin cambios.',
            'apkUrl': 'https://rindemas.cesarluis.com/rindemas.apk',
          }),
          200,
        );
      });

      final updateService = UpdateService(client: mockClient);
      final result = await updateService.checkForUpdate(
        force: true,
        currentVersion: '1.0.3',
        currentBuildNumber: 308,
      );

      expect(result, isNotNull);
      expect(result!.hasUpdate, isFalse);
    });

    test('handles network failure gracefully without throwing exceptions', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection failed');
      });

      final updateService = UpdateService(client: mockClient);
      final result = await updateService.checkForUpdate(
        force: true,
        currentBuildNumber: 2,
      );

      expect(result, isNull);
    });

    test('respects throttle duration when force is false', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        UpdateService.prefLastCheckTime: now,
      });

      bool networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });

      final updateService = UpdateService(client: mockClient);
      final result = await updateService.checkForUpdate(
        force: false,
        throttleDuration: const Duration(hours: 4),
        currentBuildNumber: 2,
      );

      expect(result, isNull);
      expect(networkCalled, isFalse);
    });
  });
}
