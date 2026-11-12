import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class MoreToolsGrid extends StatelessWidget {
  final int shoppingListPendingCount;
  final int receiptCountMonth;
  final String monthName;
  final VoidCallback onOpenShoppingList;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenReceipts;
  final VoidCallback onOpenChat;

  const MoreToolsGrid({
    Key? key,
    required this.shoppingListPendingCount,
    required this.receiptCountMonth,
    required this.monthName,
    required this.onOpenShoppingList,
    required this.onOpenCalculator,
    required this.onOpenReceipts,
    required this.onOpenChat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shoppingSubtitle = shoppingListPendingCount > 0
        ? '$shoppingListPendingCount ${shoppingListPendingCount == 1 ? 'pendiente' : 'pendientes'}'
        : 'Prepara tus compras';

    final receiptSubtitle = receiptCountMonth > 0
        ? '$receiptCountMonth ${receiptCountMonth == 1 ? 'foto' : 'fotos'} en $monthName'
        : '0 fotos en $monthName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'HERRAMIENTAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                key: const Key('more_menu_shopping_list'),
                icon: Icons.shopping_cart_outlined,
                title: 'Lista de Compras',
                subtitle: shoppingSubtitle,
                isPrimaryHighlight: false,
                onTap: onOpenShoppingList,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToolCard(
                key: const Key('more_menu_currency_calculator'),
                icon: Icons.calculate_outlined,
                title: 'Calculadora',
                subtitle: 'Bs. ⇄ Divisas',
                isPrimaryHighlight: false,
                onTap: onOpenCalculator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                key: const Key('more_menu_view_receipts'),
                icon: Icons.photo_library_outlined,
                title: 'Comprobantes',
                subtitle: receiptSubtitle,
                isPrimaryHighlight: false,
                onTap: onOpenReceipts,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToolCard(
                key: const Key('more_menu_chat_ai'),
                icon: Icons.auto_awesome,
                title: 'Asistente IA',
                subtitle: 'Consulta tus finanzas',
                isPrimaryHighlight: true, // Fondo amarillo, texto/icono negro (DESIGN.md)
                onTap: onOpenChat,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPrimaryHighlight,
    required VoidCallback onTap,
  }) {
    final bgColor = isPrimaryHighlight ? AppColors.primaryDark : AppColors.card;
    // DESIGN.md: Fondo amarillo -> texto e icono SIEMPRE negros.
    // Sobre tarjeta blanca, el icono es primaryDark (amarillo marca) o sobre pastilla amarilla suave es negro.
    final iconColor = isPrimaryHighlight ? AppColors.textPrimary : AppColors.textPrimary;
    final titleColor = isPrimaryHighlight ? AppColors.textPrimary : AppColors.textPrimary;
    final subtitleColor = isPrimaryHighlight ? AppColors.secondary : AppColors.textSecondary;
    final borderColor = isPrimaryHighlight ? AppColors.primaryDark : AppColors.border;

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          height: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isPrimaryHighlight ? AppColors.primaryLight : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPrimaryHighlight ? Colors.black.withOpacity(0.1) : AppColors.primaryDark,
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
