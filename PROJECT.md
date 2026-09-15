# Project: Control de Gastos VE — Fase 6 ("Rinde Más")

## Architecture
- **Framework:** Flutter (Dart), Android & iOS target.
- **State Management:** Provider pattern (e.g. `ScanQueueProvider`, `ExpenseProvider`, `CategoryProvider`).
- **Persistence:** Local SQLite database via `sqflite` (database_helper / migrations) + sync mechanism.
- **Notifications:** Local push notifications (via `flutter_local_notifications`).
- **UI:** Material Design 3 responsive screens (`DashboardScreen`, Scanner screen/dialog, Category management).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | R1: Subida Múltiple de Facturas | Multi-image selection from gallery, enqueue to ScanQueueProvider, return silently to Dashboard, yellow banner | M1 | ORIGINAL_REQUEST.md § R1 |
| 2 | R2: Buscador de Gastos | Search icon in DashboardScreen AppBar toggling a search field, real-time filtering by commerce or product | M2 | ORIGINAL_REQUEST.md § R2 |
| 3 | R3: Presupuestos por Categoría | User-defined monthly spending limit per category, red progress indicator/alert in Dashboard when exceeded | M3 | ORIGINAL_REQUEST.md § R3 |
| 4 | R4: Recordatorios de Inactividad | Local push notification scheduled after 3 days without app opening or expense logging; Android permissions | M4 | ORIGINAL_REQUEST.md § R4 |
| 5 | M5: E2E Verification & Audit | Comprehensive test coverage, programmatic acceptance criteria verification, and forensic audit | M5 | ORIGINAL_REQUEST.md § Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Subida Múltiple de Facturas | Image picker multi-image support, enqueue all selected images to ScanQueueProvider, navigate back to Dashboard, verify yellow processing banner | None | DONE |
| 2 | M2: Buscador de Gastos | DashboardScreen AppBar search icon, filter controller, real-time expense list filtering by commerce/product | None | DONE |
| 3 | M3: Presupuestos por Categoría | SQLite budget storage / category budget field, budget edit UI, monthly expense calculation, red progress/alert UI in Dashboard | None | DONE |
| 4 | M4: Recordatorios de Inactividad | flutter_local_notifications integration, Android permissions in AndroidManifest.xml, 3-day inactivity scheduling service, activity tracking | None | PLANNED |
| 5 | M5: E2E Verification & Auditing | Programmatic test suite across all 4 requirements, run flutter tests, Reviewer verification, Challenger stress-test, and Forensic Auditor verification | M1, M2, M3, M4 | PLANNED |

## Interface Contracts
### Scanner ↔ ScanQueueProvider
- `ScanQueueProvider.enqueueMultiple(List<String> imagePaths)` or `enqueue(String imagePath)` for each image.
- Navigation: `Navigator.of(context).pop()` returning immediately to Dashboard.
- Dashboard: Reads `scanQueueProvider.isProcessing` or queue count to display yellow banner.

### DashboardScreen ↔ Expense Filtering
- Filter query `String searchQuery`.
- When `searchQuery.isNotEmpty`, filter expenses where `expense.commerce.toLowerCase().contains(query)` OR `expense.items.any((item) => item.name.toLowerCase().contains(query))`.

### Category ↔ Budget Storage
- Category budget schema: `budget` or `monthly_limit` REAL column in SQLite categories table (or dedicated budgets table).
- Aggregation: Sum of expenses for the current month and category.
- UI Indicator: Progress bar or visual warning drawn in red if `currentMonthSpent > budget`.

### NotificationService ↔ App Lifecycle
- Scheduling: Trigger 3 days after latest of `app_opened` or `expense_logged`.
- Cancel/Reschedule: Whenever app opens or new expense is saved, reschedule notification for now + 3 days.

## Code Layout
- `lib/screens/`: UI Screens (`DashboardScreen`, etc.)
- `lib/providers/`: State management (`ScanQueueProvider`, `ExpenseProvider`, etc.)
- `lib/models/`: Domain models (`Expense`, `Category`, etc.)
- `lib/services/`: Services (`NotificationService`, `DatabaseHelper`, etc.)
- `android/app/src/main/AndroidManifest.xml`: Android configuration & permissions
- `test/`: Unit, widget, and integration tests
