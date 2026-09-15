import os
import re

root_dir = r"H:\My Drive\Documentos\Trabajo\Control de gastos VE"

dart_files = []
for dirpath, _, filenames in os.walk(os.path.join(root_dir, "lib")):
    for f in filenames:
        if f.endswith(".dart"):
            dart_files.append(os.path.join(dirpath, f))

for dirpath, _, filenames in os.walk(os.path.join(root_dir, "test")):
    for f in filenames:
        if f.endswith(".dart"):
            dart_files.append(os.path.join(dirpath, f))

package_name = "gastoscan_ai"
missing_imports = []

for df in dart_files:
    with open(df, "r", encoding="utf-8") as f:
        lines = f.readlines()
    for l_no, line in enumerate(lines, 1):
        m = re.match(r"import\s+['\"]package:" + package_name + r"/([^'\"]+)['\"];", line.strip())
        if m:
            rel = m.group(1)
            target = os.path.join(root_dir, "lib", rel)
            if not os.path.exists(target):
                missing_imports.append((df, l_no, line.strip(), target))
        m2 = re.match(r"import\s+['\"](\.[^'\"]+)['\"];", line.strip())
        if m2:
            rel = m2.group(1)
            target = os.path.normpath(os.path.join(os.path.dirname(df), rel))
            if not os.path.exists(target):
                missing_imports.append((df, l_no, line.strip(), target))

if missing_imports:
    print(f"Found {len(missing_imports)} missing imports:")
    for src, l_no, imp, tgt in missing_imports:
        print(f"  {src}:{l_no} -> {imp} (looked at {tgt})")
else:
    print("ALL internal imports resolve successfully to real files!")
