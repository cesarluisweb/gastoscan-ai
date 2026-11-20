import 'package:flutter/material.dart';
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
  final String? cachedGeminiShort;
  final String? cachedGeminiDetailed;
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
    this.cachedGeminiShort,
    this.cachedGeminiDetailed,
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
      cachedGeminiShort: cachedGeminiShort,
      cachedGeminiDetailed: cachedGeminiDetailed,
    );
  }

  void _handleConsultTap(BuildContext context, AiDashboardInsight insight) {
    onConsultInsight?.call(insight);

    final providerFromTree = Provider.of<ChatProvider?>(context, listen: false);
    providerFromTree?.presentDetailedInsight(insight.detailedText);

    if (onChatTap != null) {
      onChatTap!();
    } else {
      final fallbackProvider = providerFromTree ??
          (ChatProvider()..presentDetailedInsight(insight.detailedText));
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
          // Cabecera: Icono Destello + "Asistente IA" y botón "Consultar ->"
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              const Text(
                'Asistente IA',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
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
          // Cuerpo Horizontal: Avatar Asistente + Mensaje único
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3), // Amarillo fondo avatar
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE047), width: 1),
                ),
                child: const Center(
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  insight.shortText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
