import os
import re

# 1. Update app_constants.dart
filepath = 'lib/core/constants/app_constants.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'Salud',", "'Salud',\n    'Higiene',")
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Update app_colors.dart
filepath = 'lib/core/constants/app_colors.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'Salud': Color(0xFFEF4444),        // Rojo", "'Salud': Color(0xFFEF4444),        // Rojo\n    'Higiene': Color(0xFFF472B6),      // Rosa")
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

# 3. Update expense_card.dart
filepath = 'lib/ui/widgets/expense_card.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("case 'Salud':\n        return Icons.medical_services_outlined;", "case 'Salud':\n        return Icons.medical_services_outlined;\n      case 'Higiene':\n        return Icons.cleaning_services_outlined;")
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

# 4. Update review_expense_screen.dart
filepath = 'lib/ui/screens/review_expense_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r"'Gasto [rR]egistrado( con Ã©xito)?',", "'¡Felicidades! Compra registrada',", content)
content = re.sub(r"Icon\(Icons.cloud_done_outlined, color: .*?\)", "Icon(Icons.cloud_done_outlined, color: Colors.green)", content)
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

# 5. Update GEMINI.md Note
filepath = 'GEMINI.md'
with open(filepath, 'a', encoding='utf-8') as f:
    f.write("\n*(Nota: Ya se corrigieron los mojibakes en review_expense_screen, expense_card y gasto_provider. Por favor, asegúrate de no volver a usar Set-Content sin UTF8).*\n")
