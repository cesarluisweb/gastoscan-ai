# -*- coding: utf-8 -*-
import os

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Manual replacements
    replacements = {
        'CategorA-as': 'Categorías',
        'estAndar': 'estándar',
        'AlimentaciA3n': 'Alimentación',
        'EducaciA3n': 'Educación',
        'AlimentaciÃ³n': 'Alimentación',
        'EducaciÃ³n': 'Educación',
        'CategorÃ­a': 'Categoría',
        'Ã­tem': 'ítem',
        'Ã©xito': 'éxito',
        'Â¿': '¿',
        'guardarÃ¡': 'guardará',
        'bÃºsqueda': 'búsqueda',
        'mayÃºsculas': 'mayúsculas',
        'sesiÃ³n': 'sesión',
        'tenÃ­a': 'tenía',
        'InvÃ¡lido': 'Inválido',
        'DescripciA3n': 'Descripción',
        'CategorA-a': 'Categoría',
        'A-tems': 'ítems',
        'A-tem': 'ítem',
        'A?tems': 'ítems',
        'A?tem': 'ítem',
        'Ã\x8d': 'Í',
        'AA?tems': 'Ítems',
        'A3n': 'ón',
        'telAcfono': 'teléfono',
        'Acxito': 'éxito',
        'quedA3': 'quedó',
        'ahAA-': 'ahí',
        'venAA-a': 'venía',
        'dY"': '⚠️',
        'dYY': '✅',
        'InvAlido': 'Inválido',
        'Invlido': 'Inválido',
        'Inv\ufffdlido': 'Inválido',
        'Educaci\ufffdn': 'Educación',
        'Alimentaci\ufffdn': 'Alimentación',
        'Categor\ufffda': 'Categoría',
        'A\ufffdtems': 'ítems'
    }

    new_content = content
    for k, v in replacements.items():
        new_content = new_content.replace(k, v)

    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed {filepath}")

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            try:
                fix_file(os.path.join(root, file))
            except:
                pass
            
fix_file('pubspec.yaml')
