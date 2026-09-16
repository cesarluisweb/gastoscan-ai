# -*- coding: utf-8 -*-
with open("lib/ui/widgets/expense_card.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("case 'AlimentaciA3n':", "case 'Alimentación':")
content = content.replace("case 'EducaciA3n':", "case 'Educación':")
content = content.replace("case 'Alimentacin':", "case 'Alimentación':")
content = content.replace("case 'Educacin':", "case 'Educación':")
content = content.replace("Desglose de AA?tems:", "Desglose de Ítems:")
content = content.replace("Desglose de AA?tems:", "Desglose de Ítems:")
content = content.replace("Desglose de A?tems:", "Desglose de Ítems:")
content = content.replace("Desglose de ÃƒÂ tems:", "Desglose de Ítems:")

# Add Higiene if not present
if "case 'Higiene':" not in content:
    content = content.replace("case 'Salud':\n          return Icons.medical_services_outlined;", "case 'Salud':\n          return Icons.medical_services_outlined;\n        case 'Higiene':\n          return Icons.cleaning_services_outlined;")

with open("lib/ui/widgets/expense_card.dart", "w", encoding="utf-8") as f:
    f.write(content)
