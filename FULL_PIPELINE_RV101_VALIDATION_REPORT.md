# Full Pipeline RV101 Validation Report

Date: 2026-08-13

## Starting Point

- Branch: `codex/organize-aiglasses-monorepo`.
- Starting HEAD: `eb3c691c7ca73c7258d44fc5994d95f04e5d62be`.
- Origin branch HEAD: `2a27bd54a5d2ae677269381e4388a525c9b2115c`; ahead/behind at start: `5/0`.
- The 29 modified Flutter `lib` files were verified with `git diff --ignore-space-at-eol`; they contain no semantic diff and remain unmodified by this round.

## Environment

- Windows 11; Java 21.0.9 at `D:\Java\jdk-21`.
- Flutter 3.41.5 / Dart 3.11.3 at `D:\flutter`.
- Android SDK 36.1.0 at `D:\AndroidSDK`; platform-tools ADB 37.0.0.
- `flutter doctor -v` accepted all Android licenses. Its only warning was external network reachability to Maven/GitHub.
- `glasses-app/local.properties` was generated locally with `sdk.dir=D:\\AndroidSDK`; ignored by Git.

## Build and Simulation Status

| Surface | Software implemented | Local simulation verified | RV101 verified | Phone hardware verified |
| --- | --- | --- | --- | --- |
| Phone Flutter / coordinator / eating / packaging | YES | YES | N/A | NO |
| Phone Android native gesture classifier | YES | YES | N/A | Emulator only |
| Glasses Camera2 / frame reporter / uploader | YES | JVM tests | YES | N/A |
| WebRTC remote video | YES | initialization/retry only | PARTIAL | NO |
| Production food auto/hybrid | Framework only | fake classifier only | UNAVAILABLE | NO |

## Fresh Validation Commands

- Phone: `flutter test` (69 passed), `flutter analyze --no-fatal-infos --no-fatal-warnings` (exit 0; 74 pre-existing deprecation infos), `flutter build apk --debug` (PASS), `android/gradlew.bat :app:testDebugUnitTest` (3/3 PASS), and fresh emulator install/launch (PASS, `com.aiglasses.nutrition/.MainActivity` top-resumed).
- Glasses: `gradlew.bat :app:compileDebugKotlin :app:compileDebugUnitTestKotlin :app:testDebugUnitTest :app:assembleDebug` (PASS). JVM tests: 13 total, 0 failures/errors. The final debug APK was reinstalled and hardware-captured after the debug-endpoint hardening. Full `assembleRelease` stops at the existing `targetSdk=30` Play lint requirement, but the compiled release APK was assembled with only that lint task excluded, signed with the local debug keystore for hardware diagnosis, and verified on RV101: `POST /api/v1/glasses/debug-capture` returned `404` before Debug was restored.
- RV101: install/launch/PID/CAMERA permission/Camera2 preview/high-resolution JPEG and preview restoration all have direct ADB/Logcat evidence in `docs/rv101_hardware_validation_report.md`.
- RV101 mock-phone upload: a real 2,216,546-byte `POST /api/v1/captures` received HTTP 200 `{"accepted":true}` and produced the `Photo uploaded to phone` status path. No phone hardware was involved.

## Final Hardening Addendum

- Coordinator: duplicate `captureTaskId` submissions are rejected for in-flight and recently completed work, bounded to 512 completed IDs. A 120-intent mixed-priority test confirms a single in-flight physical capture and queue drain.
- Retry provenance: a retry keeps its `originSource`, so an automatic task remains subject to automatic cooldown, automatic duplicate fingerprinting, meal-end cancellation, and background cancellation even though its current source is `retake`.
- Lifecycle: entering `RecognitionPageFast` enables automatic capture; backgrounding or disposal disables it. Queued/delayed automatic work is cancelled, while an already dispatched request remains awaiting ACK to avoid orphaning a real glasses capture.
- Upload idempotence: phone-side capture ingestion deduplicates in-flight and completed uploads by `captureTaskId`; failed deliveries may retry, and legacy uploads without an ID remain accepted.
- Packaging: a new `SharedPreferencesAsync` in-memory integration test verifies `LocalStorageService.savePackagingScan` followed by `loadPackagingScans`; packaging remains separate from `MealRecord`.

## RV101 Matrix

- Detection: PASS, serial `1906092624103119`, Rokid RG-glasses, Android 12/API 32, authorized/stable.
- Install / launch / process: PASS.
- Camera open, preview and low-resolution frame generation: PASS. Scene upload lifecycle: PARTIAL because the phone server was absent; `ConnectException` was handled without crash.
- High-resolution still: PASS. Selected and actual JPEG: `4032x3024`; the final post-hardening sample is a valid 5,650,633-byte JPEG and preview reconfigured after capture. A final rebuilt-debug retest produced another valid `4032x3024` JPEG (3,892,242 bytes, SHA-256 `B5BB43FF0329ED277312F0CE5BA8F6D306EE818A96FA5FFE9A09AFB51F2195D0`) after `POST /api/v1/glasses/debug-capture` returned HTTP 202.
- Reconnected RV101 retest: status HTTP 200 showed `running=true`; a new HTTP 202 debug capture produced `4032x3024` / 2,679,689 bytes, `Capture.saved`, and preview reconfiguration. The process remained alive while the phone endpoint was unavailable and the image was kept locally.
- WebRTC: publisher and ICE offer lifecycle initialized, but remote video is not PASS because the phone signaling endpoint was unavailable.

### WebRTC native crash hardening

The old retry loop recreated the native peer while an unanswered offer was still pending; RV101 logs showed `SIGSEGV` on `signaling_thread` in `libjingle_peerconnection_so.so`. The new lifecycle reuses the pending offer/peer until a remote answer is applied, then permits reconstruction only after a failed/applied negotiation. The rebuilt APK produced one peer creation followed by `reusePendingOffer`; no process death occurred in the validation window. `WebRtcReconnectPolicyTest` covers the policy.

## Three Modes and Quality

- Manual: locally verified through coordinator/session tests and RV101 diagnostic JPEG capture.
- Automatic: fake classifier test simulation PASS; production UNAVAILABLE. No food/not-food TFLite was found by repository search.
- Hybrid: explicit manual side uses the same verified coordinator; automatic portion UNAVAILABLE for the same model dependency.
- Quality algorithm: local validity/resolution/brightness/blur-proxy/duplicate policy tests PASS. RV101 sanity: one valid 4032x3024 sample; no calibration claim or threshold change.
- Packaging: local Coordinator/OCR parsing/risk/edit/recalculate/confirm/persist tests PASS. RV101 high-res source camera PASS. Real vivo OCR NOT TESTED (credentials/network absent).

## Lifecycle and Remaining Items

- The RV101 wake state is required: while `Asleep`, Camera2 correctly returned system `CAMERA_DISABLED`; after wake plus `svc power stayon true`, hardware capture passed.
- Human interaction still required: real OPEN_PALM, FIST, and OK gesture matrix.
- Phone hardware still required: remote WebRTC, real capture ACK, meal-before/meal-during/meal-after over a physical network.
- External dependency: food-scene TFLite model with documented input, labels, normalization, output and threshold.
- Credential/network dependency: real vivo OCR.
- P0 software blocker: none observed in the validated local/RV101 scope. Release distribution still needs a deliberately planned target SDK update because the existing `targetSdk=30` fails current Play lint.

## Final Status

`READY_FOR_FOOD_MODEL_INTEGRATION` and `READY_FOR_USER_HARDWARE_INTERACTION`: RV101 automated Camera2/high-resolution pipeline is validated; remaining work is external model, human gestures, physical phone integration, and OCR credentials.
