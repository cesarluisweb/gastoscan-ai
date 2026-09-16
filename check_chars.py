import os
import re

for root, dirs, files in os.walk('.'):
    if '.git' in root or '.dart_tool' in root or 'build' in root or 'node_modules' in root:
        continue
    for file in files:
        if file.endswith('.dart') or file.endswith('.md') or file.endswith('.yaml'):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                    weird_chars = re.findall(r'[^\x00-\x7FáéíóúÁÉÍÓÚñÑüÜ¿¡]', content)
                    weird_chars = [c for c in weird_chars if c not in ['\n', '\r', '\t', '”', '“', '’', '‘', '—', '–', '€', '✓', '✅', '✨', '⚠️', '🚨', '💰', '📉', '📊', '🚀', '🧠', '⚙', '️', '🟢', '🔺', '🔹', '📍', '📝', '🛒', '🏥', '🧼', '🎓', '🏠', '💧', '🚗', '📦', '⭐', '📱', '💡', '🔒']]
                    if weird_chars:
                        print(f'{filepath} has weird chars: {set(weird_chars)}')
            except Exception as e:
                pass
