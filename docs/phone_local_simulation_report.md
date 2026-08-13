# Phone Local Simulation Report

Date: 2026-08-13

## Results

| Validation | Result | Evidence |
| --- | --- | --- |
| Flutter unit/widget tests | PASS | `flutter test`: 69 passed. |
| Flutter analysis | PASS | `flutter analyze --no-fatal-infos --no-fatal-warnings`: exit 0; 74 existing deprecation infos. |
| Flutter debug APK | PASS | `flutter build apk --debug` produced `phone-app/build/app/outputs/flutter-apk/app-debug.apk`. |
| Native JUnit | PASS | `android/gradlew.bat :app:testDebugUnitTest`: 3 tests, 0 failures/errors. |
| Android emulator | PASS | Existing `Medium_Phone_API_36.1` booted as `emulator-5554`, Android 16/API 36. The freshly rebuilt APK installed with `Success`; `com.aiglasses.nutrition/.MainActivity` was top-resumed and no app FATAL/ANR was observed. |

## Behavior Covered Locally

- Manual capture coordination: one physical capture until exact ACK.
- Priority and delayed automatic task preemption by meal end.
- Retry uses a new task ID; old late ACK is rejected.
- Capture quality: invalid JPEG, low-resolution meal-before, duplicate automatic meal-during, and meal-after food relevance policy.
- Eating session: two OPEN_PALM start, latched EATING through UNKNOWN/no-hand, two FIST end, failure/timeout recovery, cancellation, and no duplicate start/end capture.
- Packaging: trigger cooldown, OCR route gate, deterministic OCR parsing, risk rules, correction/recalculation, confirmation persistence/reload, and separate `PackagingScanRecord` semantics.
- Automatic/hybrid framework: fake `FoodSceneResult` candidate stabilization/cooldown is covered by unit tests. Production mode remains unavailable when the classifier is `UnavailableFoodSceneClassifier`.
- Native fixtures: OK is distinct from FIST; open palm and curled four-finger fixtures classify as expected.
- Coordinator hardening: duplicate task IDs, 120 mixed intents with a single in-flight dispatch, bounded completed-ID history, cancellation during automatic retry, and disposal callback safety.
- Lifecycle and upload: app-background automatic-capture gate, capture-upload in-flight/completed idempotence, retry-after-upload-failure behavior, and legacy upload compatibility.
- Packaging persistence: `LocalStorageService.savePackagingScan` and `loadPackagingScans` round-trip through the asynchronous preferences platform, separate from MealRecord data.
- Capture upload protocol: a local receiver accepted a real glasses multipart capture with HTTP 200 and `accepted=true`; the glasses-side response policy now treats any successful 2xx accepted response as success and surfaces `Photo uploaded to phone`.

## Native Test Repair

Initial native test compilation failed because `GestureClassifierTest.kt` imports `org.junit` but the module had no JUnit dependency. Added `testImplementation("junit:junit:4.13.2")`; retest passed. This resolved the previous cross-root concern for the currently configured SDK/Pub cache build.

## Boundaries

- No real Android phone was used; emulator validates install/launch only.
- No food-scene TFLite exists. The only relevant repository asset is `android/app/src/main/assets/hand_landmarker.task`; production automatic/hybrid automatic capture is intentionally unavailable.
- Real vivo OCR credentials and end-to-end phone/RV101 networking were not supplied.
