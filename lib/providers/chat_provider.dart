import 'package:flutter/foundation.dart';

/// Provider que mantiene en memoria la conversación del asistente IA
/// durante toda la sesión activa de la app.
class ChatProvider with ChangeNotifier {
  static const String initialGreeting =
      '¡Hola! Puedo analizar tus finanzas, darte consejos para ahorrar, registrar gastos o agregar productos a tu lista de compras. ¿Por dónde empezamos?';

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  ChatProvider({List<Map<String, dynamic>>? initialMessages}) {
    if (initialMessages != null && initialMessages.isNotEmpty) {
      _messages.addAll(initialMessages);
    } else {
      _resetToInitialGreeting();
    }
  }

  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get hasUserMessages => _messages.any((m) => m['role'] == 'user');

  void _resetToInitialGreeting() {
    _messages.clear();
    _messages.add({
      'role': 'assistant',
      'text': initialGreeting,
    });
  }

  void addMessage(Map<String, dynamic> message) {
    _messages.add(message);
    notifyListeners();
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void clearConversation() {
    _resetToInitialGreeting();
    _isLoading = false;
    notifyListeners();
  }
}
