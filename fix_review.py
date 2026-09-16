# -*- coding: utf-8 -*-
import re
with open("lib/ui/screens/review_expense_screen.dart", "r", encoding="utf-8", errors="ignore") as f:
    c = f.read()

c = c.replace("telAcfono", "teléfono")
c = c.replace("venAA-a", "venía")
c = c.replace("ahAA-", "ahí")
c = c.replace("quedA3", "quedó")
c = c.replace("Acxito", "éxito")
c = c.replace("CategorA-a", "Categoría")
c = c.replace("CategorA-as", "Categorías")
c = c.replace("DescripciA3n", "Descripción")
c = c.replace("InvAlido", "Inválido")
c = c.replace("Invlido", "Inválido")
c = c.replace("A-tem(s)", "ítem(s)")
c = c.replace("A-tems", "ítems")
c = c.replace("A?tems", "ítems")
c = c.replace("A?tem", "ítem")
c = c.replace("dY\"", "⚠️")
c = c.replace("dYY", "✅")
c = c.replace("InformaciA3n", "Información")
c = c.replace("EmisiA3n", "Emisión")
c = c.replace("saliA3", "salió")
c = c.replace("econA3mico", "económico")

c = re.sub(r"Inv.*lido", "Inválido", c)
c = re.sub(r'A-tem\(s\)', 'ítem(s)', c)
c = re.sub(r'A-tems', 'ítems', c)

c = c.replace("Icon(Icons.cloud_done_outlined, color: AppColors.primaryDark)", "Icon(Icons.cloud_done_outlined, color: Colors.green)")
c = c.replace("Text('Gasto registrado y', style", "Text('¡Felicidades! Gasto registrado y', style")
c = c.replace("Text('Gasto registrado y ${matchedIds.length} ítem(s)", "Text('¡Felicidades! Gasto registrado y ${matchedIds.length} ítem(s)")
c = c.replace("Text('Gasto registrado con éxito')", "Text('¡Felicidades! Compra registrada')")

c = c.replace("Â¿Seguro que deseas descartar Está factura escaneada? No se guardarÃ¡ en tu historial.", "¿Seguro que deseas descartar esta factura escaneada? No se guardará en tu historial.")

with open("lib/ui/screens/review_expense_screen.dart", "w", encoding="utf-8") as f:
    f.write(c)
