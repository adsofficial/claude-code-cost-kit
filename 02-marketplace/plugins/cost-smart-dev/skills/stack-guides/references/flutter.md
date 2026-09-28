# Flutter / Dart

## Conventions
- Follow the project's state management (Riverpod, Bloc or Provider); do not introduce a second one.
- Feature-first folders (`lib/features/<feature>/{data,domain,presentation}`) unless the project uses another layout.
- Immutable models (`freezed` / `json_serializable` if already used). Null safety everywhere; avoid `!` unless proven safe.
- `const` constructors wherever possible; split large `build` methods into small widgets.
- Every screen handles loading, error and empty states. Text through localization (`intl` / ARB files), no hard-coded user-facing strings.
- Platform differences behind an interface, not scattered `Platform.isIOS` checks.

## Testing
- Unit tests for logic, widget tests for UI, `integration_test` for critical flows.
- Mock repositories/HTTP with `mocktail` or `mockito`; never hit real APIs in tests.
- Commands: `flutter analyze`, `flutter test`, `dart format --set-exit-if-changed .`

## Security
- Tokens and secrets in `flutter_secure_storage`, never `SharedPreferences` or plain files.
- No API keys or secrets in the app bundle: anything shipped in the app is public. Call your backend instead.
- HTTPS only; consider certificate pinning for high-risk apps.
- Validate deep links and route arguments; do not trust data from the backend blindly in WebViews.
- Obfuscate release builds (`--obfuscate --split-debug-info`); no sensitive data in logs (`debugPrint` stripped in release).

## Cost & performance
- Avoid rebuilding big trees: `const`, `select`/`Consumer` scoping, `ListView.builder` for long lists.
- Cache network images; paginate lists; debounce search input.
