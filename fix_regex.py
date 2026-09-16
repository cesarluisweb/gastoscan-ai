# -*- coding: utf-8 -*-
import os, re

def fix_file(filepath):
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # regex replacements
    content = re.sub(r'Alimentaci.*n', 'Alimentación', content)
    content = re.sub(r'Educaci.*n', 'Educación', content)
    content = re.sub(r'CategorA-as est.*ndar', 'Categorías estándar', content)
    content = re.sub(r'Categor.*a', 'Categoría', content)
    content = re.sub(r'Desglose de .*tems:', 'Desglose de Ítems:', content)
    content = re.sub(r'A-tem\(s\)', 'ítem(s)', content)
    content = re.sub(r'A-tems', 'ítems', content)
    content = re.sub(r'Digitalizaci.*n inteligente', 'Digitalización inteligente', content)
    
    # Specific ones for review_expense_screen.dart
    content = content.replace("telAcfono", "teléfono")
    content = content.replace("venAA-a", "venía")
    content = content.replace("ahAA-", "ahí")
    content = content.replace("quedA3", "quedó")
    content = content.replace("Acxito", "éxito")
    
    # Check for 'Salud' and add 'Higiene' if missing in app_constants.dart
    if filepath.endswith('app_constants.dart') and "'Higiene'" not in content:
        content = content.replace("'Salud',", "'Salud',\n    'Higiene',")
        
    # Check for 'Salud' and add 'Higiene' in expense_card.dart
    if filepath.endswith('expense_card.dart') and "case 'Higiene':" not in content:
        content = content.replace("case 'Salud':\n        return Icons.medical_services_outlined;", "case 'Salud':\n        return Icons.medical_services_outlined;\n      case 'Higiene':\n        return Icons.cleaning_services_outlined;")
        
    # Success banner in review_expense_screen.dart
    if filepath.endswith('review_expense_screen.dart'):
        content = content.replace("Icon(Icons.cloud_done_outlined, color: AppColors.primaryDark)", "Icon(Icons.cloud_done_outlined, color: Colors.green)")
        content = content.replace("Text('Gasto registrado y', style", "Text('¡Felicidades! Gasto registrado y', style")
        content = content.replace("Text('Gasto registrado y ${matchedIds.length} ítem(s)", "Text('¡Felicidades! Gasto registrado y ${matchedIds.length} ítem(s)")
        content = content.replace("Text('Gasto registrado con éxito')", "Text('¡Felicidades! Compra registrada')")

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))
fix_file('pubspec.yaml')
