import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gasto_model.dart';

class ExpenseCard extends StatefulWidget {
  final GastoModel gasto;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ExpenseCard({
    Key? key,
    required this.gasto,
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

  @override
  State<ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<ExpenseCard> {
  bool _expanded = false;

  IconData _getCategoryIcon(String categoria) {
    switch (categoria) {
      case 'Alimentación':
        return Icons.shopping_cart_outlined;
      case 'Salud':
        return Icons.medical_services_outlined;
      case 'Higiene':
        return Icons.cleaning_services_outlined;
      case 'Educación':
        return Icons.school_outlined;
      case 'Hogar':
        return Icons.home_outlined;
      case 'Servicios':
        return Icons.receipt_long_outlined;
      case 'Transporte':
        return Icons.directions_car_outlined;
      default:
        return Icons.attach_money_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColors[widget.gasto.categoria] ?? AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (widget.gasto.items.isNotEmpty) {
                setState(() => _expanded = !_expanded);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(widget.gasto.categoria),
                      color: catColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.gasto.comercio,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormatter.formatDate(widget.gasto.fecha),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatUsd(widget.gasto.totalUsdDisplay),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.gasto.moneda != 'USD')
                        Text(
                          CurrencyFormatter.formatAmount(
                            widget.gasto.totalOriginalDisplay,
                            widget.gasto.moneda,
                          ),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                    color: AppColors.surface,
                    onSelected: (val) {
                      if (val == 'delete') widget.onDelete();
                      if (val == 'edit') widget.onEdit();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: AppColors.primaryDark, size: 18),
                            SizedBox(width: 8),
                            Text('Editar', style: TextStyle(color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.gasto.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.cardLighter,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desglose de Ítems:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.gasto.items.map((it) {
                    double itemUsd = it.totalDisplay;
                    if (widget.gasto.moneda != 'USD' && widget.gasto.totalOriginalDisplay > 0) {
                      itemUsd = it.totalDisplay * (widget.gasto.totalUsdDisplay / widget.gasto.totalOriginalDisplay);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              '${it.cantidad.toStringAsFixed(it.cantidad % 1 == 0 ? 0 : 2)}x ${it.descripcion}',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              it.categoria,
                              style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatUsd(itemUsd),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
