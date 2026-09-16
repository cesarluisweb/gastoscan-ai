import os

replacements = {
    'DigitalizaciA3n': 'Digitalización',
    'OptimizaciA3n': 'Optimización',
    'ImAgenes': 'Imágenes',
    'GestiA3n': 'Gestión',
    'GrAficos': 'Gráficos',
    'ExportaciA3n': 'Exportación'
}

def fix_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        return
    
    orig = content
    for bad, good in replacements.items():
        content = content.replace(bad, good)
        
    if content != orig:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Fixed {filepath}')

fix_file('pubspec.yaml')
fix_file('firebase.json')
