import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/constants/app_colors.dart';

void main() {
  group('AppColors.getBudgetProgressColor Tests', () {
    test('returns success (green) for consumption below 85%', () {
      expect(AppColors.getBudgetProgressColor(0.0), AppColors.success);
      expect(AppColors.getBudgetProgressColor(0.29), AppColors.success);
      expect(AppColors.getBudgetProgressColor(0.50), AppColors.success);
      expect(AppColors.getBudgetProgressColor(0.849), AppColors.success);
    });

    test('returns warning (amber) for consumption between 85% and 99.9%', () {
      expect(AppColors.getBudgetProgressColor(0.85), AppColors.warning);
      expect(AppColors.getBudgetProgressColor(0.90), AppColors.warning);
      expect(AppColors.getBudgetProgressColor(0.999), AppColors.warning);
    });

    test('returns error (red) for consumption at or exceeding 100%', () {
      expect(AppColors.getBudgetProgressColor(1.0), AppColors.error);
      expect(AppColors.getBudgetProgressColor(1.5), AppColors.error);
      expect(AppColors.getBudgetProgressColor(2.0), AppColors.error);
    });

    test('returns error (red) when isExceeded is true regardless of percentage', () {
      expect(AppColors.getBudgetProgressColor(0.50, isExceeded: true), AppColors.error);
      expect(AppColors.getBudgetProgressColor(0.0, isExceeded: true), AppColors.error);
    });
  });
}
