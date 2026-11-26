/// Resultado determinista del selector de señales para el Asistente IA.
/// Decide qué señales locales de SQLite y contexto temporal deben calcularse
/// y enviarse al Worker según la intención del turno del usuario.
class ChatSignalSelection {
  final bool includeAntExpenses;
  final bool includePrevMonthComparison;
  final bool includePriceFindings;
  final bool includeTemporalContext;
  final bool includeTopComercios;
  final String intentGroup;

  const ChatSignalSelection({
    required this.includeAntExpenses,
    required this.includePrevMonthComparison,
    required this.includePriceFindings,
    required this.includeTemporalContext,
    required this.includeTopComercios,
    required this.intentGroup,
  });

  const ChatSignalSelection.directOrAction()
      : includeAntExpenses = false,
        includePrevMonthComparison = false,
        includePriceFindings = false,
        includeTemporalContext = false,
        includeTopComercios = false,
        intentGroup = 'direct_or_action';

  const ChatSignalSelection.all({this.intentGroup = 'analysis_or_budget'})
      : includeAntExpenses = true,
        includePrevMonthComparison = true,
        includePriceFindings = true,
        includeTemporalContext = true,
        includeTopComercios = true;

  const ChatSignalSelection.neutral()
      : includeAntExpenses = false,
        includePrevMonthComparison = false,
        includePriceFindings = false,
        includeTemporalContext = true,
        includeTopComercios = false,
        intentGroup = 'neutral';

  bool get needsAnyHiddenSignal =>
      includeAntExpenses || includePrevMonthComparison || includePriceFindings;

  ChatSignalSelection copyWith({
    bool? includeAntExpenses,
    bool? includePrevMonthComparison,
    bool? includePriceFindings,
    bool? includeTemporalContext,
    bool? includeTopComercios,
    String? intentGroup,
  }) {
    return ChatSignalSelection(
      includeAntExpenses: includeAntExpenses ?? this.includeAntExpenses,
      includePrevMonthComparison:
          includePrevMonthComparison ?? this.includePrevMonthComparison,
      includePriceFindings: includePriceFindings ?? this.includePriceFindings,
      includeTemporalContext:
          includeTemporalContext ?? this.includeTemporalContext,
      includeTopComercios: includeTopComercios ?? this.includeTopComercios,
      intentGroup: intentGroup ?? this.intentGroup,
    );
  }
}

/// Selector determinista (sin llamadas a LLM) que clasifica la consulta del usuario
/// para inyectar únicamente las señales locales relevantes y evitar ruido o
/// consultas SQLite innecesarias en preguntas directas o registros de gastos.
class ChatSignalSelector {
  static final RegExp _nonWordChars = RegExp(r'[^a-z0-9\s]+');
  static final RegExp _multiSpace = RegExp(r'\s+');

  static final RegExp _shoppingListCue = RegExp(
    r'\b(lista de compras|mi lista|a la lista|en la lista|de la lista|tengo que comprar|falta por comprar|pendiente en mi lista|pendientes en mi lista)\b',
  );

  static final RegExp _shoppingListVerb = RegExp(
    r'^(agrega|agregar|anota|anotar|pon|poner|quita|quitar|elimina|eliminar|borra|borrar|marca|marcar|tacha|tachar|cambia|cambiar|renombra|renombrar)\b',
  );

  static final RegExp _recordExpenseVerb = RegExp(
    r'\b(compre|gaste|pague|acabo de comprar|acabo de pagar|acabo de gastar|registra|registrar)\b',
  );

  static final RegExp _questionCue = RegExp(
    r'^(cuanto|cuantos|cuanta|cuantas|que|cual|cuales|donde|como|cuando|por que|estoy|voy|me alcanza|he gastado|llevo)\b',
  );

  static final RegExp _directLookupPattern = RegExp(
    r'^(cuanto|cuanta)\s+(gaste|he gastado|llevo gastado|llevo|pague|compre)\s+(en|de|por)\b',
  );

  static final RegExp _prevMonthPattern = RegExp(
    r'\b(mes pasado|mes anterior|meses anteriores|respecto al mes|frente al mes|comparar|comparativa|comparacion|evolucion|mas que antes|menos que antes|mas que el mes|menos que el mes|he gastado mas|gastando mas|gastando menos|aumentando|aumentado|suelo comprar cada mes|aun no he comprado)\b',
  );

  static final RegExp _pricesPattern = RegExp(
    r'\b(mas barato|mas barata|mas caro|mas cara|precio|precios|subido de precio|subieron de precio|subio de precio|aumento de precio|aumentaron de precio|donde comprar|donde me salio|donde consigo|mejor precio|mejores precios|comparador|inflacion|comercios|comercio mas barato|supermercado mas barato)\b',
  );

  static final RegExp _productPriceWord = RegExp(
    r'\b(caro|cara|barato|barata|subio|bajo|comercio|tienda|donde|mejor)\b',
  );

  static final RegExp _antExpensesPattern = RegExp(
    r'\b(hormiga|gastos pequenos|gasto pequeno|compras pequenas|compra pequena|fuga|fugas|chucheria|chucherias|snack|snacks|menores a|pocos dolares|sumando mas de lo que parece|gastos chiquitos)\b',
  );

  static final RegExp _fullAnalysisPattern = RegExp(
    r'\b(ahorrar|ahorro|reducir|recortar|presupuesto|ritmo|en que se me va|en que se me esta yendo|se me fue el dinero|alcanza|alcanzara|proyeccion|cierro el mes|cerrar el mes|resumen|diagnostico|consejo|consejos|recomendacion|recomendaciones|como voy|organizar mis gastos|planificar|planificacion|diciembre|fin de mes|dias o momentos del mes|suelo gastar mas|sin afectar lo esencial|compromet[a-z]*|estirar mi dinero|estirar el presupuesto)\b',
  );

  static final RegExp _shortFollowupCue = RegExp(
    r'^(y\s+)?(por que|porque|dime mas|cuentame mas|explica|explicame|detalla|detallalo|cuales|cual|como asi|y eso|y el resto|mas detalle|a que se debe|donde|cuanto fue|que mas|y ahora)\b',
  );

  /// Normaliza texto en español siguiendo el orden canónico del proyecto:
  /// primero mapea diacríticos latinos y luego limpia signos de puntuación.
  static String normalizeText(String input) {
    final lower = input.trim().toLowerCase();
    if (lower.isEmpty) return '';
    final noAccents = lower
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ç', 'c');
    return noAccents
        .replaceAll(_nonWordChars, ' ')
        .replaceAll(_multiSpace, ' ')
        .trim();
  }

  /// Selecciona deterministamente las señales necesarias para el turno actual.
  static ChatSignalSelection select({
    required String currentMessage,
    String? previousUserMessage,
    bool forceAllSignals = false,
    Iterable<String> knownProductNames = const [],
  }) {
    if (forceAllSignals) {
      return const ChatSignalSelection.all();
    }

    final normalized = normalizeText(currentMessage);
    if (normalized.isEmpty) {
      return const ChatSignalSelection.neutral();
    }

    // Repreguntas cortas referenciales heredan la intención del turno previo del usuario
    if (previousUserMessage != null && previousUserMessage.trim().isNotEmpty) {
      final wordCount = normalized.split(' ').length;
      if (wordCount <= 5 && _shortFollowupCue.hasMatch(normalized)) {
        final prevSelection = _classifyNormalized(
          normalizeText(previousUserMessage),
          rawMessage: previousUserMessage,
          knownProductNames: knownProductNames,
        );
        return prevSelection.copyWith(intentGroup: 'followup_inherited');
      }
    }

    return _classifyNormalized(
      normalized,
      rawMessage: currentMessage,
      knownProductNames: knownProductNames,
    );
  }

  static ChatSignalSelection _classifyNormalized(
    String normalized, {
    required String rawMessage,
    required Iterable<String> knownProductNames,
  }) {
    if (normalized.isEmpty) {
      return const ChatSignalSelection.neutral();
    }

    final bool hasQuestionMark = rawMessage.contains('?');
    final bool isQuestion = hasQuestionMark || _questionCue.hasMatch(normalized);

    final bool wantsPrevMonth = _prevMonthPattern.hasMatch(normalized);
    final bool wantsPrices = _pricesPattern.hasMatch(normalized) ||
        _mentionsKnownProductWithPriceCue(normalized, knownProductNames);
    final bool wantsAnt = _antExpensesPattern.hasMatch(normalized);
    final bool wantsFullAnalysis = _fullAnalysisPattern.hasMatch(normalized);
    final bool hasAnalyticalCue =
        wantsPrevMonth || wantsPrices || wantsAnt || wantsFullAnalysis;

    // 1. Lista de compras o registro directo de gastos -> 0 señales ocultas ni ruido
    if (!hasAnalyticalCue) {
      if (_shoppingListCue.hasMatch(normalized) ||
          _shoppingListVerb.hasMatch(normalized)) {
        return const ChatSignalSelection.directOrAction();
      }
      if (_directLookupPattern.hasMatch(normalized)) {
        return const ChatSignalSelection.directOrAction();
      }
      if (!isQuestion && _recordExpenseVerb.hasMatch(normalized)) {
        return const ChatSignalSelection.directOrAction();
      }
    }

    // 2. Análisis general, ahorro, presupuesto o ritmo
    if (wantsFullAnalysis) {
      return const ChatSignalSelection.all();
    }

    // 3. Señales analíticas específicas (combinables)
    if (wantsPrevMonth || wantsPrices || wantsAnt) {
      final String group;
      if (wantsPrevMonth && !wantsPrices && !wantsAnt) {
        group = 'prev_month';
      } else if (wantsPrices && !wantsPrevMonth && !wantsAnt) {
        group = 'prices';
      } else if (wantsAnt && !wantsPrevMonth && !wantsPrices) {
        group = 'ant_expenses';
      } else {
        group = 'analysis_or_budget';
      }

      return ChatSignalSelection(
        includeAntExpenses: wantsAnt,
        includePrevMonthComparison: wantsPrevMonth,
        includePriceFindings: wantsPrices,
        includeTemporalContext: wantsPrevMonth,
        includeTopComercios: wantsPrices,
        intentGroup: group,
      );
    }

    // 4. Consulta neutra no clasificada
    return const ChatSignalSelection.neutral();
  }

  static bool _mentionsKnownProductWithPriceCue(
    String normalizedMessage,
    Iterable<String> knownProductNames,
  ) {
    if (!_productPriceWord.hasMatch(normalizedMessage)) return false;
    for (final rawName in knownProductNames) {
      final normProd = normalizeText(rawName);
      if (normProd.length < 4) continue;
      if (normalizedMessage.contains(normProd)) {
        return true;
      }
    }
    return false;
  }
}
