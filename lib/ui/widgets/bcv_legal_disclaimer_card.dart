import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Tarjeta compartida de aviso legal e independencia respecto al BCV
/// para pantallas que muestran tasas oficiales de referencia.
class BcvLegalDisclaimerCard extends StatelessWidget {
  final Key? cardKey;
  final Key? linkKey;
  final VoidCallback onOpenBcv;

  const BcvLegalDisclaimerCard({
    Key? key,
    this.cardKey,
    this.linkKey,
    required this.onOpenBcv,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aviso legal sobre tasas oficiales',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Las tasas «Dólar BCV» y «Euro BCV» corresponden a información pública publicada por el Banco Central de Venezuela (BCV). Rinde Más es una aplicación independiente y no representa, no está afiliada ni cuenta con respaldo del BCV ni de ninguna entidad gubernamental.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            key: linkKey,
            onTap: onOpenBcv,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Fuente oficial: www.bcv.org.ve',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 12, color: AppColors.textPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
