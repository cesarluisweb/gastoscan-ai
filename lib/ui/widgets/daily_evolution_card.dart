import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/gasto_model.dart';

/// Tarjeta 2 — Evolución Diaria (Tarjeta independiente en Análisis)
/// Muestra la curva de gasto acumulado día a día contrastada contra
/// la diagonal de ritmo ideal permitido hasta fin de mes.
class DailyEvolutionCard extends StatelessWidget {
  final List<GastoModel> gastosMes;
  final double totalGastadoMes;
  final double limitePresupuesto;
  final String monedaPrincipal;
  final int anio;
  final int mes;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;

  const DailyEvolutionCard({
    Key? key,
    required this.gastosMes,
    required this.totalGastadoMes,
    this.limitePresupuesto = 0.0,
    this.monedaPrincipal = 'USD',
    required this.anio,
    required this.mes,
    this.tasaCambio = 1.0,
    this.tasaEur = 0.0,
    this.tasaUsdt = 0.0,
  }) : super(key: key);

  String _fmt(double val) => CurrencyFormatter.formatAmount(val, monedaPrincipal);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool isCurrentMonth = (now.year == anio && now.month == mes);
    final bool isPastMonth = (anio < now.year) || (anio == now.year && mes < now.month);
    final int totalDiasMes = DateTime(anio, mes + 1, 0).day;
    final int maxDia = isCurrentMonth
        ? now.day.clamp(1, totalDiasMes)
        : (isPastMonth ? totalDiasMes : 1);

    // 1. Agrupar montos convertidos a la moneda activa por día
    final Map<int, double> gastosPorDia = {};
    for (final g in gastosMes) {
      final d = DateTime.tryParse(g.fecha);
      if (d != null && d.year == anio && d.month == mes) {
        final double monto;
        if (monedaPrincipal == 'VES') {
          if (g.moneda == 'VES') {
            monto = g.totalOriginalDisplay;
          } else {
            final rate = g.tasaCambio > 0 ? g.tasaCambio : (tasaCambio > 0 ? tasaCambio : 1.0);
            monto = g.totalUsdDisplay * rate;
          }
        } else if (monedaPrincipal == 'USDT') {
          monto = (g.totalUsdt != null && g.totalUsdt! > 0)
              ? g.totalUsdtDisplay
              : g.totalUsdDisplay;
        } else if (monedaPrincipal == 'EUR') {
          final eurRate = tasaEur > 0 ? tasaEur : (tasaCambio > 0 ? tasaCambio : 1.0);
          if (g.moneda == 'VES') {
            monto = eurRate > 0 ? g.totalOriginalDisplay / eurRate : g.totalUsdDisplay;
          } else {
            monto = CurrencyFormatter.convertFromUsd(
              g.totalUsdDisplay,
              'EUR',
              tasaCambio,
              tasaEur: tasaEur,
              tasaUsdt: tasaUsdt,
            );
          }
        } else {
          // USD
          monto = g.totalUsdDisplay;
        }
        gastosPorDia[d.day] = (gastosPorDia[d.day] ?? 0.0) + monto;
      }
    }

    // 2. Curva acumulada día a día
    double running = 0.0;
    final List<FlSpot> actualSpots = [];
    for (int dia = 1; dia <= maxDia; dia++) {
      running += (gastosPorDia[dia] ?? 0.0);
      actualSpots.add(FlSpot(dia.toDouble(), running));
    }

    final double gastoActual = totalGastadoMes > 0 ? totalGastadoMes : running;
    final bool hasBudget = limitePresupuesto > 0;
    final bool isExceeded = hasBudget && (gastoActual > limitePresupuesto);
    final double ritmoEsperado = hasBudget ? (limitePresupuesto / totalDiasMes) * maxDia : 0.0;
    final bool isOverRhythm = hasBudget && (gastoActual > ritmoEsperado);

    // 3. Subtítulo dinámico
    final String subtitulo;
    if (hasBudget) {
      if (isPastMonth) {
        subtitulo = isExceeded
            ? 'Cerró por encima del límite presupuestado'
            : 'Cerró dentro del límite presupuestado';
      } else {
        if (isExceeded) {
          subtitulo = 'Has superado el límite total del mes';
        } else if (isOverRhythm) {
          subtitulo = 'Vas por encima del ritmo límite esperado a la fecha';
        } else {
          subtitulo = 'Vas por debajo del ritmo límite esperado a la fecha';
        }
      }
    } else {
      subtitulo = isPastMonth
          ? 'Evolución final del gasto en el mes'
          : 'Gasto acumulado día a día a lo largo del mes';
    }

    final Color actualLineColor = isExceeded
        ? AppColors.error
        : const Color(0xFF1E293B); // Tono pizarra oscuro

    // 4. Línea ideal (diagonal punteada de día 1 a fin de mes)
    final List<LineChartBarData> lines = [];
    if (hasBudget) {
      lines.add(
        LineChartBarData(
          spots: [
            const FlSpot(1, 0),
            FlSpot(totalDiasMes.toDouble(), limitePresupuesto),
          ],
          isCurved: false,
          color: const Color(0xFF94A3B8), // Gris slate suave
          barWidth: 1.8,
          dashArray: [5, 5],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    // Línea real acumulativa
    final actualBarData = LineChartBarData(
      spots: actualSpots.isNotEmpty ? actualSpots : [const FlSpot(1, 0)],
      isCurved: false,
      color: actualLineColor,
      barWidth: 2.8,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) {
          return barData.spots.isNotEmpty && spot == barData.spots.last;
        },
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 5,
            color: actualLineColor,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: actualLineColor.withValues(alpha: 0.05),
      ),
    );
    lines.add(actualBarData);

    final double maxY = math.max(
      limitePresupuesto,
      math.max(gastoActual, 10.0),
    ) * 1.15;

    return Container(
      key: const Key('card_daily_evolution'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
          // Cabecera: Título y Badge del monto actual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Evolución Diaria',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cardLighter,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                ),
                child: Text(
                  _fmt(gastoActual),
                  key: const Key('daily_evolution_current_spent'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Gráfico de línea
          SizedBox(
            height: 175,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: totalDiasMes.toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? (maxY / 3) : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.6),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        final valInt = value.toInt();
                        final esFinDeMes = valInt == totalDiasMes;
                        // En meses de 31 días se omite el d30 para evitar el solapamiento visual "d30d31"
                        final esMultiplo5NoColisionante = (valInt % 5 == 0) && (totalDiasMes - valInt > 1);
                        if (valInt == 1 || esMultiplo5NoColisionante || esFinDeMes) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'd$valInt',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lines,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final bool isActual = spot.barIndex == (lines.length - 1);
                        if (!isActual) {
                          return LineTooltipItem(
                            'Ideal: ${_fmt(spot.y)}',
                            const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          );
                        }
                        return LineTooltipItem(
                          'Día ${spot.x.toInt()}: ${_fmt(spot.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),

          if (hasBudget) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 2,
                  decoration: const BoxDecoration(
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Ritmo límite permitido',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 14,
                  height: 3,
                  decoration: BoxDecoration(
                    color: actualLineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Gasto acumulado',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
