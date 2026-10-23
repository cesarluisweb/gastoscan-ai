import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gastoscan_ai/data/datasources/remote/gemini_service.dart';

void main() {
  group('GeminiService API Key Header Security Tests', () {
    test('validateGeminiApiKey sends x-goog-api-key header and never exposes key in URL query', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response('{"models": []}', 200);
      });

      const testKey = 'AIzaSyTestKeyForUnitTesting12345';
      final isValid = await GeminiService.validateGeminiApiKey('  $testKey  ', client: mockClient);

      expect(isValid, isTrue);
      expect(capturedUri, isNotNull);
      expect(capturedUri.toString(), equals('https://generativelanguage.googleapis.com/v1beta/models'));
      expect(capturedUri!.queryParameters.containsKey('key'), isFalse);
      expect(capturedUri.toString().contains(testKey), isFalse);
      expect(capturedHeaders?['x-goog-api-key'], equals(testKey));
    });

    test('validateGeminiApiKey rejects short keys without performing HTTP request', () async {
      bool requestMade = false;
      final mockClient = MockClient((_) async {
        requestMade = true;
        return http.Response('{}', 200);
      });

      final isValid = await GeminiService.validateGeminiApiKey('short', client: mockClient);
      expect(isValid, isFalse);
      expect(requestMade, isFalse);
    });

    test('validateGeminiApiKey returns false on 400/403 status codes', () async {
      final mockClient = MockClient((_) async {
        return http.Response('{"error": "invalid_key"}', 403);
      });

      final isValid = await GeminiService.validateGeminiApiKey('AIzaSyInvalidKey987654321', client: mockClient);
      expect(isValid, isFalse);
    });
  });
}
