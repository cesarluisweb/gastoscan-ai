import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gasto_model.dart';
import '../../domain/finance/savings_health_models.dart';
import '../../domain/finance/savings_health_calculator.dart';
import '../screens/chat_screen.dart';

class AiInsightCard extends StatelessWidget {
  final List<GastoModel> gastos;
  final double presupuestoGeneral;
  final double metaAhorro;
  final Map<String, double> totalesPorCategoria;
  final double totalGastadoMes;
  final String monedaPrincipal;
  final String monedaPresupuesto;
  final double tasaCambio;
  final VoidCallback? onChatTap;

  const AiInsightCard({
    Key? key,
    required this.gastos,
    required this.presupuestoGeneral,
    this.metaAhorro = 0.0,
    required this.totalesPorCategoria,
    required this.totalGastadoMes,
    this.monedaPrincipal = 'USD',
    this.monedaPresupuesto = 'USD',
    this.tasaCambio = 1.0,
    this.onChatTap,
  }) : super(key: key);

  String _generarMensaje() {
    final now = DateTime.now();
    final diasEnMes = DateTime(now.year, now.month + 1, 0).day;
    final diasRestantes = (diasEnMes - now.day).clamp(1, diasEnMes);
    final mesActualNombre = DateFormatter.getMonthName(now.month);

    if (gastos.isEmpty) {
      if (now.day <= 5 && presupuestoGeneral > 0) {
        return '¡Nuevo mes! Tu presupuesto de $mesActualNombre ya está listo. Hoy es un buen día para determinarte a aplicar lo aprendido el mes pasado.';
      }
      return 'Registra tu primera compra con el botón + para activar estadísticas y recomendaciones automáticas.';
    }

    final hasSavingsGoal = metaAhorro > 0;
    if (hasSavingsGoal && presupuestoGeneral > 0) {
      final savingsSnapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: presupuestoGeneral,
        metaAhorro: metaAhorro,
        gastoAcumulado: totalGastadoMes,
        diaActual: now.day,
        diasTotalesMes: diasEnMes,
        moneda: monedaPresupuesto,
      );

      final formattedMeta = CurrencyFormatter.formatPreferido(
        metaAhorro,
        null,
        tasaCambio,
        monedaPrincipal,
      );

      if (savingsSnapshot.status == SavingsGoalStatus.comprometida) {
        final exceso = savingsSnapshot.gastoAcumulado - savingsSnapshot.limiteParaGastar;
        final formattedExceso = CurrencyFormatter.formatPreferido(
          exceso,
          null,
          tasaCambio,
          monedaPrincipal,
        );
        return 'Has superado tu límite de gasto por $formattedExceso. Tu meta de ahorro de $formattedMeta está siendo comprometida.';
      }

      if (savingsSnapshot.status == SavingsGoalStatus.enRiesgo) {
        final proy = savingsSnapshot.gastoProyectadoFinDeMes;
        final formattedProy = CurrencyFormatter.formatPreferido(
          proy,
          null,
          tasaCambio,
          monedaPrincipal,
        );
        return 'Atención: a tu ritmo actual proyectas gastar $formattedProy. Modera tus consumos para proteger tu meta de ahorro de $formattedMeta.';
      }

      if (savingsSnapshot.status == SavingsGoalStatus.protegida && now.day >= 15) {
        return '¡Excelente administración! Tu ritmo de gasto mantiene tu meta de ahorro de $formattedMeta protegida.';
      }
    }

    if (presupuestoGeneral > 0) {
      final porcentaje = totalGastadoMes / presupuestoGeneral;
      final pctRedondeado = (porcentaje * 100).round();
      final diasTexto = diasRestantes == 1 ? 'falta 1 día' : 'faltan $diasRestantes días';

      if (porcentaje >= 1.0) {
        final excesoUsd = totalGastadoMes - presupuestoGeneral;
        final formattedExceso = CurrencyFormatter.formatPreferido(
          excesoUsd,
          null,
          tasaCambio,
          monedaPrincipal,
        );
        return 'Has superado tu presupuesto general por $formattedExceso. Conviene moderar consumos no esenciales.';
      }

      if (porcentaje >= 0.85) {
        return 'Atención: llevas gastado el $pctRedondeado% de tu presupuesto y $diasTexto. Modera tus gastos.';
      }

      if (porcentaje < 0.50 && now.day >= 15) {
        final diasCapTexto = diasRestantes == 1 ? 'Falta 1 día' : 'Faltan $diasRestantes días';
        if (diasRestantes <= 5) {
          return '¡Excelente cierre de mes! $diasCapTexto y solo has consumido el $pctRedondeado% de tu presupuesto. Tienes margen para ahorrar.';
        }
        return '¡Excelente administración! A más de mitad de mes solo has consumido el $pctRedondeado% de tu presupuesto. ¡Así se rinde más!';
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
        return 'Tu mayor concentración de gasto este mes está en $topCat ($pctTop% del total). Mantén su seguimiento.';
      }
    }

    if (presupuestoGeneral <= 0) {
      return 'Consejo: Asigna un presupuesto mensual en la pestaña de Análisis para monitorear tu límite en tiempo real.';
    }

    return 'Tus finanzas van al día. Registra cada compra puntualmente para mantener tus estadísticas actualizadas.';
  }

  @override
  Widget build(BuildContext context) {
    final mensaje = _generarMensaje();

    return Container(
      key: const Key('ai_insight_card'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5), // Fondo cálido sutil de IA
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEF08A)), // Borde amarillo sutil
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                onTap: onChatTap ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(showBackButton: true),
                        ),
                      );
                    },
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
          // Cuerpo Horizontal: Avatar Asistente + Mensaje
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
                  mensaje,
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
