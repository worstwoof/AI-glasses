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

## Actual Camera Capability and JPEG Evidence

- Camera ID: `0`.
- Supported JPEG (format 33) includes `4032x3024`, `4000x3000`, `4032x2268`, `3840x2160`, `3264x2448`, `3200x2400`, `1920x1080`, `1280x720`, `640x480`, and smaller outputs. The full system list was queried with `dumpsys media.camera`.
- Selected JPEG: `4032x3024`, the closest supported output to the production target.
- Preview: `640x480` YUV `ImageReader`.
- Final capture request diagnostic: `trigger=debug_http`, `type=food`, `scene=rv101_diagnostic`, `session=none`, `task=none`.
- Final capture: `capture_1786566480603_full.jpg`; Camera2 diagnostic reported `4032x3024`, 5,672,929 bytes.
- Pulled artifact: `docs/hardware_artifacts/rv101_capture_final_full.jpg` (ignored by Git); JPEG signature `FFD8FFE1`, dimensions `4032x3024`, SHA-256 `E2953C5A0C09E545B44C5356AABDA3B6F6AF34178B48CF218E75631130B4E66F`.
- Final post-hardening capture: `capture_1786567706571_full.jpg`, 5,650,633 bytes. Pulled as ignored `docs/hardware_artifacts/rv101_capture_post_policy_full.jpg`; signature `FFD8FFE1`, dimensions `4032x3024`, SHA-256 `9358D8D9E6FEF24E0DF6C5C91F4083C9378976CEEA92DE5A92C805EB43F78F50`.
- Capture was locally persisted when upload failed. Metadata code reads image bounds before upload, so it reports the actual file dimensions.

## Hardware Defect Found and Fixed

Observed: RV101 launches `MainActivity` without a drawable app window and sleeps after the short launch interval. The previous 300 ms window-focus-gated start never ran, and starting while asleep produced `CAMERA_DISABLED`.

Root cause: the device does not provide stable window focus/surface for this activity, while Camera2 requires the device to be awake. The launch path also posted its first capture start after Activity pause.

Fix: start from the resumed lifecycle state immediately, preserve the non-exported service and token checks, and add JVM coverage for lifecycle eligibility/timing. Hardware retest with `KEYCODE_WAKEUP` plus `svc power stayon true` opened Camera2, configured preview, captured the real JPEG, and restored preview.

The diagnostic endpoint is additionally hidden before token validation in non-debug builds, so release requests receive 404 rather than exposing a debug route through an authentication response. The debug policy has a JVM regression test; the post-hardening debug APK was rebuilt, reinstalled, and captured successfully on RV101.

## Release Packaging Boundary

`assembleRelease` compiled the release source but stopped at the pre-existing `targetSdk = 30` `ExpiredTargetSdkVersion` lint error. This validation round did not raise the target SDK because RV101 is Android 12/API 32 and the compatibility migration needs separately scoped hardware testing. Debug hardware validation is unaffected.

## Remaining Hardware Dependencies

- Real phone WebRTC signaling, remote video, and phone capture ACK need a phone on the same network.
- Real OPEN_PALM, FIST, and OK interaction needs a person in front of the device camera.
- Production food automatic/hybrid capture remains unavailable because no food-scene TFLite model is in the repository.
- Real vivo OCR needs valid credentials and a packaging image flow through a phone.
