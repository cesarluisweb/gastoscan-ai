import os

files = [
    r'lib/data/models/categoria_model.dart',
    r'lib/data/datasources/local/database_helper.dart',
    r'lib/data/repositories/gasto_repository.dart',
    r'lib/providers/gasto_provider.dart',
    r'lib/ui/widgets/category_chart.dart',
    r'lib/ui/screens/dashboard_screen.dart',
    r'test/models/categoria_model_test.dart',
    r'test/datasources/database_helper_category_test.dart',
    r'test/providers/gasto_provider_budget_test.dart',
    r'test/screens/dashboard_category_budget_test.dart',
    r'test/screens/dashboard_screen_test.dart',
    r'test/screens/dashboard_search_test.dart',
]

def check_balance(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    stack = []
    pairs = {')': '(', '}': '{', ']': '['}
    in_single_quote = False
    in_double_quote = False
    in_triple_single = False
    in_triple_double = False
    in_line_comment = False
    in_block_comment = False
    i = 0
    while i < len(content):
        c = content[i]
        next_c = content[i+1] if i + 1 < len(content) else ''
        next_2 = content[i:i+3]
        
        if in_line_comment:
            if c == '\n':
                in_line_comment = False
        elif in_block_comment:
            if c == '*' and next_c == '/':
                in_block_comment = False
                i += 1
        elif in_triple_single:
            if next_2 == "'''":
                in_triple_single = False
                i += 2
        elif in_triple_double:
            if next_2 == '"""':
                in_triple_double = False
                i += 2
        elif in_single_quote:
            if c == '\\':
                i += 1
            elif c == "'":
                in_single_quote = False
        elif in_double_quote:
            if c == '\\':
                i += 1
            elif c == '"':
                in_double_quote = False
        else:
            if c == '/' and next_c == '/':
                in_line_comment = True
                i += 1
            elif c == '/' and next_c == '*':
                in_block_comment = True
                i += 1
            elif next_2 == "'''":
                in_triple_single = True
                i += 2
            elif next_2 == '"""':
                in_triple_double = True
                i += 2
            elif c == "'":
                in_single_quote = True
            elif c == '"':
                in_double_quote = True
            elif c in '({[':
                stack.append((c, i))
            elif c in ')}]':
                if not stack:
                    print(f'{filename}: Unmatched closing {c} at pos {i}')
                    return False
                top, top_i = stack.pop()
                if top != pairs[c]:
                    print(f'{filename}: Mismatched {top} at {top_i} and {c} at {i}')
                    return False
        i += 1
        
    if stack:
        print(f'{filename}: Unclosed {len(stack)} items: {stack[:5]}')
        return False
    print(f'{filename}: BALANCED OK')
    return True

all_ok = all(check_balance(f) for f in files)
print('ALL OK:', all_ok)
