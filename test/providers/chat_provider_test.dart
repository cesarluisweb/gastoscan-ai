import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/providers/chat_provider.dart';

void main() {
  group('ChatProvider Tests', () {
    test('initializes with default welcome greeting', () {
      final provider = ChatProvider();
      expect(provider.messages.length, 1);
      expect(provider.messages.first['role'], 'assistant');
      expect(provider.messages.first['text'], ChatProvider.initialGreeting);
      expect(provider.isLoading, isFalse);
      expect(provider.hasUserMessages, isFalse);
    });

    test('initializes with custom initial messages when provided', () {
      final custom = [
        {'role': 'user', 'text': 'Hola'},
        {'role': 'assistant', 'text': 'Saludos'}
      ];
      final provider = ChatProvider(initialMessages: custom);
      expect(provider.messages.length, 2);
      expect(provider.messages.first['text'], 'Hola');
      expect(provider.hasUserMessages, isTrue);
    });

    test('addMessage appends message and notifies listeners', () {
      final provider = ChatProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.addMessage({'role': 'user', 'text': '¿Cuánto gasté hoy?'});

      expect(provider.messages.length, 2);
      expect(provider.messages.last['text'], '¿Cuánto gasté hoy?');
      expect(provider.hasUserMessages, isTrue);
      expect(notifyCount, 1);
    });

    test('setLoading changes isLoading state and notifies listeners', () {
      final provider = ChatProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setLoading(true);
      expect(provider.isLoading, isTrue);
      expect(notifyCount, 1);

      // Calling with same value does not notify redundantly
      provider.setLoading(true);
      expect(notifyCount, 1);

      provider.setLoading(false);
      expect(provider.isLoading, isFalse);
      expect(notifyCount, 2);
    });

    test('clearConversation resets back to initial greeting and resets loading', () {
      final provider = ChatProvider();
      provider.addMessage({'role': 'user', 'text': 'Mensaje 1'});
      provider.addMessage({'role': 'assistant', 'text': 'Respuesta 1'});
      provider.setLoading(true);

      expect(provider.messages.length, 3);
      expect(provider.isLoading, isTrue);

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearConversation();

      expect(provider.messages.length, 1);
      expect(provider.messages.first['text'], ChatProvider.initialGreeting);
      expect(provider.isLoading, isFalse);
      expect(provider.hasUserMessages, isFalse);
      expect(notifyCount, 1);
    });
  });
}
