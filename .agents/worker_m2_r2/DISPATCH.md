## 2026-09-15T20:56:48Z

<USER_REQUEST>
You are Worker 2 for Milestone 2 (R2: Buscador de Gastos) of  Rinde Más (Flutter App).

Your working directory is:
H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\worker_m2_r2

Read these files before starting:
- Authoritative User Request: H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\ORIGINAL_REQUEST.md
- Master Project Plan: H:\My Drive\Documentos\Trabajo\Control de gastos VE\PROJECT.md
- Architecture Skill: H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\skills\flutter-apply-architecture-best-practices\SKILL.md

Workspace Root:
H:\My Drive\Documentos\Trabajo\Control de gastos VE

Project Technical Rules:
- Google Drive sync: Never run concurrent npm/build processes if applicable.
- If using PowerShell Set-Content, ALWAYS use -Encoding UTF8.

Task Scope:
Implement R2: Buscador de Gastos:
1. Examine lib/ui/screens/dashboard_screen.dart and its AppBar.
2. Inspect how expenses and their items are modeled (lib/models/ or lib/data/models/expense.dart, item.dart, expense_item.dart, etc.) and how expenses are retrieved and listed in DashboardScreen.
3. In DashboardScreen:
   - Add a search icon (Icons.search) to the AppBar.
   - When tapped, toggle a search TextField with hint Buscar por comercio o producto... and a close/clear button (Icons.close).
   - Track the search query and filter the expenses list in real-time.
   - Match by commerce (expense.commerce / merchant) or by product name (checking items associated with the expense). Both case-insensitive.
   - If query is empty, display all expenses as normal.
   - If search yields 0 matches, show a friendly empty state message.
   - Ensure the search integrates cleanly without breaking existing pull-to-refresh, banners, or category sections.
4. Write comprehensive widget tests in 	est/screens/dashboard_search_test.dart (or update existing tests) verifying:
   - Tapping search icon reveals search text field.
   - Entering search query (e.g. Cafe) immediately filters out non-matching expenses.
   - Expenses matching by commerce are included.
   - Expenses matching by product name are included.
   - Clearing search query restores all expenses.
5. Verify your test code matches the project conventions and models.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Deliverable:
Write your report to H:\My Drive\Documentos\Trabajo\Control de gastos VE\.agents\worker_m2_r2\handoff.md detailing:
- Files modified and created
- Search and filtering implementation
- Tests created and verification instructions
When complete, notify the caller (parent) via send_message.
</USER_REQUEST>
