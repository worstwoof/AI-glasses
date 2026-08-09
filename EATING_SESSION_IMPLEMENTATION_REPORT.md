# Eating Session Implementation Report

## 1. Executive Summary

This round adds a latched Eating Session across the phone and RV101 apps. Two consecutive OPEN_PALM detections create a unique session, wait two seconds, send exactly one meal-before food capture, and enter EATING only after the matching uploaded GlassCapture is received. Two consecutive FIST detections then wait two seconds, send exactly one meal-after capture, and complete the same session only after the matching ACK. WebRTC preview and approximately 1 FPS low-resolution gesture sampling remain independent and are not stopped by the session controller.

## 2. Initial State

Starting HEAD was 7334d7a (`fix: harden packaging OCR pipeline`) on `codex/organize-aiglasses-monorepo`. The existing code already had WebRTC preview, 1 FPS scene JPEG reporting, OK/open-palm MediaPipe classification, food/packaging capture routing, and packaging OCR/risk tests. It did not have a FIST gesture, a persistent EatingSession state machine, meal-before/meal-after triggers, session metadata, or ACK matching.

The working tree already contained 29 unrelated Flutter files marked by LF/CRLF conversion. They were not staged or rewritten for this round.

## 3. Existing Teammate Work Investigation

Searches over the working tree, all local branches, and `git log --all --grep` found:

| Capability before this round | Result | Evidence |
| --- | --- | --- |
| FIST classifier | NOT FOUND | PhoneSceneClassifier had only OK, OPEN_PALM, UNKNOWN |
| Persistent EatingSession | NOT FOUND | No EatingSession/meal state model existed |
| Automatic high-resolution meal-before | NOT FOUND | Only manual food capture and automatic packaging capture existed |
| Automatic high-resolution meal-after | NOT FOUND | No meal_end trigger existed |
| Periodic high-resolution eating capture | NOT FOUND | No periodic meal capture loop existed |

No relevant teammate commit or branch was available in accessible refs.

## 4. Architecture

1. Realtime preview: Camera2 preview -> WebRtcPreviewPublisher -> phone RTCVideoView. Existing code remains active.
2. Gesture sampling: Camera2 preview -> PreviewFrameReporter -> `/api/v1/scene/frames` -> phone MediaPipe. Existing interval remains 1000 ms and JPEG quality remains 58.
3. Business capture: DataChannel capture command -> existing CaptureRequest/Camera2 still path -> PhotoUploader -> `/api/v1/captures` -> GlassReceiverService.

The controller never stops the camera, WebRTC publisher, PreviewFrameReporter, or MediaPipe classifier.

## 5. Gesture Logic

PhoneSceneClassifier now returns `gesture=fist` with `scene=unknown`. The new geometry classifier checks OK first, open palm second, and FIST third. FIST requires all four primary fingers to be folded relative to the wrist/palm scale and uses a fingertip cluster check; it is not a single absolute y-coordinate rule. Existing OK and OPEN_PALM behavior remains.

## 6. Eating State Machine

| State | Accepted gesture | Transition |
| --- | --- | --- |
| IDLE | OPEN_PALM x2 | STARTING, create mealSessionId |
| STARTING | none | after 2 s send meal_before; matching ACK -> EATING |
| EATING | FIST x2 | ENDING |
| ENDING | none | after 2 s send meal_after; matching ACK -> IDLE |

UNKNOWN, no-hand, OPEN_PALM, and OK do not leave EATING. A send failure or ACK timeout returns STARTING to IDLE and ENDING to EATING. A control-channel disconnect uses the same recovery behavior.

## 7. Capture Protocol

Meal start command:

    {"type":"capture","captureType":"food","trigger":"meal_start","scene":"meal_before","mealSessionId":"meal_...","timestamp":...}

Meal end command:

    {"type":"capture","captureType":"food","trigger":"meal_end","scene":"meal_after","mealSessionId":"meal_...","timestamp":...}

The glasses carries scene and mealSessionId through GlassesCaptureRequest, CaptureUploadMetadata, and PhotoUploader multipart metadata. Legacy commands without those fields retain their existing defaults.

## 8. Session Pairing

The controller creates a microsecond-based ID with an additional suffix on every IDLE -> STARTING transition. Both commands use the same active ID. The phone accepts an ACK only when capture type is food, scene matches the pending meal scene, and mealSessionId matches the active session. The completed ID remains visible in the debug snapshot.

## 9. Capture ACK

DataChannel send success only starts the ACK timeout; it is not treated as a photo success. The state advances only from the multipart upload handler after a real GlassCapture has been saved and its metadata matches the pending scene and session ID. Wrong scene/session uploads are ignored by the controller.

## 10. Failure Handling

- Control channel unavailable or send exception: STARTING -> IDLE; ENDING -> EATING.
- No upload ACK before the 12-second timeout: same recovery as send failure.
- Wrong scene, wrong session, or packaging upload: ignored and the pending state remains.
- DataChannel/peer disconnect during STARTING or ENDING: the controller recovers to the preceding stable state.

## 11. Packaging Interaction

The existing two-frame OK rising-edge packaging trigger is preserved. The trigger is sent only when the EatingSession state is IDLE. STARTING, EATING, and ENDING suppress automatic packaging, so an OK frame cannot interrupt or restart an active meal.

## 12. MealRecord Safety

This round does not create a MealRecord, call the food VLM automatically, calculate before/after calorie differences, or add periodic high-resolution eating captures. The existing manual food analysis flow remains available.

## 13. UI

RecognitionPageFast now shows the Eating Session state, pending scene, session ID, failure text, and meal-before/meal-after thumbnails in the live preview pane. Existing manual food and packaging buttons remain available.

## 14. Tests

Executed:

- `flutter test test/eating_session_controller_test.dart test/packaging_capture_trigger_policy_test.dart test/capture_type_test.dart` -> 10 tests passed.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` -> exit 0; only existing/deprecation info diagnostics remained.
- `glasses-app\\gradlew.bat :app:testDebugUnitTest --console=plain` with `ANDROID_HOME=D:\\AndroidSDK` -> BUILD SUCCESSFUL; all glasses Kotlin tests passed.
- Kotlin standalone `GestureLandmarkClassifier` smoke fixture -> OK, OPEN_PALM, and FIST checks passed.

The phone Android JUnit task and phone APK build were attempted but exceeded the environment timeout without output. They are recorded as NOT RUN/NOT VERIFIED rather than inferred from Flutter tests.

## 15. Hardware Status

NOT VERIFIED ON HARDWARE. No RV101 camera, Android phone UI, WebRTC continuity, real OPEN_PALM/FIST accuracy, high-resolution meal-before/meal-after capture, or same-session upload pairing has been exercised on devices.

## 16. Hardware Test Plan

See [`docs/eating_session_hardware_test_plan.md`](docs/eating_session_hardware_test_plan.md).

## 17. Remaining Risks

- FIST false positives/negatives on real camera angles and hand orientations.
- OPEN_PALM false starts and two-frame detection latency at 1 FPS.
- Two-second settle experience and hand still visible at capture time.
- Camera2 still capture latency/fallback and its effect on perceived WebRTC smoothness.
- Upload ACK latency, disconnect/reconnect timing, and malformed or mismatched metadata.
- Phone APK/native Gradle verification remains pending in this environment.


## Final Validation Update

After the report draft was written, the following additional commands were executed:

- flutter test -> 39 tests passed.
- glasses-app\gradlew.bat :app:compileDebugKotlin :app:compileDebugUnitTestKotlin with ANDROID_HOME=D:\AndroidSDK -> BUILD SUCCESSFUL.
- glasses-app\gradlew.bat :app:assembleDebug with ANDROID_HOME=D:\AndroidSDK -> BUILD SUCCESSFUL.
- The phone Flutter APK build was attempted for 300 seconds and timed out without Gradle output; no APK success is claimed.