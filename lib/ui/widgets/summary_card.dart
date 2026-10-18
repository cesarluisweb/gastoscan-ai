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

    final hasBudget = presupuestoGeneral > 0;
    final hasSavingsGoal = metaAhorro > 0;

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

    final rem = (targetBudget - effectiveSpent).clamp(0.0, double.infinity);
    final excess = (effectiveSpent - targetBudget).clamp(0.0, double.infinity);

    final spentFormatted = CurrencyFormatter.formatAmount(effectiveSpent, monedaPrincipal);
    final targetFormatted = CurrencyFormatter.formatAmount(targetBudget, monedaPrincipal);
    final remFormatted = CurrencyFormatter.formatAmount(rem, monedaPrincipal);
    final excessFormatted = CurrencyFormatter.formatAmount(excess, monedaPrincipal);
    final metaFormatted = CurrencyFormatter.formatAmount(metaInLens, monedaPrincipal);

    String formatSecundarioAmount(double amountInLens) {
      if (monedaPrincipal == 'VES') {
        final inUsd = amountInLens / usdRate;
        return CurrencyFormatter.formatUsd(inUsd);
      } else {
        final inVes = amountInLens * usdRate;
        return CurrencyFormatter.formatVes(inVes);
      }
    }

    final snapshot = hasSavingsGoal
        ? SavingsHealthCalculator.calculate(
            presupuestoGeneral: budgetInLens,
            metaAhorro: metaInLens,
            gastoAcumulado: effectiveSpent,
            diaActual: isCurrentMonth ? now.day : DateTime(targetYear, targetMonth + 1, 0).day,
            diasTotalesMes: DateTime(targetYear, targetMonth + 1, 0).day,
            moneda: monedaPrincipal,
          )
        : null;

    final lenses = [
      {'id': 'USD', 'label': 'USD BCV'},
      {'id': 'VES', 'label': 'Bs.'},
      {'id': 'USDT', 'label': 'USDT P2P'},
      {'id': 'EUR', 'label': 'EUR BCV'},
    ];

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
          // ========================================================
          // 1. ESTADO SIN PRESUPUESTO DEFINIDO
          // ========================================================
          if (!hasBudget) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Total gastado',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _buildCurrencyDropdown(context, lenses),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                spentFormatted,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '≈ ${formatSecundarioAmount(effectiveSpent)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('summary_card_set_budget_btn'),
              onTap: () => BudgetBottomSheet.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15), // Amarillo de acento
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '+ Definir presupuesto del mes',
                    style: TextStyle(
                      color: Color(0xFF0F172A), // Texto oscuro
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            // ========================================================
            // 2. ESTADO CON PRESUPUESTO DEFINIDO
            // ========================================================
            // Fila superior: Disponible para gastar / Pastilla Excedido <---> Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!isOverBudget)
                  Text(
                    isPastMonth ? 'Te sobraron' : 'Disponible para gastar',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2), // Fondo rojo suave
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasSavingsGoal ? 'Excedido del límite' : 'Excedido del presupuesto',
                      style: const TextStyle(
                        color: Color(0xFFDC2626), // Texto rojo negrita
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                _buildCurrencyDropdown(context, lenses),
              ],
            ),
            const SizedBox(height: 6),
            // Monto protagonista (32sp negrita)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isOverBudget ? '- $excessFormatted' : remFormatted,
                style: TextStyle(
                  color: isOverBudget ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Equivalente secundario del monto protagonista
            Text(
              '≈ ${formatSecundarioAmount(isOverBudget ? excess : rem)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Fila de contexto sobre la barra (Gastado vs Límite)
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Izquierda: Gastado: $ X
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        children: [
                          const TextSpan(text: 'Gastado: ', style: TextStyle(fontWeight: FontWeight.w500)),
                          TextSpan(
                            text: spentFormatted,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Derecha (tocable): Límite: $ Y ✏️
                Flexible(
                  child: InkWell(
                    key: const Key('summary_card_edit_budget_btn'),
                    onTap: () => BudgetBottomSheet.show(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasSavingsGoal ? 'Límite: ' : 'Presupuesto: ',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              targetFormatted,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Barra de progreso con marcador vertical de ahorro
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final double rawLimiteRatio = budgetInLens > 0 ? (limiteParaGastar / budgetInLens) : 1.0;
                final double savingsMarkerPos = (totalWidth * rawLimiteRatio).clamp(0.0, totalWidth);

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // Barra lineal redondeada de 10dp de alto
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: percentUsed.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: AppColors.cardLighter,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget
                              ? AppColors.error
                              : AppColors.getBudgetProgressColor(percentUsed, isExceeded: false),
                        ),
                      ),
                    ),
                    // Marcador vertical gris oscuro sobresaliendo 3dp arriba y abajo
                    if (hasSavingsGoal)
                      Positioned(
                        left: savingsMarkerPos - 1.0,
                        top: -3,
                        bottom: -3,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B5563), // Gris oscuro nítido
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // Divisor sutil y Pie de Meta de ahorro (si hasSavingsGoal es true)
            if (hasSavingsGoal) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final bool isInvading = effectiveSpent > limiteParaGastar;
                  final bool isEnRiesgo = snapshot?.status == SavingsGoalStatus.enRiesgo;

                  final Color dotColor;
                  final String statusText;
                  final Color statusTextColor;

                  if (isInvading || snapshot?.status == SavingsGoalStatus.comprometida) {
                    dotColor = AppColors.error;
                    statusText = 'En riesgo';
                    statusTextColor = AppColors.error;
                  } else if (isEnRiesgo) {
                    dotColor = const Color(0xFFD97706);
                    statusText = 'En riesgo';
                    statusTextColor = const Color(0xFFD97706);
                  } else {
                    dotColor = const Color(0xFFF59E0B);
                    statusText = 'Protegida';
                    statusTextColor = const Color(0xFF16A34A);
                  }

                  return Row(
                    children: [
                      Icon(
                        Icons.savings_outlined,
                        size: 16,
                        color: dotColor,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Meta de ahorro: ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        metaFormatted,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' · $statusText',
                        style: TextStyle(
                          color: statusTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
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
        offset: const Offset(0, 32),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.cardLighter.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activeLens['label'] ?? 'USD BCV',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
