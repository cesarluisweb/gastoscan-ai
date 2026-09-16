import os
import re

with open('lib/ui/widgets/expense_card.dart', 'r', encoding='utf-8') as f:
    content = f.read()
    weird_chars = re.findall(r'case .Alimentaci.*?n.:', content)
    print(weird_chars)
