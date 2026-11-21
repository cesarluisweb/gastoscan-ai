import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/gasto_model.dart';
import '../../providers/chat_provider.dart';
import '../../services/ai_insight_service.dart';
import '../screens/chat_screen.dart';

class AiInsightCard extends StatelessWidget {
  final List<GastoModel> gastos;
  final double presupuestoGeneral;
  final double metaAhorro;
  final Map<String, double> totalesPorCategoria;
  final Map<String, double> presupuestosPorCategoria;
  final double totalGastadoMes;
  final String monedaPresupuesto;
  final double tasaCambio;
  final int? mes;
  final int? anio;
  final VoidCallback? onChatTap;
  final DateTime? currentDate;
  final String? cachedGeminiText;
  final AiHiddenSignals? hiddenSignals;
  final ValueChanged<AiDashboardInsight>? onConsultInsight;

  const AiInsightCard({
    Key? key,
    required this.gastos,
    required this.presupuestoGeneral,
    this.metaAhorro = 0.0,
    required this.totalesPorCategoria,
    this.presupuestosPorCategoria = const {},
    required this.totalGastadoMes,
    this.monedaPresupuesto = 'USD',
    this.tasaCambio = 1.0,
    this.mes,
    this.anio,
    this.onChatTap,
    this.currentDate,
    this.cachedGeminiText,
    this.hiddenSignals,
    this.onConsultInsight,
  }) : super(key: key);

  AiDashboardInsight resolveDashboardInsight() {
    return AiInsightService.resolveInsight(
      gastos: gastos,
      presupuestoGeneral: presupuestoGeneral,
      metaAhorro: metaAhorro,
      totalesPorCategoria: totalesPorCategoria,
      presupuestosPorCategoria: presupuestosPorCategoria,
      totalGastadoMes: totalGastadoMes,
      monedaPresupuesto: monedaPresupuesto,
      tasaCambio: tasaCambio,
      mes: mes,
      anio: anio,
      currentDate: currentDate,
      cachedGeminiText: cachedGeminiText,
      hiddenSignals: hiddenSignals,
    );
  }

  void _copyInsightToClipboard(BuildContext context, String rawText) {
    final cleanText = AiInsightService.stripMarkdownForCopy(rawText);
    if (cleanText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: cleanText));
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Consejo copiado al portapapeles',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleConsultTap(BuildContext context, AiDashboardInsight insight) {
    onConsultInsight?.call(insight);

    final providerFromTree = Provider.of<ChatProvider?>(context, listen: false);
    providerFromTree?.startInsightDeepDive(insight.text);

    if (onChatTap != null) {
      onChatTap!();
    } else {
      final fallbackProvider = providerFromTree ??
          (ChatProvider()..startInsightDeepDive(insight.text));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            showBackButton: true,
            chatProvider: fallbackProvider,
          ),
        ),
      );
    }
  }

  /// Renderiza texto enriquecido convirtiendo `**negrita**` y `*cursiva*` en `TextSpan` reales,
  /// limpiando cualquier marcador Markdown huérfano para que nunca se vean asteriscos literales.
  static Widget buildFormattedText(
    String text, {
    TextStyle? baseStyle,
  }) {
    final effectiveBase = baseStyle ??
        const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.5,
          height: 1.4,
          fontWeight: FontWeight.w400,
        );

    final List<TextSpan> spans = [];
    final RegExp tokenRegex = RegExp(r'\*\*(.+?)\*\*|\*(?!\s)(.+?)(?<!\s)\*', dotAll: true);
    int lastEnd = 0;

    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        final plain = text.substring(lastEnd, match.start).replaceAll('**', '');
        if (plain.isNotEmpty) {
          spans.add(TextSpan(text: plain, style: effectiveBase));
        }
      }

      final boldGroup = match.group(1);
      final italicGroup = match.group(2);
      if (boldGroup != null) {
        spans.add(
          TextSpan(
            text: boldGroup.replaceAll('**', ''),
            style: effectiveBase.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (italicGroup != null) {
        spans.add(
          TextSpan(
            text: italicGroup,
            style: effectiveBase.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final tail = text.substring(lastEnd).replaceAll('**', '');
      if (tail.isNotEmpty) {
        spans.add(TextSpan(text: tail, style: effectiveBase));
      }
    }

    if (spans.isEmpty) {
      return Text(text.replaceAll('**', ''), style: effectiveBase);
    }

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final insight = resolveDashboardInsight();

    return Container(
      key: const Key('ai_insight_card'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5), // Fondo cálido sutil de IA
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEF08A)), // Borde amarillo sutil
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Icono Destello + "Asistente IA", botón Copiar y botón "Consultar ->"
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Asistente IA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                key: const Key('ai_insight_card_copy_btn'),
                onTap: () => _copyInsightToClipboard(context, insight.text),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.copy_outlined,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                key: const Key('ai_insight_card_consultar_btn'),
                onTap: () => _handleConsultTap(context, insight),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Consultar',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward, size: 11, color: AppColors.textPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Cuerpo limpio a ancho completo (también permite copiar manteniendo presionado)
          GestureDetector(
            onLongPress: () => _copyInsightToClipboard(context, insight.text),
            child: SizedBox(
              width: double.infinity,
              child: buildFormattedText(insight.text),
            ),
          ),
        ],
      ),
    );
  }
}
