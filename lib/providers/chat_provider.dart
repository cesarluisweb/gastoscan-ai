import 'package:flutter/foundation.dart';

/// Provider que mantiene en memoria la conversación del asistente IA
/// durante toda la sesión activa de la app.
class ChatProvider with ChangeNotifier {
  static const String initialGreeting =
      '¡Hola! Puedo analizar tus finanzas, darte consejos para ahorrar, registrar gastos o agregar productos a tu lista de compras. ¿Por dónde empezamos?';

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _pendingInsightDeepDive;
  String? _lastDeepDivedInsight;

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
  String? get pendingInsightDeepDive => _pendingInsightDeepDive;
  String? get lastDeepDivedInsight => _lastDeepDivedInsight;

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

  /// Presenta en el chat un consejo como mensaje del asistente (sin disparar llamada en vivo).
  void presentDetailedInsight(String detailedInsight) {
    final clean = detailedInsight.trim();
    if (clean.isEmpty) return;

    if (_messages.isNotEmpty && _messages.last['text'] == clean) {
      return;
    }

    if (!hasUserMessages &&
        _messages.length == 1 &&
        _messages.first['text'] == initialGreeting) {
      _messages[0] = {
        'role': 'assistant',
        'text': clean,
      };
    } else {
      _messages.add({
        'role': 'assistant',
        'text': clean,
      });
    }
    notifyListeners();
  }

  /// Inicia una profundización en vivo desde el botón `Consultar ->` de Inicio.
  /// Es idempotente para el mismo consejo: si el usuario ya abrió `Consultar ->` para
  /// este consejo, regresó a Inicio sin interactuar y vuelve a tocar `Consultar ->`,
  /// NO vuelve a agregar burbujas ni vuelve a disparar la petición a Gemini.
  void startInsightDeepDive(String insightText) {
    final clean = insightText.trim();
    if (clean.isEmpty) return;

    final introBubble = 'Sobre el análisis de hoy:\n\n$clean';
    final alreadyHasIntro = _messages.any((m) => m['text'] == introBubble);

    if (_lastDeepDivedInsight == clean && alreadyHasIntro) {
      return;
    }

    if (!alreadyHasIntro) {
      if (!hasUserMessages &&
          _messages.length == 1 &&
          _messages.first['text'] == initialGreeting) {
        _messages[0] = {
          'role': 'assistant',
          'text': introBubble,
        };
      } else {
        _messages.add({
          'role': 'assistant',
          'text': introBubble,
        });
      }
    }

    _lastDeepDivedInsight = clean;
    _pendingInsightDeepDive = clean;
    notifyListeners();
  }

  /// Consume el consejo pendiente de profundización en vivo (solo se dispara una vez).
  String? consumePendingInsightDeepDive() {
    final pending = _pendingInsightDeepDive;
    _pendingInsightDeepDive = null;
    return pending;
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
    _pendingInsightDeepDive = null;
    _lastDeepDivedInsight = null;
    notifyListeners();
  }
}
