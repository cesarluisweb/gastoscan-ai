## 2026-09-15T21:02:03Z

You are Worker 3 for Milestone 3 (R3: Presupuestos por Categoría) of "Rinde Más" (Flutter App).

Your working directory is:
H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\worker_m3_r3

Read these files before starting:
- Authoritative User Request: H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\ORIGINAL_REQUEST.md
- Master Project Plan: H:\My Drive\Documentos\Trabajo\Control de gastos VE\PROJECT.md
- Architecture Skill: H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\skills\flutter-apply-architecture-best-practices\SKILL.md

Workspace Root:
H:\My Drive\Documentos\Trabajo\Control de gastos VE

Project Technical Rules:
- Google Drive sync: Never run concurrent npm/build processes if applicable.
- If using PowerShell Set-Content, ALWAYS use `-Encoding UTF8`.

Task Scope:
Implement R3: Presupuestos por Categoría:
1. Examine `lib/data/datasources/local/database_helper.dart`, category models in `lib/data/models/`, and providers (such as `gasto_provider.dart`, etc.).
2. Database & Model persistence:
   - Ensure categories support a monthly budget limit (e.g. `presupuesto_mensual` / `presupuesto` / `budget` REAL).
   - In `DatabaseHelper`, ensure schema handles this column (with proper migration or `ALTER TABLE` if upgrading existing DB, and default in `onCreate`).
   - Update model `toMap()` and `fromMap()` methods and helper methods to query and update category budget limits.
3. Provider & Business Logic:
   - In the provider (e.g. `GastoProvider` or category management), expose methods to set/update a category's monthly budget.
   - Calculate monthly spent per category against its budget.
4. Dashboard UI & Visual Alert:
   - In `DashboardScreen` (or its category summary / `CategoryChart` / category breakdown section):
     - Display category progress against its monthly budget.
     - Allow the user to tap on a category or a budget button to open a dialog/bottom sheet to set/edit the monthly budget amount.
     - When monthly spending exceeds the assigned budget (`spent > budget` with budget > 0), draw a visual excess alert indicator in RED (e.g., `Colors.red` / `AppColors.error` progress bar, badge, or warning text) for that category.
5. Acceptance Criteria:
   - "Asignar $50 a Comida, y registrar un gasto de $60 en Comida hace que se dibuje un indicador visual de exceso (color rojo) en la UI de esa categoría."
6. Write tests in `test/` verifying:
   - Category model and DB helper budget storage and retrieval.
   - UI widget test: setting budget to $50 and expense to $60 renders the red visual excess indicator.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Deliverable:
Write your report to `H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\worker_m3_r3\handoff.md` detailing:
- Files modified and created
- Database schema changes and migration logic
- UI budget setup dialog & visual red alert indicator
- Tests created and verification instructions
When complete, notify the caller (parent) via `send_message`.
