# AGENTS.md

This document provides context and guidelines for AI agents working on the `app_estetica` codebase.

## 1. Project Overview
**App Estética** is a Flutter mobile application for managing an aesthetics business (tickets, sessions, clients, payments, reports).
- **Backend:** Supabase (PostgreSQL, Auth, Edge Functions).
- **State Management:** Provider.
- **Architecture:** Repository Pattern (Repository -> Provider -> Screen).

## 2. Environment & Commands

### Setup & Build
- **Install dependencies:** `flutter pub get`
- **Run app:** `flutter run` (Use a connected device or emulator)
- **Clean build:** `flutter clean && flutter pub get`

### Linting & Formatting
- **Lint:** `flutter analyze`
  - Strict adherence to `flutter_lints` rules defined in `analysis_options.yaml`.
  - Fix all lint warnings before committing.
- **Format:** `dart format .`
  - Use 2-space indentation.
  - Always use trailing commas in widget trees and parameter lists for better formatting.

### Testing
- **Run all tests:** `flutter test`
- **Run a single test file:** `flutter test test/path/to/file_test.dart`
- **Run a specific test by name:** `flutter test --name "test name"`
- **Note:** The project currently has minimal tests. New features **should** include unit tests for Repositories and Providers.

## 3. Architecture & Patterns

### Core Pattern: Repository -> Provider -> Screen
1.  **Repositories (`lib/repositories/`)**:
    - Handle all data fetching and business logic (Supabase calls).
    - **Do not** store state.
    - Use `Supabase.instance.client`.
    - Example: `TicketRepository` handles tickets, sessions, and payments.
    - **Migration Rule:** Move logic from legacy `ApiService` to specific repositories.

2.  **Providers (`lib/providers/`)**:
    - Manage UI state (loading, error, data lists).
    - Extend `ChangeNotifier`.
    - Call Repositories to fetch/update data.
    - Expose getters for state (e.g., `bool get isLoading`).
    - Handle exceptions from Repositories and set error states (`_error`).

3.  **Screens (`lib/screens/`)**:
    - Build UI based on Provider state.
    - **Do not** call Repositories directly (unless absolutely necessary for a one-off action not affecting global state).
    - Use `Consumer<T>` or `Provider.of<T>` to access data.

### Supabase Integration
- Use RPC calls for atomic operations involving multiple tables (e.g., `eliminar_ticket_atomico`).
- Handle Supabase errors using `try/catch` blocks.
- Database fields use `snake_case`; Dart models use `lowerCamelCase`.

## 4. Code Style & Conventions

### Imports
- **Preferred:** Absolute imports for project files.
  ```dart
  import 'package:app_estetica/repositories/ticket_repository.dart'; // GOOD
  import '../../repositories/ticket_repository.dart'; // AVOID (unless very close)
  ```
- **Order:** Dart core -> Package imports -> Project imports.

### Naming
- **Classes/Enums:** `UpperCamelCase` (e.g., `TicketRepository`, `ClientModel`).
- **Variables/Methods:** `lowerCamelCase` (e.g., `fetchTickets`, `isLoading`).
- **Files:** `snake_case.dart` (e.g., `ticket_repository.dart`).
- **Constants:** `lowerCamelCase` (preferred in Dart) or `SCREAMING_SNAKE_CASE`.

### Typing & Null Safety
- **Strict Typing:** Avoid `dynamic` whenever possible. Create Models/DTOs if data structures are reused.
- **Supabase Responses:** Explicitly cast responses or map them safely.
  ```dart
  final List<dynamic> data = response as List<dynamic>;
  // Better: Map to model
  ```

### Error Handling
- Use `try/catch` in Repositories and Providers.
- **Logging:** Use `debugPrint('Error: $e')` instead of `print()`.
- **User Feedback:** Providers should expose error messages for the UI to display (e.g., SnackBar).

### Specific Rules
- **No Raw SQL:** Use the Supabase Flutter SDK or RPC functions.
- **UI Components:** Reusable widgets go in `lib/widgets/`.
- **Legacy Code:** Be aware of `lib/services/api_service.dart`. **Do not add new logic here.** Refactor to Repositories instead.

## 5. Development Workflow
1.  **Understand:** Read related Repositories and Providers before changing logic.
2.  **Plan:** Identify if a new Repository method or Provider action is needed.
3.  **Implement:** Follow the pattern. Add `debugPrint` for debugging complex flows.
4.  **Verify:** Run `flutter analyze` and `flutter test` (if applicable).
