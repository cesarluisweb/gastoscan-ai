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
  final String monedaPresupuesto;
  final double tasaCambio;
  final int? mes;
  final int? anio;
  final VoidCallback? onChatTap;
  final DateTime? currentDate;

  const AiInsightCard({
    Key? key,
    required this.gastos,
    required this.presupuestoGeneral,
    this.metaAhorro = 0.0,
    required this.totalesPorCategoria,
    required this.totalGastadoMes,
    this.monedaPresupuesto = 'USD',
    this.tasaCambio = 1.0,
    this.mes,
    this.anio,
    this.onChatTap,
    this.currentDate,
  }) : super(key: key);

  String _generarMensaje() {
    final now = currentDate ?? DateTime.now();
    final targetYear = anio ?? now.year;
    final targetMonth = mes ?? now.month;
    final diasEnMes = DateTime(targetYear, targetMonth + 1, 0).day;
    final isPastMonth = targetYear < now.year ||
        (targetYear == now.year && targetMonth < now.month);
    final isCurrentMonth = targetYear == now.year && targetMonth == now.month;
    final diasRestantes = isCurrentMonth
        ? (diasEnMes - now.day).clamp(1, diasEnMes)
        : 1;
    final mesActualNombre = DateFormatter.getMonthName(targetMonth);

    if (gastos.isEmpty) {
      if (now.day <= 5 && presupuestoGeneral > 0 && isCurrentMonth) {
        return '¡Nuevo mes! Tu presupuesto de $mesActualNombre ya está listo. Hoy es un buen día para determinarte a aplicar lo aprendido el mes pasado.';
      }
      return 'Registra tu primera compra con el botón + para activar estadísticas y recomendaciones automáticas.';
    }

    if (presupuestoGeneral <= 0) {
      return 'Define un presupuesto mensual y te diré cuánto puedes gastar cada día sin descuidar tu ahorro.';
    }

    final hasSavingsGoal = metaAhorro > 0;
    final limiteParaGastar = hasSavingsGoal
        ? (presupuestoGeneral - metaAhorro).clamp(0.0, double.infinity)
        : presupuestoGeneral;

    final formattedMeta = CurrencyFormatter.formatAmount(
      metaAhorro,
      monedaPresupuesto,
    );

    // Caso: Mes pasado cerrado
    if (isPastMonth) {
      if (totalGastadoMes > limiteParaGastar) {
        final exceso = totalGastadoMes - limiteParaGastar;
        final formattedExceso = CurrencyFormatter.formatAmount(
          exceso,
          monedaPresupuesto,
        );
        return 'En $mesActualNombre superaste tu ${hasSavingsGoal ? "límite" : "presupuesto"} por $formattedExceso.';
      } else {
        final rem = limiteParaGastar - totalGastadoMes;
        final formattedRem = CurrencyFormatter.formatAmount(
          rem,
          monedaPresupuesto,
        );
        return '¡Mes cerrado con éxito! Te sobraron $formattedRem de tu ${hasSavingsGoal ? "límite" : "presupuesto"}.';
      }
    }

    // Caso: Excedido en el mes actual
    if (totalGastadoMes > limiteParaGastar) {
      final exceso = totalGastadoMes - limiteParaGastar;
      final formattedExceso = CurrencyFormatter.formatAmount(
        exceso,
        monedaPresupuesto,
      );
      if (hasSavingsGoal) {
        return 'Superaste tu límite por $formattedExceso. Tu meta de ahorro de $formattedMeta está comprometida; te sugiero pausar gastos no esenciales.';
      } else {
        return 'Superaste tu presupuesto por $formattedExceso. Te sugiero pausar gastos no esenciales esta semana.';
      }
    }

    // Caso: En riesgo por ritmo proyectado (con meta de ahorro)
    if (hasSavingsGoal) {
      final savingsSnapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: presupuestoGeneral,
        metaAhorro: metaAhorro,
        gastoAcumulado: totalGastadoMes,
        diaActual: now.day,
        diasTotalesMes: diasEnMes,
        moneda: monedaPresupuesto,
      );

      if (savingsSnapshot.status == SavingsGoalStatus.enRiesgo) {
        final proy = savingsSnapshot.gastoProyectadoFinDeMes;
        final formattedProy = CurrencyFormatter.formatAmount(
          proy,
          monedaPresupuesto,
        );
        return 'Atención: a tu ritmo actual proyectas gastar $formattedProy. Modera tus consumos para proteger tu meta de ahorro de $formattedMeta.';
      }
    }

    // Caso: Ritmo saludable con presupuesto
    final disponible = limiteParaGastar - totalGastadoMes;
    final ritmoDiario = disponible / diasRestantes;
    final formattedRitmo = CurrencyFormatter.formatAmount(
      ritmoDiario,
      monedaPresupuesto,
    );
    final diasTexto = diasRestantes == 1
        ? 'el día restante'
        : 'los $diasRestantes días restantes';

    if (hasSavingsGoal) {
      return '¡Excelente administración! Puedes gastar hasta $formattedRitmo/día durante $diasTexto sin tocar tu meta de $formattedMeta protegida.';
    } else {
      return '¡Excelente administración! Puedes gastar hasta $formattedRitmo/día durante $diasTexto sin exceder tu presupuesto.';
    }
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
