# AI_RULES.md — Hard Engineering Guidelines for Agents

When implementing features or bugfixes in SRU Timetable 3.0:

1. **Verify Before Coding**:
   - Check existing code and tests before making modifications.
   - Do not guess or assume API signatures.

2. **No Premature Deletion**:
   - Understand why code was written before removing it.
   - Preserve comments, docstrings, and tests unrelated to the target fix.

3. **Atomic State Updates**:
   - Never wipe existing caches before fresh requests resolve.
   - Store temporary payloads in memory until validated, then commit to Hive atomically.

4. **Zero Rebuild Leaks**:
   - Never initialize `PageController`, `TextEditingController`, `AnimationController`, or `ScrollController` inside `build()` methods.
   - Always initialize in `initState()` and dispose in `dispose()`.

5. **Banner Ads Lifecycle**:
   - Never create a new `BannerAd` on every build or tab switch.
   - Use the centralized `AdService` banner cache or maintain a single alive instance in `DashboardScreen`.

6. **Web / PWA Integrity**:
   - Always guard native-only plugins (`Platform.isAndroid`, etc.) with `!kIsWeb`.
   - Never perform blocking network requests before initial UI render.
   - Support standard HTML password autofill (`username`, `current-password`, `one-time-code`).

7. **Verification**:
   - Always run `flutter analyze` after completing changes to ensure 0 lint errors.
