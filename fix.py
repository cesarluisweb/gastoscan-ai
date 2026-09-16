import os
import re

replacements = {
    'CategorA-a': 'Categoría',
    'CategorA-as': 'Categorías',
    'categorA-a': 'categoría',
    'categorA-as': 'categorías',
    'AlimentaciA3n': 'Alimentación',
    'EducaciA3n': 'Educación',
    'EducaciÃƒÂ³n': 'Educación',
    'AlimentaciÃƒÂ³n': 'Alimentación',
    'AlimentaciAA3n': 'Alimentación',
    'EducaciAA3n': 'Educación',
    'A?tems': 'Ítems',
    'A\'A,A?tems': 'Ítems',
    'InvAlido': 'Inválido',
    'Axito': 'éxito',
    'bAsqueda': 'búsqueda',
    'mayAsculas': 'mayúsculas',
    'EstA': 'Está',
    'estA': 'está',
    'mÃ¡s': 'más',
    'AutomÃ¡tica': 'Automática',
    'ConfiguraciÃ³n': 'Configuración',
    'espaAol': 'español',
    'diseAo': 'diseño',
    'daAarA': 'dañará',
    'usarA': 'usará',
    'romperA': 'romperá',
    'parAmetro': 'parámetro',
    'ubicaciA3n': 'ubicación',
    'allA-': 'allí',
    'Anicamente': 'únicamente',
    'TAccnicas': 'Técnicas',
    'bloquearA': 'bloqueará',
    'cA3digo': 'código',
    'asegArate': 'asegúrate',
    'sesiA3n': 'sesión',
    'tenA-a': 'tenía',
    'AFelicidades!': '¡Felicidades!',
    'Ã©xito': 'éxito',
    'Â¿': '¿',
    'Ã¡': 'á',
    'Ã³': 'ó',
    'Ã­': 'í',
    'EstÃ¡': 'Está',
    'estÃ¡': 'está',
    'mÃ¡s': 'más',
    'econÃ³mico': 'económico',
    'saliÃ³': 'salió',
    'DescripciÃ³n': 'Descripción',
    'CategorÃ­a': 'Categoría',
    'InformaciÃ³n': 'Información',
    'Ã­tems': 'ítems',
    'Ã tems': 'Ítems',
    'ÃƒÂ tems': 'Ítems'
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

for root, dirs, files in os.walk('.'):
    if '.git' in root or '.dart_tool' in root or 'build' in root or 'node_modules' in root:
        continue
    for file in files:
        if file.endswith('.dart') or file.endswith('.md'):
            fix_file(os.path.join(root, file))
