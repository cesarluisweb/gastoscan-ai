import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'budget_bottom_sheet.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/finance/savings_health_models.dart';
import '../../domain/finance/savings_health_calculator.dart';
import '../../providers/settings_provider.dart';

class SummaryCard extends StatelessWidget {
  final double totalUsd;
  final double totalVes;
  final double totalUsdt;
  final String periodo;
  final String monedaPrincipal;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;
  final double presupuestoGeneral;
  final double metaAhorro;
  final String monedaPresupuesto;
  final int? mes;
  final int? anio;
  final ValueChanged<String>? onMonedaChanged;

  const SummaryCard({
    Key? key,
    required this.totalUsd,
    required this.totalVes,
    this.totalUsdt = 0.0,
    required this.periodo,
    this.monedaPrincipal = 'USD',
    this.tasaCambio = 1.0,
    this.tasaEur = 0.0,
    this.tasaUsdt = 0.0,
    this.presupuestoGeneral = 0.0,
    this.metaAhorro = 0.0,
    this.monedaPresupuesto = 'USD',
    this.mes,
    this.anio,
    this.onMonedaChanged,
  }) : super(key: key);

  double _convertBudgetToLens(double amount) {
    if (amount <= 0) return 0.0;
    if (monedaPresupuesto == monedaPrincipal) return amount;

    final double usdRate = tasaCambio > 0 ? tasaCambio : 1.0;
    final double eurRate = tasaEur > 0 ? tasaEur : usdRate;

    double inUsd = amount;
    if (monedaPresupuesto == 'VES') {
      inUsd = amount / usdRate;
    } else if (monedaPresupuesto == 'EUR') {
      inUsd = (amount * eurRate) / usdRate;
    } else if (monedaPresupuesto == 'USDT') {
      inUsd = amount;
    }

    if (monedaPrincipal == 'USD' || monedaPrincipal == 'USDT') {
      return inUsd;
    } else if (monedaPrincipal == 'VES') {
      return inUsd * usdRate;
    } else if (monedaPrincipal == 'EUR') {
      return eurRate > 0 ? (inUsd * usdRate) / eurRate : inUsd;
    }
    return amount;
  }

  @override
  Widget build(BuildContext context) {
    final double usdtEff = totalUsdt > 0 ? totalUsdt : totalUsd;
    final textoPrincipal = CurrencyFormatter.formatPreferido(
      totalUsd,
      totalVes > 0 ? totalVes : null,
      tasaCambio,
      monedaPrincipal,
      tasaEur: tasaEur,
      tasaUsdt: tasaUsdt,
      totalUsdt: totalUsdt > 0 ? totalUsdt : null,
    );

    final textoSecundario = CurrencyFormatter.formatSecundario(
      totalUsd,
      totalVes > 0 ? totalVes : null,
      tasaCambio,
      monedaPrincipal,
    );

    final hasBudget = presupuestoGeneral > 0;
    final hasSavingsGoal = metaAhorro > 0;

    final double usdRate = tasaCambio > 0 ? tasaCambio : 1.0;
    final double eurRate = tasaEur > 0 ? tasaEur : usdRate;
    final double vesEquiv = totalVes > 0 ? totalVes : (totalUsd * usdRate);

    final double effectiveSpent;
    if (monedaPrincipal == 'VES') {
      effectiveSpent = vesEquiv;
    } else if (monedaPrincipal == 'USDT') {
      effectiveSpent = usdtEff;
    } else if (monedaPrincipal == 'EUR') {
      effectiveSpent = eurRate > 0 ? (vesEquiv / eurRate) : totalUsd;
    } else {
      effectiveSpent = totalUsd;
    }

    final double budgetInLens = _convertBudgetToLens(presupuestoGeneral);
    final double metaInLens = _convertBudgetToLens(metaAhorro);

    final limiteParaGastar = hasSavingsGoal
        ? (budgetInLens - metaInLens).clamp(0.0, double.infinity)
        : budgetInLens;

    final targetBudget = hasSavingsGoal ? limiteParaGastar : budgetInLens;
    final percentUsed = (hasBudget && targetBudget > 0) ? (effectiveSpent / targetBudget) : 0.0;
    final isOverBudget = hasBudget && (effectiveSpent > targetBudget);

    final now = DateTime.now();
    final targetYear = anio ?? now.year;
    final targetMonth = mes ?? now.month;
    final isCurrentMonth = (mes == null || anio == null) ||
        (now.month == targetMonth && now.year == targetYear);
    final isPastMonth = targetYear < now.year ||
        (targetYear == now.year && targetMonth < now.month);
    final totalDaysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final daysRemaining = isCurrentMonth
        ? (totalDaysInMonth - now.day).clamp(0, 31)
        : (isPastMonth ? 0 : totalDaysInMonth);
    final daysForCalculation = daysRemaining > 0 ? daysRemaining : 1;

    // Métricas para la fila inferior compacta proyectadas al lente activo
    final rem = (targetBudget - effectiveSpent).clamp(0.0, double.infinity);
    final ritmoDiario = rem / daysForCalculation;
    final diasTexto = daysRemaining == 1 ? 'Falta 1 día' : 'Faltan $daysRemaining días';
    final remFormatted = CurrencyFormatter.formatAmount(rem, monedaPrincipal);
    final ritmoFormatted = CurrencyFormatter.formatAmount(ritmoDiario, monedaPrincipal);
    final budgetFormatted = CurrencyFormatter.formatAmount(budgetInLens, monedaPrincipal);
    final limiteFormatted = CurrencyFormatter.formatAmount(limiteParaGastar, monedaPrincipal);
    final excessFormatted = CurrencyFormatter.formatAmount(
      (effectiveSpent - targetBudget).clamp(0.0, double.infinity),
      monedaPrincipal,
    );

    final snapshot = hasSavingsGoal
        ? SavingsHealthCalculator.calculate(
            presupuestoGeneral: budgetInLens,
            metaAhorro: metaInLens,
            gastoAcumulado: effectiveSpent,
            diaActual: isCurrentMonth ? now.day : (isPastMonth ? totalDaysInMonth : 1),
            diasTotalesMes: totalDaysInMonth,
            moneda: monedaPrincipal,
          )
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: "Total gastado" y "Presupuesto: $X"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total gastado',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasBudget)
                Flexible(
                  child: InkWell(
                    key: const Key('summary_card_edit_budget_btn'),
                    onTap: () => BudgetBottomSheet.show(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardLighter,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              hasSavingsGoal
                                  ? 'Límite: $limiteFormatted'
                                  : 'Presupuesto: $budgetFormatted',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                InkWell(
                  key: const Key('summary_card_set_budget_btn'),
                  onTap: () => BudgetBottomSheet.show(context),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '+ Definir presupuesto',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila Monto Principal + Selector Desplegable Flotante (Estilo Binance)
          () {
            final lenses = [
              {'id': 'USD', 'label': 'USD BCV'},
              {'id': 'VES', 'label': 'Bs.'},
              {'id': 'USDT', 'label': 'USDT P2P'},
              {'id': 'EUR', 'label': 'EUR BCV'},
            ];
            final displayMainAmount = monedaPrincipal == 'VES'
                ? textoPrincipal.replaceFirst('Bs. ', '')
                : textoPrincipal;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayMainAmount,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCurrencyDropdown(context, lenses),
              ],
            );
          }(),
          const SizedBox(height: 2),
          // Monto Secundario (Bs. / USD) limpio con ≈
          Text(
            '≈ $textoSecundario',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 16),
            // Fila informativa: Disponible / Excedido a la izquierda, Porcentaje a la derecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOverBudget ? 'Excedido: ' : 'Disponible: ',
                          style: TextStyle(
                            color: isOverBudget ? AppColors.error : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          isOverBudget ? excessFormatted : remFormatted,
                          style: TextStyle(
                            color: isOverBudget ? AppColors.error : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(percentUsed * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isOverBudget ? AppColors.error : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Barra de progreso a todo el ancho de la tarjeta
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentUsed.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.cardLighter,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.getBudgetProgressColor(percentUsed, isExceeded: isOverBudget),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Fila inferior de datos secundarios (Ritmo a la izquierda, Meta/Días a la derecha)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Lado izquierdo: Ritmo sugerido corto y seguro
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isOverBudget
                          ? (hasSavingsGoal ? 'Límite superado' : 'Presupuesto superado')
                          : (isPastMonth ? 'Mes finalizado' : 'Ritmo: $ritmoFormatted/día'),
                      style: TextStyle(
                        color: isOverBudget ? AppColors.error : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Lado derecho: Meta con cochinito coloreado o días restantes
                if (hasSavingsGoal && snapshot != null) ...[
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Builder(
                        builder: (context) {
                          Color iconColor;
                          switch (snapshot.status) {
                            case SavingsGoalStatus.protegida:
                              iconColor = const Color(0xFF2E7D32);
                              break;
                            case SavingsGoalStatus.enRiesgo:
                              iconColor = const Color(0xFFB45309);
                              break;
                            case SavingsGoalStatus.comprometida:
                              iconColor = const Color(0xFFC62828);
                              break;
                            case SavingsGoalStatus.sinMeta:
                              iconColor = AppColors.textSecondary;
                              break;
                          }
                          final metaFormatted = CurrencyFormatter.formatAmount(metaInLens, monedaPrincipal);

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.savings_outlined,
                                size: 14,
                                color: iconColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Meta: $metaFormatted',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ] else if (isCurrentMonth) ...[
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        diasTexto,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(
    BuildContext context,
    List<Map<String, String>> lenses,
  ) {
    SettingsProvider? settings;
    try {
      settings = Provider.of<SettingsProvider>(context, listen: false);
    } catch (_) {
      settings = null;
    }
    final current = settings?.monedaPrincipal ?? monedaPrincipal;
    final activeLens = lenses.firstWhere(
      (l) => l['id'] == current,
      orElse: () => {'id': 'USD', 'label': 'USD BCV'},
    );

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        key: const Key('summary_card_lens_dropdown'),
        tooltip: 'Cambiar moneda',
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        offset: const Offset(0, 36),
        onSelected: (id) {
          HapticFeedback.selectionClick();
          if (onMonedaChanged != null) {
            onMonedaChanged!(id);
          } else {
            settings?.setMonedaPrincipal(id);
          }
        },
        itemBuilder: (BuildContext ctx) {
          return lenses.map((l) {
            final id = l['id']!;
            final label = l['label']!;
            final isSelected = current == id;
            return PopupMenuItem<String>(
              key: Key('lens_switch_${id.toLowerCase()}'),
              value: id,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardLighter,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activeLens['label'] ?? 'USD BCV',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
