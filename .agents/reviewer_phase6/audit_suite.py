import os
import sys
import re
import xml.etree.ElementTree as ET

def check_brackets(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    stack = []
    pairs = {')': '(', '}': '{', ']': '['}
    in_single_quote = False
    in_double_quote = False
    in_multiline_comment = False
    in_single_line_comment = False
    
    i = 0
    line_num = 1
    col_num = 0
    errors = []

    while i < len(content):
        c = content[i]
        col_num += 1

        if c == '\n':
            line_num += 1
            col_num = 0
            in_single_line_comment = False
            i += 1
            continue

        if in_single_line_comment:
            i += 1
            continue

        if in_multiline_comment:
            if c == '*' and i + 1 < len(content) and content[i + 1] == '/':
                in_multiline_comment = False
                i += 2
                col_num += 1
                continue
            i += 1
            continue

        if not in_single_quote and not in_double_quote:
            if c == '/' and i + 1 < len(content) and content[i + 1] == '/':
                in_single_line_comment = True
                i += 2
                col_num += 1
                continue
            if c == '/' and i + 1 < len(content) and content[i + 1] == '*':
                in_multiline_comment = True
                i += 2
                col_num += 1
                continue

        # String literals
        if c == '\\' and (in_single_quote or in_double_quote):
            i += 2
            col_num += 1
            continue

        if c == "'" and not in_double_quote:
            in_single_quote = not in_single_quote
            i += 1
            continue

        if c == '"' and not in_single_quote:
            in_double_quote = not in_double_quote
            i += 1
            continue

        if not in_single_quote and not in_double_quote:
            if c in '({[':
                stack.append((c, line_num, col_num))
            elif c in ')}]':
                if not stack:
                    errors.append(f"Unmatched closing '{c}' at {line_num}:{col_num}")
                else:
                    open_char, o_line, o_col = stack.pop()
                    if pairs[c] != open_char:
                        errors.append(f"Mismatched bracket: expected '{pairs[c]}' but found '{c}' at {line_num}:{col_num} (opened at {o_line}:{o_col})")

        i += 1

    while stack:
        open_char, o_line, o_col = stack.pop()
        errors.append(f"Unclosed '{open_char}' opened at {o_line}:{o_col}")

    return errors

def audit_all_files():
    print("=== STARTING COMPREHENSIVE CODE AUDIT ===")
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    print(f"Project root: {root_dir}")

    # 1. Bracket & Syntax Balance
    files_to_check = [
        "lib/ui/screens/scan_screen.dart",
        "lib/providers/scan_queue_provider.dart",
        "lib/ui/screens/dashboard_screen.dart",
        "lib/data/datasources/local/database_helper.dart",
        "lib/data/models/categoria_model.dart",
        "lib/data/repositories/gasto_repository.dart",
        "lib/providers/gasto_provider.dart",
        "lib/ui/widgets/category_chart.dart",
        "lib/services/notification_service.dart",
        "lib/main.dart",
        "test/providers/scan_queue_provider_test.dart",
        "test/screens/scan_screen_test.dart",
        "test/screens/dashboard_screen_test.dart",
        "test/screens/dashboard_search_test.dart",
        "test/models/categoria_model_test.dart",
        "test/datasources/database_helper_category_test.dart",
        "test/providers/gasto_provider_budget_test.dart",
        "test/screens/dashboard_category_budget_test.dart",
        "test/services/notification_service_test.dart",
    ]

    all_syntax_pass = True
    for rel_path in files_to_check:
        full_path = os.path.join(root_dir, rel_path)
        if not os.path.exists(full_path):
            print(f"[FAIL] Missing file: {rel_path}")
            all_syntax_pass = False
            continue
        errs = check_brackets(full_path)
        if errs:
            print(f"[FAIL] Syntax/bracket balance errors in {rel_path}:")
            for e in errs:
                print(f"   {e}")
            all_syntax_pass = False
        else:
            print(f"[PASS] Balanced: {rel_path}")

    # 2. Integrity Violations Check
    # Look for suspicious dummy implementations or hardcoded shortcuts in lib/
    print("\n--- Integrity Audit in lib/ ---")
    lib_files = [f for f in files_to_check if f.startswith("lib/")]
    integrity_clean = True
    for rel_path in lib_files:
        full_path = os.path.join(root_dir, rel_path)
        with open(full_path, 'r', encoding='utf-8') as f:
            code = f.read()

        # Check for empty TODO/stub methods
        if re.search(r'\{\s*//\s*TODO\s*\}', code):
            print(f"[WARN] Empty TODO found in {rel_path}")
            integrity_clean = False

        # Check for hardcoded test returns in production methods
        if "return true; // fake" in code or "return 42;" in code:
            print(f"[INTEGRITY VIOLATION] Fake return detected in {rel_path}")
            integrity_clean = False

    if integrity_clean:
        print("[PASS] No integrity violations or dummy stubs found in production code.")

    # 3. AndroidManifest Permissions & Receivers
    print("\n--- Android Manifests Audit ---")
    manifests = [
        os.path.join(root_dir, "android", "app", "src", "main", "AndroidManifest.xml"),
        os.path.join(root_dir, "android_template", "AndroidManifest.xml")
    ]
    required_perms = [
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.SCHEDULE_EXACT_ALARM",
        "android.permission.USE_EXACT_ALARM",
        "android.permission.VIBRATE",
    ]
    required_receivers = [
        "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
        "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
    ]

    for mpath in manifests:
        rel = os.path.relpath(mpath, root_dir)
        with open(mpath, 'r', encoding='utf-8') as f:
            mcontent = f.read()
        for p in required_perms:
            if p not in mcontent:
                print(f"[FAIL] {rel} missing permission: {p}")
            else:
                print(f"[PASS] {rel} has {p}")
        for r in required_receivers:
            if r not in mcontent:
                print(f"[FAIL] {rel} missing receiver: {r}")
            else:
                print(f"[PASS] {rel} has {r}")

    # 4. Pubspec Dependencies
    print("\n--- Pubspec Audit ---")
    pubspec_path = os.path.join(root_dir, "pubspec.yaml")
    with open(pubspec_path, 'r', encoding='utf-8') as f:
        pcontent = f.read()
    if "flutter_local_notifications:" in pcontent and "timezone:" in pcontent:
        print("[PASS] pubspec.yaml contains flutter_local_notifications and timezone")
    else:
        print("[FAIL] pubspec.yaml missing required dependencies")

    # 5. Database Schema & Migration
    print("\n--- Database Helper Audit ---")
    db_path = os.path.join(root_dir, "lib", "data", "datasources", "local", "database_helper.dart")
    with open(db_path, 'r', encoding='utf-8') as f:
        db_content = f.read()
    if "CREATE TABLE IF NOT EXISTS categorias" in db_content or "CREATE TABLE categorias" in db_content:
        print("[PASS] DatabaseHelper defines categorias table")
    else:
        print("[FAIL] DatabaseHelper missing categorias table creation")

    if "oldVersion < 6" in db_content:
        print("[PASS] DatabaseHelper includes v6 migration for categorias")
    else:
        print("[FAIL] DatabaseHelper missing v6 migration")

    print("\n=== AUDIT SUMMARY ===")
    if all_syntax_pass and integrity_clean:
        print("ALL STATIC AUDIT CHECKS PASSED.")
    else:
        print("SOME CHECKS FAILED.")

if __name__ == '__main__':
    audit_all_files()
