import os

for root, dirs, files in os.walk('.'):
    if '.git' in root or '.dart_tool' in root or 'build' in root or 'node_modules' in root:
        continue
    for file in files:
        if file.endswith('.dart') or file.endswith('.md'):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
            except Exception as e:
                print(f'Error reading {filepath}: {e}')
