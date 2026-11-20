import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';
import 'package:gastoscan_ai/services/profile_avatar_service.dart';

/// PNG válido de 1x1 píxel (67 bytes) con firma mágica oficial.
final Uint8List kValidPngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileAvatarService', () {
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('profile_avatar_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      ProfileAvatarService.reset();
    });

    test('descarga imagen PNG valida, la guarda en disco y la sirve offline despues', () async {
      int httpCalls = 0;
      final onlineClient = MockClient((request) async {
        httpCalls++;
        return http.Response.bytes(
          kValidPngBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      });

      final serviceOnline = ProfileAvatarService(
        httpClient: onlineClient,
        connectivityService: ConnectivityService(testConnected: true),
        baseDirectoryProvider: () async => tempDir,
      );

      final cached = await serviceOnline.ensureAvatarCached(
        uid: 'user-123',
        photoUrl: 'https://lh3.googleusercontent.com/avatar-v1.png',
      );
      expect(cached, isNotNull);
      expect(await cached!.exists(), isTrue);
      expect(httpCalls, 1);

      // Segunda consulta offline debe devolver el mismo archivo sin tocar red
      int offlineCalls = 0;
      final offlineClient = MockClient((_) async {
        offlineCalls++;
        return http.Response('No deberia llamarse', 500);
      });
      final serviceOffline = ProfileAvatarService(
        httpClient: offlineClient,
        connectivityService: ConnectivityService(testConnected: false),
        baseDirectoryProvider: () async => tempDir,
      );

      final fromDisk = await serviceOffline.getCachedAvatarFile(
        uid: 'user-123',
        photoUrl: 'https://lh3.googleusercontent.com/avatar-v1.png',
      );
      expect(fromDisk, isNotNull);
      expect(fromDisk!.path, equals(cached.path));
      expect(offlineCalls, 0);
    });

    test('rechaza respuesta HTML 200 (portal cautivo) y payloads mayores a 2 MB sin corromper cache previa', () async {
      final goodClient = MockClient((_) async {
        return http.Response.bytes(
          kValidPngBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      });

      final serviceGood = ProfileAvatarService(
        httpClient: goodClient,
        connectivityService: ConnectivityService(testConnected: true),
        baseDirectoryProvider: () async => tempDir,
      );
      final initialFile = await serviceGood.ensureAvatarCached(
        uid: 'user-captive',
        photoUrl: 'https://lh3.googleusercontent.com/avatar-ok.png',
      );
      expect(initialFile, isNotNull);

      // Portal cautivo que devuelve HTML 200
      final captiveClient = MockClient((_) async {
        return http.Response(
          '<html><body>Inicia sesion en Wi-Fi</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final serviceCaptive = ProfileAvatarService(
        httpClient: captiveClient,
        connectivityService: ConnectivityService(testConnected: true),
        baseDirectoryProvider: () async => tempDir,
      );
      final captiveRes = await serviceCaptive.ensureAvatarCached(
        uid: 'user-captive',
        photoUrl: 'https://lh3.googleusercontent.com/avatar-v2.png',
      );
      expect(captiveRes, isNull);

      // Respuesta mintiendo content-type image/png pero con bytes basura
      final fakeBytesClient = MockClient((_) async {
        return http.Response(
          'esto no es una imagen valida ni tiene magic bytes',
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      final serviceFake = ProfileAvatarService(
        httpClient: fakeBytesClient,
        connectivityService: ConnectivityService(testConnected: true),
        baseDirectoryProvider: () async => tempDir,
      );
      final fakeRes = await serviceFake.ensureAvatarCached(
        uid: 'user-captive',
        photoUrl: 'https://lh3.googleusercontent.com/avatar-v3.png',
      );
      expect(fakeRes, isNull);

      // Payload > 2 MB con header PNG
      final oversized = Uint8List(2 * 1024 * 1024 + 32);
      oversized.setRange(0, kValidPngBytes.length, kValidPngBytes);
      final hugeClient = MockClient((_) async {
        return http.Response.bytes(
          oversized,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      final serviceHuge = ProfileAvatarService(
        httpClient: hugeClient,
        connectivityService: ConnectivityService(testConnected: true),
        baseDirectoryProvider: () async => tempDir,
      );
      final hugeRes = await serviceHuge.ensureAvatarCached(
        uid: 'user-captive',
        photoUrl: 'https://lh3.googleusercontent.com/avatar-v4.png',
      );
      expect(hugeRes, isNull);

      // La cache valida previa sigue intacta en disco
      expect(await initialFile!.exists(), isTrue);
    });

    test('al cambiar photoUrl crea nuevo archivo con nuevo hash y elimina el anterior', () async {
      final client = MockClient((_) async {
        return http.Response.bytes(
          kValidPngBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      final service = ProfileAvatarService(
        httpClient: client,
        connectivityService: ConnectivityService(testConnected: true),
        baseDirectoryProvider: () async => tempDir,
      );

      final v1 = await service.ensureAvatarCached(
        uid: 'user-rotate',
        photoUrl: 'https://lh3.googleusercontent.com/photo-1',
      );
      final v2 = await service.ensureAvatarCached(
        uid: 'user-rotate',
        photoUrl: 'https://lh3.googleusercontent.com/photo-2',
      );

      expect(v1, isNotNull);
      expect(v2, isNotNull);
      expect(v1!.path, isNot(equals(v2!.path)));
      expect(await v1.exists(), isFalse);
      expect(await v2.exists(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('profile_avatar_url_user-rotate'),
        equals('https://lh3.googleusercontent.com/photo-2'),
      );
    });

    test('clearAvatarCache purga archivos en disco y metadatos en SharedPreferences', () async {
      final client = MockClient((_) async {
        return http.Response.bytes(
          kValidPngBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      final service = ProfileAvatarService(
        httpClient: client,
        connectivityService: ConnectivityService(testConnected: true),
        baseDirectoryProvider: () async => tempDir,
      );

      final saved = await service.ensureAvatarCached(
        uid: 'user-logout',
        photoUrl: 'https://lh3.googleusercontent.com/photo-logout',
      );
      expect(saved, isNotNull);
      expect(await saved!.exists(), isTrue);

      await service.clearAvatarCache(uid: 'user-logout');
      expect(await saved.exists(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_avatar_url_user-logout'), isNull);
    });

    test('deduplica descargas concurrentes para el mismo uid y url', () async {
      int httpCalls = 0;
      final gate = Completer<void>();
      final client = MockClient((_) async {
        httpCalls++;
        await gate.future;
        return http.Response.bytes(
          kValidPngBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      });

      final service = ProfileAvatarService(
        httpClient: client,
        connectivityService: ConnectivityService(testConnected: true),
        baseDirectoryProvider: () async => tempDir,
      );

      final f1 = service.ensureAvatarCached(
        uid: 'user-concurrent',
        photoUrl: 'https://lh3.googleusercontent.com/photo-c',
      );
      final f2 = service.ensureAvatarCached(
        uid: 'user-concurrent',
        photoUrl: 'https://lh3.googleusercontent.com/photo-c',
      );

      await Future<void>.delayed(Duration.zero);
      gate.complete();

      final results = await Future.wait([f1, f2]);
      expect(httpCalls, 1);
      expect(results[0]?.path, equals(results[1]?.path));
    });
  });
}
