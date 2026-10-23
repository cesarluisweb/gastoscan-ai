import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final member = invocation.memberName;
    if (member == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value != null) {
        data[key] = value;
      }
      return Future<void>.value();
    }
    if (member == #read) {
      final key = invocation.namedArguments[#key] as String;
      return Future<String?>.value(data[key]);
    }
    if (member == #delete) {
      final key = invocation.namedArguments[#key] as String;
      data.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class TestableSettingsProvider extends SettingsProvider {
  TestableSettingsProvider({super.secureStorage});

  @override
  Future<bool> actualizarTasaAutomatica({http.Client? client}) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Local-Only API Key Security Tests', () {
    late FakeSecureStorage fakeSecureStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeSecureStorage = FakeSecureStorage();
    });

    test('setApiKey and removeApiKey persist and delete key exclusively in SecureStorage', () async {
      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      await provider.loadSettings();

      await provider.setApiKey('  AIzaSyLocalOnlySecretKey123  ');
      expect(provider.apiKey, equals('AIzaSyLocalOnlySecretKey123'));
      expect(fakeSecureStorage.data[AppConstants.prefApiKey], equals('AIzaSyLocalOnlySecretKey123'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.prefApiKey), isNull);

      await provider.removeApiKey();
      expect(provider.apiKey, isEmpty);
      expect(fakeSecureStorage.data.containsKey(AppConstants.prefApiKey), isFalse);
    });

    test('loadSettings migrates legacy key from SharedPreferences to SecureStorage and deletes plaintext copy', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefApiKey: 'AIzaSyLegacyPlaintextKey999',
      });

      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      await provider.loadSettings();

      expect(provider.apiKey, equals('AIzaSyLegacyPlaintextKey999'));
      expect(fakeSecureStorage.data[AppConstants.prefApiKey], equals('AIzaSyLegacyPlaintextKey999'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.prefApiKey), isNull);
    });
  });
}
