# -*- coding: utf-8 -*-
import os

def replace_in_file(filepath, replacements):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    new_content = content
    for k, v in replacements.items():
        new_content = new_content.replace(k, v)
    if new_content != content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)

replacements = {
    "CategorA-as estAndar": "Categorías estándar",
    "AlimentaciA3n": "Alimentación",
    "EducaciA3n": "Educación",
    "CategorA-a": "Categoría",
    "A-tems": "ítems",
    "A-tem(s)": "ítem(s)",
    "A?tems": "ítems",
    "A?tem": "ítem",
    "A3n": "ón",
    "telAcfono": "teléfono",
    "Acxito": "éxito",
    "quedA3": "quedó",
    "ahAA-": "ahí",
    "venAA-a": "venía",
    "dY\"": "⚠️",
    "dYY": "✅",
    "InvAlido": "Inválido",
    "Invlido": "Inválido",
    "DigitalizaciA3n": "Digitalización",
    "sesiA3n": "sesión",
    "tenA-a": "tenía",
    "sesiÃ³n": "sesión",
    "tenÃ­a": "tenía",
    "Â¿": "¿",
    "guardarÃ¡": "guardará",
    "Ã­tem": "ítem",
    "Ã©xito": "éxito"
}

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            replace_in_file(os.path.join(root, file), replacements)

replace_in_file('pubspec.yaml', replacements)

# Insert Higiene in app_constants.dart
with open('lib/core/constants/app_constants.dart', 'r', encoding='utf-8') as f:
    app_c = f.read()
if "'Higiene'" not in app_c:
    app_c = app_c.replace("'Salud',", "'Salud',\n    'Higiene',")
    with open('lib/core/constants/app_constants.dart', 'w', encoding='utf-8') as f:
        f.write(app_c)

# Insert Higiene in expense_card.dart
with open('lib/ui/widgets/expense_card.dart', 'r', encoding='utf-8') as f:
    exp_c = f.read()
if "case 'Higiene':" not in exp_c:
    exp_c = exp_c.replace("case 'Salud':\n          return Icons.medical_services_outlined;", "case 'Salud':\n          return Icons.medical_services_outlined;\n        case 'Higiene':\n          return Icons.cleaning_services_outlined;")
    with open('lib/ui/widgets/expense_card.dart', 'w', encoding='utf-8') as f:
        f.write(exp_c)

# Update success banner in review_expense_screen.dart
with open('lib/ui/screens/review_expense_screen.dart', 'r', encoding='utf-8') as f:
    rev_c = f.read()

rev_c = rev_c.replace("Icon(Icons.cloud_done_outlined, color: AppColors.primaryDark)", "Icon(Icons.cloud_done_outlined, color: Colors.green)")
rev_c = rev_c.replace("Text('Gasto registrado y ${matchedIds.length} ítem(s) de tu lista marcados como comprados.')", "Text('¡Felicidades! Gasto registrado y ${matchedIds.length} ítem(s) de tu lista marcados como comprados.')")
rev_c = rev_c.replace("Text('Gasto registrado con éxito')", "Text('¡Felicidades! Compra registrada')")

with open('lib/ui/screens/review_expense_screen.dart', 'w', encoding='utf-8') as f:
    f.write(rev_c)

