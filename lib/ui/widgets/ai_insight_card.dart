import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/gasto_model.dart';
import '../screens/chat_screen.dart';

class AiInsightCard extends StatelessWidget {
  final List<GastoModel> gastos;
  final double presupuestoGeneral;
  final Map<String, double> totalesPorCategoria;
  final double totalGastadoMes;
  final String monedaPrincipal;
  final double tasaCambio;
  final VoidCallback? onChatTap;

  const AiInsightCard({
    Key? key,
    required this.gastos,
    required this.presupuestoGeneral,
    required this.totalesPorCategoria,
    required this.totalGastadoMes,
    this.monedaPrincipal = 'USD',
    this.tasaCambio = 1.0,
    this.onChatTap,
  }) : super(key: key);

  String _generarMensaje() {
    final now = DateTime.now();
    final diasEnMes = DateTime(now.year, now.month + 1, 0).day;
    final diasRestantes = (diasEnMes - now.day).clamp(1, diasEnMes);

    if (gastos.isEmpty) {
      return 'Registra tu primera compra con el botón + para activar estadísticas y recomendaciones automáticas.';
    }

    if (presupuestoGeneral > 0) {
      final porcentaje = totalGastadoMes / presupuestoGeneral;
      final pctRedondeado = (porcentaje * 100).round();

      if (porcentaje >= 1.0) {
        final excesoUsd = totalGastadoMes - presupuestoGeneral;
        final formattedExceso = monedaPrincipal == 'VES'
            ? CurrencyFormatter.formatVes(excesoUsd * (tasaCambio > 0 ? tasaCambio : 1.0))
            : CurrencyFormatter.formatUsd(excesoUsd);
        return 'Has superado tu presupuesto general por $formattedExceso. Revisa tus gastos para identificar dónde puedes reducir consumos.';
      }

      if (porcentaje >= 0.85) {
        return 'Atención: llevas gastado el $pctRedondeado% de tu presupuesto y faltan $diasRestantes días para fin de mes. Conviene moderar los gastos no esenciales.';
      }

      if (porcentaje < 0.50 && now.day >= 15) {
        return '¡Excelente administración! A más de mitad de mes solo has consumido el $pctRedondeado% de tu presupuesto estimado. ¡Así se rinde más!';
      }
    }

    if (totalesPorCategoria.isNotEmpty && totalGastadoMes > 0) {
      String? topCat;
      double topMonto = 0.0;
      totalesPorCategoria.forEach((cat, monto) {
        if (monto > topMonto) {
          topMonto = monto;
          topCat = cat;
        }
      });

      if (topCat != null && topMonto > 0) {
        final pctTop = ((topMonto / totalGastadoMes) * 100).round();
        return 'Tu mayor concentración de gasto este mes está en $topCat ($pctTop% del total). Mantén un seguimiento constante de esta categoría.';
      }
    }

    if (presupuestoGeneral <= 0) {
      return 'Consejo: Asigna un presupuesto mensual en la pestaña de Análisis para monitorear tu límite de gasto en tiempo real.';
    }

    return 'Tus finanzas van al día. Registra cada compra puntualmente para mantener tus estadísticas actualizadas.';
  }

  @override
  Widget build(BuildContext context) {
    final mensaje = _generarMensaje();

    return Container(
      key: const Key('ai_insight_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Asistente IA',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onChatTap ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(showBackButton: true),
                        ),
                      );
                    },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Consultar',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.secondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mensaje,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
