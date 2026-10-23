import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/item_gasto_model.dart';
import 'receipt_viewer_dialog.dart';

String toTitleCase(String text) {
  if (text.isEmpty) return text;
  final isAllUpper = text == text.toUpperCase() && text.contains(RegExp(r'[A-Za-z]'));
  if (!isAllUpper) return text;

  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    if (lower == 'c.a.' || lower == 's.a.' || lower == 's.r.l.' || lower == 'c.a' || lower == 's.a') {
      return word.toUpperCase();
    }
    return lower[0].toUpperCase() + lower.substring(1);
  }).join(' ');
}

String cleanItemDescription(String desc) {
  return desc
      .replaceAll(RegExp(r'\s*\([GERgerExX]+\)\s*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*-(G|E|R)\s*$', caseSensitive: false), '')
      .trim();
}

class ExpenseCard extends StatefulWidget {
  final GastoModel gasto;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final String monedaPrincipal;
  final bool initiallyExpanded;
  final bool showDirectItemBreakdown;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;

  const ExpenseCard({
    Key? key,
    required this.gasto,
    required this.onDelete,
    required this.onEdit,
    this.monedaPrincipal = 'USD',
    this.initiallyExpanded = false,
    this.showDirectItemBreakdown = false,
    this.tasaCambio = 1.0,
    this.tasaEur = 0.0,
    this.tasaUsdt = 0.0,
  }) : super(key: key);

  @override
  State<ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<ExpenseCard> {
  bool _expanded = false;
  bool _showAllItems = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    if (widget.initiallyExpanded) {
      _showAllItems = true;
    }
  }

  @override
  void didUpdateWidget(ExpenseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
      if (widget.initiallyExpanded) {
        _showAllItems = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColors[widget.gasto.categoria] ?? AppColors.textSecondary;

    final tasa = widget.gasto.tasaCambio > 0
        ? widget.gasto.tasaCambio
        : (widget.tasaCambio > 0 ? widget.tasaCambio : 1.0);
    final double ves = widget.gasto.moneda == 'VES'
        ? widget.gasto.totalOriginalDisplay
        : widget.gasto.totalUsdDisplay * tasa;
    final double usd = widget.gasto.totalUsdDisplay;

    final primaryFormatted = CurrencyFormatter.formatPreferido(
      usd,
      ves,
      tasa,
      widget.monedaPrincipal,
      tasaEur: widget.gasto.tasaEurDisplay > 0 ? widget.gasto.tasaEurDisplay : widget.tasaEur,
      tasaUsdt: widget.gasto.tasaUsdtDisplay > 0 ? widget.gasto.tasaUsdtDisplay : widget.tasaUsdt,
      totalUsdt: widget.gasto.totalUsdtDisplay,
      totalEur: widget.gasto.totalEurDisplay,
      monedaOrigen: widget.gasto.moneda,
    );

    final secondaryFormatted = CurrencyFormatter.formatSecundario(
      usd,
      ves,
      tasa,
      widget.monedaPrincipal,
    );

    final String tasaStr = CurrencyFormatter.formatVes(tasa).replaceAll('Bs. ', '');

    final String subtitleText;
    if (!widget.showDirectItemBreakdown) {
      final fechaStr = DateFormatter.formatDate(widget.gasto.fecha);
      if (widget.gasto.items.isNotEmpty) {
        final count = widget.gasto.items.length;
        final artStr = count == 1 ? '1 artículo' : '$count artículos';
        subtitleText = '$fechaStr • $artStr';
      } else {
        subtitleText = fechaStr;
      }
    } else {
      if (widget.gasto.items.length > 1) {
        subtitleText = '${widget.gasto.items.length} artículos • Tasa $tasaStr';
      } else if (widget.gasto.items.length == 1) {
        subtitleText = '1 artículo • Tasa $tasaStr';
      } else {
        subtitleText = 'Tasa $tasaStr';
      }
    }

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
                if (widget.showDirectItemBreakdown) {
                  if (widget.gasto.items.length > 4) {
                    setState(() => _showAllItems = !_showAllItems);
                  }
                } else {
                  setState(() => _expanded = !_expanded);
                }
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  if (!widget.showDirectItemBreakdown) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppConstants.getCategoryIcon(widget.gasto.categoria),
                        color: catColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toTitleCase(widget.gasto.comercio),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                subtitleText,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.gasto.rutaFotoLocal != null && widget.gasto.rutaFotoLocal!.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.photo_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        primaryFormatted,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        secondaryFormatted,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                    color: AppColors.surface,
                    onSelected: (val) {
                      if (val == 'edit') widget.onEdit();
                      if (val == 'view_receipt' && widget.gasto.rutaFotoLocal != null && widget.gasto.rutaFotoLocal!.isNotEmpty) {
                        ReceiptViewerDialog.show(
                          context,
                          imagePath: widget.gasto.rutaFotoLocal!,
                          title: widget.gasto.comercio,
                          subtitle: DateFormatter.formatDate(widget.gasto.fecha),
                          amount: CurrencyFormatter.formatUsd(widget.gasto.totalUsdDisplay),
                        );
                      }
                      if (val == 'delete') widget.onDelete();
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
                      if (widget.gasto.rutaFotoLocal != null && widget.gasto.rutaFotoLocal!.isNotEmpty)
                        const PopupMenuItem(
                          value: 'view_receipt',
                          child: Row(
                            children: [
                              Icon(Icons.photo_outlined, color: AppColors.primaryDark, size: 18),
                              SizedBox(width: 8),
                              Text('Ver comprobante', style: TextStyle(color: AppColors.textPrimary)),
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
          if ((widget.showDirectItemBreakdown || _expanded) && widget.gasto.items.isNotEmpty) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Builder(
                builder: (context) {
                  final bool hasMoreThan4 = widget.gasto.items.length > 4;
                  final List<ItemGastoModel> itemsToShow;
                  if (widget.showDirectItemBreakdown && hasMoreThan4 && !_showAllItems) {
                    itemsToShow = widget.gasto.items.take(4).toList();
                  } else {
                    itemsToShow = widget.gasto.items;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...itemsToShow.map((it) {
                        final double itemRatio = (widget.gasto.totalOriginalDisplay > 0)
                            ? (it.totalDisplay / widget.gasto.totalOriginalDisplay)
                            : (widget.gasto.items.isNotEmpty ? (1.0 / widget.gasto.items.length) : 0.0);

                        final double itemUsd = itemRatio > 0
                            ? (widget.gasto.totalUsdDisplay * itemRatio)
                            : CurrencyFormatter.convertAmount(
                                it.totalDisplay,
                                widget.gasto.moneda,
                                'USD',
                                tasa,
                                tasaEur: widget.tasaEur,
                                tasaUsdt: widget.tasaUsdt,
                              );

                        final double itemVes = (widget.gasto.moneda == 'VES')
                            ? it.totalDisplay
                            : (itemUsd * tasa);

                        final double itemDisplay;
                        switch (widget.monedaPrincipal.toUpperCase()) {
                          case 'VES':
                            itemDisplay = itemVes;
                            break;
                          case 'EUR':
                            itemDisplay = CurrencyFormatter.convertFromUsd(
                              itemUsd,
                              'EUR',
                              tasa,
                              tasaEur: widget.tasaEur,
                              tasaUsdt: widget.tasaUsdt,
                            );
                            break;
                          case 'USDT':
                            itemDisplay = itemRatio > 0
                                ? (widget.gasto.totalUsdtDisplay * itemRatio)
                                : widget.gasto.totalUsdtDisplay;
                            break;
                          case 'USD':
                          default:
                            itemDisplay = itemUsd;
                            break;
                        }

                        final String itemText = CurrencyFormatter.formatAmount(itemDisplay, widget.monedaPrincipal);
                        final itCatColor = AppColors.categoryColors[it.categoria] ?? AppColors.textSecondary;
                        final itCatIcon = AppConstants.getCategoryIcon(it.categoria);
                        final cleanDesc = cleanItemDescription(it.descripcion);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: itCatColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(itCatIcon, size: 12, color: itCatColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${it.cantidad.toStringAsFixed(it.cantidad % 1 == 0 ? 0 : 2)}x $cleanDesc',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (it.cantidad > 1) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${it.cantidad.toStringAsFixed(it.cantidad % 1 == 0 ? 0 : 2)}x a ${CurrencyFormatter.formatAmount(itemDisplay / it.cantidad, widget.monedaPrincipal)} c/u',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                itemText,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (widget.showDirectItemBreakdown && hasMoreThan4) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: InkWell(
                            key: Key('expense_card_toggle_more_${widget.gasto.uuid}'),
                            onTap: () {
                              setState(() => _showAllItems = !_showAllItems);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.cardLighter,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _showAllItems
                                        ? 'Ver menos'
                                        : 'Ver ${widget.gasto.items.length - 4} artículos más',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _showAllItems ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
