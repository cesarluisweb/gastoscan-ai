import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/services/sync_service.dart';

void main() {
  group('SyncService Email Validation Tests', () {
    late SyncService syncService;

    setUp(() {
      syncService = SyncService();
    });

    test('vincularConEmail rejects empty or invalid email', () async {
      final res1 = await syncService.vincularConEmail('', 'password123');
      expect(res1, equals('Ingresa un correo electrónico válido.'));

      final res2 = await syncService.vincularConEmail('not-an-email', 'password123');
      expect(res2, equals('Ingresa un correo electrónico válido.'));
    });

    test('vincularConEmail rejects short password', () async {
      final res = await syncService.vincularConEmail('usuario@addy.io', '12345');
      expect(res, equals('La contraseña debe tener al menos 6 caracteres.'));
    });

    test('iniciarSesionConEmail rejects empty or invalid email', () async {
      final res1 = await syncService.iniciarSesionConEmail('', 'password123');
      expect(res1, equals('Ingresa un correo electrónico válido.'));

      final res2 = await syncService.iniciarSesionConEmail('sin-arroba.com', 'password123');
      expect(res2, equals('Ingresa un correo electrónico válido.'));
    });

    test('iniciarSesionConEmail rejects short password', () async {
      final res = await syncService.iniciarSesionConEmail('usuario@dominio.com', '123');
      expect(res, equals('La contraseña debe tener al menos 6 caracteres.'));
    });
  });
}
