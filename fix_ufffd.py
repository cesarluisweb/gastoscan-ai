import os

filepath = 'lib/ui/widgets/expense_card.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("case 'Alimentacin':", "case 'Alimentación':")
content = content.replace("case 'Educacin':", "case 'Educación':")
content = content.replace("Desglose de tems:", "Desglose de ítems:")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

filepath = 'GEMINI.md'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()
    
content = content.replace('Tcnicas', 'Técnicas')
content = content.replace('bloquear', 'bloqueará')
content = content.replace('ubicacin', 'ubicación')
content = content.replace('all', 'allí')
content = content.replace('nicamente', 'únicamente')
content = content.replace('Codificacin', 'Codificación')
content = content.replace('cdigo', 'código')
content = content.replace('parmetro', 'parámetro')
content = content.replace('usar', 'usará')
content = content.replace('romper', 'romperá')
content = content.replace('daar', 'dañará')
content = content.replace('diseo', 'diseño')
content = content.replace('espaol', 'español')
content = content.replace('asegrate', 'asegúrate')
content = content.replace('Atems', 'Ítems')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
