# DISPATCH

## 2026-09-15T18:56:26Z

You are the Phase 6 Codebase Explorer for "Rinde Más" (Flutter App).
Your working directory is:
H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\explorer_survey_phase6

Authoritative Request:
H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\ORIGINAL_REQUEST.md

Workspace Root:
H:\My Drive\Documentos\Trabajo\Control de gastos VE

Project Technical Rules:
- Under Google Drive sync: do NOT run heavy concurrent builds or npm/flutter locking commands if avoidable. Read files carefully.
- If creating any scripts or files, ensure UTF-8 encoding.

Your Task:
Investigate the codebase to produce an exact, authoritative survey report covering all 4 requirements of Phase 6:
1. R1: Subida Múltiple de Facturas
   - Examine how gallery scanning is currently implemented (which screen/widget, image_picker usage).
   - Examine ScanQueueProvider (location, methods, how queue items are processed in background).
   - Examine how DashboardScreen displays the yellow processing banner.
   - Specify the exact code changes needed to support pickMultiImage, enqueue each to ScanQueueProvider, and immediately pop/navigate back to Dashboard.

2. R2: Buscador de Gastos
   - Examine DashboardScreen (AppBar structure, actions, title).
   - Examine how expenses are retrieved and displayed (ExpenseProvider, SQLite queries, filtering).
   - Specify how to add the search icon in AppBar, toggle a search TextField, and filter displayed expenses in real time by commerce (comercio) or product name.

3. R3: Presupuestos por Categoría
   - Examine SQLite database tables (database_helper.dart, schema version, migrations, categories table, expenses table).
   - Examine Category model, Expense model, CategoryProvider / ExpenseProvider.
   - Determine how monthly spending per category is calculated.
   - Determine where in DashboardScreen categories are shown and how to render a visual alert (red progress bar or warning indicator when spending > budget).
   - Determine how the user edits/defines the monthly budget limit per category (e.g., tap on category or dialog).

4. R4: Recordatorios de Inactividad (Push Locales)
   - Inspect pubspec.yaml: check if flutter_local_notifications or similar is installed.
   - Inspect android/app/src/main/AndroidManifest.xml: check notification permissions.
   - Inspect app entry point (main.dart) and lifecycle/expense logging to see how last active timestamp can be tracked (e.g. SharedPreferences).
   - Outline the notification service setup and 3-day inactivity scheduling function.

5. Test Suite & Infrastructure:
   - Inspect test/ directory to understand current test conventions and coverage.
   - Propose test plan for R1, R2, R3, and R4.

Deliverable:
Write your full findings to:
H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\explorer_survey_phase6\survey_report.md
Also write a clear handoff.md in your working directory.
When complete, notify me (the caller) via send_message with a summary of findings and the path to your report.
