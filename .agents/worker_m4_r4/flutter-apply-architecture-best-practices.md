# Architecting Flutter Applications
(Copied from .agents/skills/flutter-apply-architecture-best-practices/SKILL.md)

Enforce strict Separation of Concerns by dividing the application into distinct layers. Never mix UI rendering with business logic or data fetching.

### UI Layer (Presentation)
Implement the MVVM pattern. Views are lean widgets, ViewModels extend ChangeNotifier or use Listenable.

### Data Layer
Implement the Repository pattern and Services for external communication (APIs, plugins, local storage).

### Workflow
1. Define Domain Models
2. Implement Services
3. Implement Repositories
4. Apply Domain logic
5. Implement ViewModel
6. Implement View
7. Inject Dependencies
8. Run Validator / Tests
