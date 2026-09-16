import os
import re

filepath = 'lib/ui/screens/review_expense_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r"content: Text\('Gasto registrado con .*?'\)", "content: Text('¡Felicidades! Compra registrada')", content)
content = re.sub(r"Icon\(Icons.cloud_done_outlined, color: Colors.green\)", "Icon(Icons.cloud_done_outlined, color: Colors.green)", content) # Just in case
content = content.replace("Gasto registrado y", "¡Felicidades! Gasto registrado y")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
