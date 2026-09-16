# -*- coding: utf-8 -*-
import re
with open("lib/ui/widgets/expense_card.dart", "r", encoding="utf-8", errors="ignore") as f:
    c = f.read()

c = re.sub(r"case 'Alimentaci.*n':", "case 'Alimentación':", c)
c = re.sub(r"case 'Educaci.*n':", "case 'Educación':", c)
c = re.sub(r"Desglose de .*tems:", "Desglose de Ítems:", c)

with open("lib/ui/widgets/expense_card.dart", "w", encoding="utf-8") as f:
    f.write(c)
