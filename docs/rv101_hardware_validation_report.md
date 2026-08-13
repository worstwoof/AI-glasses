# RV101 Hardware Validation Report

Date: 2026-08-13

## Device and Build

- Device: `1906092624103119`, Rokid `RG-glasses`, product/device `glasses`.
- Android: 12 / API 32. ADB state was `device` throughout the final run.
- APK: `glasses-app/app/build/outputs/apk/debug/app-debug.apk`; the final post-hardening build was installed with `adb -s 1906092624103119 install -r` and returned `Success`.
- Package/activity: `com.example.rv101cameraprobe` / `.MainActivity`.
- CAMERA permission: runtime grant observed in `dumpsys package`.
- Local SDK configuration: `glasses-app/local.properties` uses `D:\\AndroidSDK`; the file is ignored and untracked.

## Automated RV101 Results

| Test | Status | Evidence |
| --- | --- | --- |
| ADB detection / authorization | PASS | `adb devices -l` reported the explicit serial in `device` state. |
| Install / launch / process | PASS | `install -r` returned `Success`; `pidof` returned a live process. |
| No application FATAL / ANR | PASS | Final filtered Logcat had no application `FATAL EXCEPTION` or ANR. The unrelated vendor `NcLib` `anr_strength_blender` messages are not an app ANR. |
| Camera permission | PASS | `android.permission.CAMERA: granted=true`. |
| Camera2 open | PASS | Camera ID `0` connected to `com.example.rv101cameraprobe`. |
| Preview session | PASS | `Camera session configured id=0 preview=640x480`. |
| Preview continuity | PASS | After still capture, the session was configured again and frame counts rose from 1 to 105, about 18 FPS. |
| Low-resolution scene frames | PARTIAL | 640x480 source frames continued at roughly 18 FPS; the reporter attempted JPEG quality 58 at the intended 1-second interval. Uploads failed safely with `ConnectException` because no phone server was present. |
| WebRTC publisher | PARTIAL | Publisher initialized, created offers and retried safely. Signaling failed with `ConnectException` to the unavailable `192.168.43.1:8080`; no remote phone video was available. |
| High-resolution JPEG | PASS | Debug-only, token-protected endpoint returned HTTP 202; final post-hardening JPEG completed and was saved. |
| Release debug-path isolation | PASS | The compiled release variant was signed locally for diagnosis and installed on RV101; `POST /api/v1/glasses/debug-capture` returned HTTP 404. Debug APK was immediately restored afterward. |

## Actual Camera Capability and JPEG Evidence

- Camera ID: `0`.
- Supported JPEG (format 33) includes `4032x3024`, `4000x3000`, `4032x2268`, `3840x2160`, `3264x2448`, `3200x2400`, `1920x1080`, `1280x720`, `640x480`, and smaller outputs. The full system list was queried with `dumpsys media.camera`.
- Selected JPEG: `4032x3024`, the closest supported output to the production target.
- Preview: `640x480` YUV `ImageReader`.
- Final capture request diagnostic: `trigger=debug_http`, `type=food`, `scene=rv101_diagnostic`, `session=none`, `task=none`.
- Final capture: `capture_1786566480603_full.jpg`; Camera2 diagnostic reported `4032x3024`, 5,672,929 bytes.
- Pulled artifact: `docs/hardware_artifacts/rv101_capture_final_full.jpg` (ignored by Git); JPEG signature `FFD8FFE1`, dimensions `4032x3024`, SHA-256 `E2953C5A0C09E545B44C5356AABDA3B6F6AF34178B48CF218E75631130B4E66F`.
- Final post-hardening capture: `capture_1786567706571_full.jpg`, 5,650,633 bytes. Pulled as ignored `docs/hardware_artifacts/rv101_capture_post_policy_full.jpg`; signature `FFD8FFE1`, dimensions `4032x3024`, SHA-256 `9358D8D9E6FEF24E0DF6C5C91F4083C9378976CEEA92DE5A92C805EB43F78F50`.
- Final rebuilt-debug retest: the new Debug APK was installed with `adb -s 1906092624103119 install -r`; `POST /api/v1/glasses/debug-capture` through an explicit ADB forward returned HTTP 202. It saved `capture_1786569974075_full.jpg`, 3,892,242 bytes; the pulled temporary artifact had `FFD8FFE1`, dimensions `4032x3024`, SHA-256 `B5BB43FF0329ED277312F0CE5BA8F6D306EE818A96FA5FFE9A09AFB51F2195D0`. The status endpoint returned to `DETECTING`, and Logcat showed a new `Camera session configured id=0 preview=640x480` followed by growing frame counts.
- Local mock receiver retest: the rebuilt Debug APK sent a real high-resolution multipart request to `POST /api/v1/captures` (2,216,546 bytes). The receiver returned HTTP 200 with `{"accepted":true}`, exercising the broadened 2xx acceptance policy; the capture status/log path recorded `Photo uploaded to phone` rather than a rejection.
- Reconnected-device retest (11:12-11:13): after reinstalling the Debug APK, the explicit status endpoint returned HTTP 200 with `running=true` and `Camera ready: 640x480; photo 4032x3024`; the process stayed at PID `18286`. A fresh debug capture returned HTTP 202, completed as `4032x3024` / 2,679,689 bytes, logged `Capture.saved`, and reconfigured the preview session. Frame counts continued from 1,185 to above 1,200 after the still capture. With the phone endpoint absent, the final status was `Upload failed: ConnectException; photo kept locally`, which is the expected offline fallback.
- Capture was locally persisted when upload failed. Metadata code reads image bounds before upload, so it reports the actual file dimensions.

## Hardware Defect Found and Fixed

Observed: RV101 launches `MainActivity` without a drawable app window and sleeps after the short launch interval. The previous 300 ms window-focus-gated start never ran, and starting while asleep produced `CAMERA_DISABLED`.

Root cause: the device does not provide stable window focus/surface for this activity, while Camera2 requires the device to be awake. The launch path also posted its first capture start after Activity pause.

Fix: start from the resumed lifecycle state immediately, preserve the non-exported service and token checks, and add JVM coverage for lifecycle eligibility/timing. Hardware retest with `KEYCODE_WAKEUP` plus `svc power stayon true` opened Camera2, configured preview, captured the real JPEG, and restored preview.

The diagnostic endpoint is additionally hidden before token validation in non-debug builds, so release requests receive 404 rather than exposing a debug route through an authentication response. The debug policy has a JVM regression test; the post-hardening debug APK was rebuilt, reinstalled, and captured successfully on RV101.

WebRTC reconnect defect: the previous implementation destroyed and recreated the native peer on every retry while the phone answer was still unavailable. On RV101 this eventually produced native `SIGSEGV` crashes on `signaling_thread` inside `libjingle_peerconnection_so.so` (observed at 05:33:03 and 06:23:37). The fix retains the pending local offer/peer connection until an answer is applied, and only rebuilds after negotiation failure or an applied remote description. The rebuilt APK short-window retest emitted one `createPeer`, then `reusePendingOffer`, with the process remaining alive; JVM coverage is in `WebRtcReconnectPolicyTest`.

## Release Packaging Boundary

Full `assembleRelease` compiled the release source but stopped at the pre-existing `targetSdk = 30` `ExpiredTargetSdkVersion` lint error. For this endpoint-isolation check only, the same release variant was assembled with `lintVitalRelease` excluded, locally signed with the Android debug keystore, and installed on RV101; it returned the required 404. This validation round did not raise the target SDK because RV101 is Android 12/API 32 and the compatibility migration needs separately scoped hardware testing. Debug hardware validation is unaffected.

## Remaining Hardware Dependencies

- Real phone WebRTC signaling, remote video, and phone capture ACK need a phone on the same network.
- Real OPEN_PALM, FIST, and OK interaction needs a person in front of the device camera.
- Production food automatic/hybrid capture remains unavailable because no food-scene TFLite model is in the repository.
- Real vivo OCR needs valid credentials and a packaging image flow through a phone.
