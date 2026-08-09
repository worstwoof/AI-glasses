# Eating Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a latched gesture-controlled eating session that captures exactly one high-resolution meal-before image after confirmed open palm and one meal-after image after confirmed fist, paired by `mealSessionId`.

**Architecture:** Keep `WebRtcPreviewPublisher` and `PreviewFrameReporter` running unchanged from the Camera2 preview callback. Add a pure Dart `EatingSessionController` that owns gesture confirmation, delays, send failures, ACK timeouts, matching upload ACKs, session pairing and debug snapshot. `GlassReceiverService` delegates raw gestures and uploaded captures to it, while the existing Camera2/DataChannel/upload path propagates `scene` and `mealSessionId`.

**Tech Stack:** Flutter/Dart unit tests, Kotlin/JUnit tests, Android MediaPipe Hand Landmarker, Camera2, WebRTC DataChannel, multipart HTTP.

---

### Task 1: Define and test the Dart state machine

**Files:**
- Create: `phone-app/lib/services/eating_session_controller.dart`
- Create: `phone-app/test/eating_session_controller_test.dart`

- [ ] **Step 1: Write failing controller tests**

Cover: two `open_palm` gestures from `idle` create one ID and enter `starting`; unrelated gestures do not exit an active session; the 2-second delay sends `{captureType: food, trigger: meal_start, scene: meal_before, mealSessionId}`; only an uploaded capture with both matching scene and session ID enters `eating`; two fists initiate `ending`; the corresponding `meal_after` ACK returns to idle while retaining paired captures; start send/timeout returns idle and end send/timeout returns eating; non-idle suppresses automatic packaging.

- [ ] **Step 2: Run the new test file and verify RED**

Run: `flutter test test/eating_session_controller_test.dart`
Expected: compile failure because `EatingSessionController` does not exist.

- [ ] **Step 3: Implement the minimum controller**

Expose `EatingSessionState { idle, starting, eating, ending }`, a `EatingSessionSnapshot`, `onGesture`, `onCaptureReceived`, `onCaptureSendFailed`, `dispose`, and injected clock/delay/ID/send callback seams. Keep only `OPEN_PALM` and `FIST` actionable in their stated states.

- [ ] **Step 4: Run controller tests and verify GREEN**

Run: `flutter test test/eating_session_controller_test.dart`
Expected: all session tests pass.

### Task 2: Extend the transport metadata before session integration

**Files:**
- Modify: `phone-app/lib/services/glass_receiver_service.dart`
- Modify: `glasses-app/app/src/main/java/com/example/rv101cameraprobe/CaptureRequest.kt`
- Modify: `glasses-app/app/src/main/java/com/example/rv101cameraprobe/WebRtcPreviewPublisher.kt`
- Modify: `glasses-app/app/src/main/java/com/example/rv101cameraprobe/CaptureService.kt`
- Modify: `glasses-app/app/src/main/java/com/example/rv101cameraprobe/PhotoUploader.kt`
- Create: `glasses-app/app/src/test/java/com/example/rv101cameraprobe/CaptureRequestTest.kt`

- [ ] **Step 1: Write failing metadata tests**

Assert that `GlassesCaptureRequest` retains a caller-provided `scene` and `mealSessionId`, and existing default food/app-button requests remain valid.

- [ ] **Step 2: Run Kotlin unit tests to verify RED**

Run: `gradlew.bat :app:testDebugUnitTest --tests com.example.rv101cameraprobe.CaptureRequestTest`
Expected: compilation failure because the new request fields do not exist.

- [ ] **Step 3: Implement metadata propagation**

`sendCaptureCommand` accepts optional `scene`/`mealSessionId`; DataChannel JSON carries them; glasses parsing, `CaptureUploadMetadata`, and multipart JSON preserve them. Existing packaging metadata remains `ingredient_label`; ordinary food remains `remote_preview`.

- [ ] **Step 4: Run metadata and existing tracker tests to verify GREEN**

Run: `gradlew.bat :app:testDebugUnitTest --tests com.example.rv101cameraprobe.CaptureRequestTest --tests com.example.rv101cameraprobe.CaptureRequestTrackerTest`
Expected: all selected Kotlin tests pass.

### Task 3: Add FIST classification safely

**Files:**
- Modify: `phone-app/android/app/src/main/kotlin/com/aiglasses/nutrition/PhoneSceneClassifier.kt`
- Create: `phone-app/android/app/src/test/kotlin/com/aiglasses/nutrition/GestureClassifierTest.kt`

- [ ] **Step 1: Write failing synthetic landmark tests**

Assert a curled four-finger fixture returns `FIST`, an OK pinch returns `OK`, and an open-palm fixture returns `OPEN_PALM`.

- [ ] **Step 2: Run the phone Android unit test to verify RED**

Run: `gradlew.bat testDebugUnitTest --tests com.aiglasses.nutrition.GestureClassifierTest` from `phone-app/android`.
Expected: compilation failure because `FIST` and fist classification are absent.

- [ ] **Step 3: Implement orientation-resistant fist geometry**

Check all four primary tips against PIP/MCP distances relative to wrist/palm scale, reject extended fingers, and retain classification order `OK`, `OPEN_PALM`, `FIST`, `UNKNOWN`. Return gesture `fist` with scene `unknown`.

- [ ] **Step 4: Run the gesture test to verify GREEN**

Run: `gradlew.bat testDebugUnitTest --tests com.aiglasses.nutrition.GestureClassifierTest` from `phone-app/android`.
Expected: all gesture cases pass.

### Task 4: Integrate session behavior, ACKs, Packaging priority, and debug UI

**Files:**
- Modify: `phone-app/lib/services/glass_receiver_service.dart`
- Modify: `phone-app/lib/services/phone_scene_classifier.dart`
- Modify: `phone-app/lib/recognition_page_fast.dart`
- Modify: `phone-app/lib/services/glass_capture_extensions.dart`
- Modify: `phone-app/test/eating_session_controller_test.dart`

- [ ] **Step 1: Write integration-facing failing tests**

Add tests proving automatic packaging is eligible only in idle; meal-before/after require capture upload ACKs matching both `scene` and `mealSessionId`; receive order and mismatches cannot advance state.

- [ ] **Step 2: Run Flutter targeted tests to verify RED**

Run: `flutter test test/eating_session_controller_test.dart test/packaging_capture_trigger_policy_test.dart`
Expected: at least the new session expectations fail before integration.

- [ ] **Step 3: Wire the controller into `GlassReceiverService`**

Forward native `gesture` values instead of inferring a session from `PhoneSceneMode.eating`; bridge delayed send commands; forward each saved `GlassCapture` as the only ACK source; update snapshots. Keep `UNKNOWN`/no hand latched, suppress OK packaging in starting/eating/ending, and do not call food VLM or create `MealRecord`.

- [ ] **Step 4: Add compact live-page debug presentation**

Show `IDLE`/`STARTING`/`EATING`/`ENDING`, start/end capture failures, session ID, and before/after image thumbnails in `_LivePreviewPane`; keep existing manual actions.

- [ ] **Step 5: Run Flutter targeted tests to verify GREEN**

Run: `flutter test test/eating_session_controller_test.dart test/packaging_capture_trigger_policy_test.dart test/capture_type_test.dart`
Expected: all selected tests pass.

### Task 5: Update documentation, run full validation, and commit

**Files:**
- Modify: `README.md`
- Modify: `phone-app/README.md`
- Modify: `glasses-app/README.md`
- Create: `docs/eating_session_hardware_test_plan.md`
- Create: `EATING_SESSION_IMPLEMENTATION_REPORT.md`

- [ ] **Step 1: Document the three independent streams and hardware procedure**

State that WebRTC remains active, low-resolution frames remain at 1 FPS/quality 58, and high-resolution 95-quality Camera2 JPEGs occur only at meal start/end. Document `adb devices`, explicit phone/RV101 selection, Android Studio entry points, expected protocol JSON, session ACK rules, limitations, and `NOT VERIFIED ON HARDWARE`.

- [ ] **Step 2: Create the hardware checklist**

Add the required test rows, expected values, `Actual Result`, `PASS/FAIL`, and `Notes` columns.

- [ ] **Step 3: Run complete validation**

Run: `flutter test`; `flutter analyze --no-fatal-infos --no-fatal-warnings`; `gradlew.bat :app:compileDebugKotlin :app:compileDebugUnitTestKotlin`; `gradlew.bat :app:testDebugUnitTest`; `gradlew.bat :app:assembleDebug`; and `git diff --check`. Report actual results without inferring hardware validation.

- [ ] **Step 4: Make a scoped local commit**

Stage only the Eating Session files, preserving the pre-existing 29 line-ending-only Flutter modifications. Commit: `feat: add gesture-controlled eating capture session`.
