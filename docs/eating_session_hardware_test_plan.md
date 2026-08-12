# Eating Session Hardware Validation

## Before You Start

1. Connect the phone and RV101 to the same Wi-Fi network or phone hotspot.
2. Run `adb devices` and record every serial. Do not assume the first device is the phone.
3. Install/run `phone-app` on the Android phone serial and `glasses-app` on the RV101 serial.
4. Open the phone app's Recognition -> Live Preview page. If the glasses process was killed or the device rebooted, open RV101 Camera Probe once from the glasses launcher first.

## Android Studio Entry Points

- Open `D:\Desktop\AI-glasses\glasses-app` in Android Studio, select the RV101 device, run/debug the app, and inspect the `rv101_capture` Logcat tag.
- Open the Flutter project `D:\Desktop\AI-glasses\phone-app` in Android Studio or run `flutter run` from that directory after selecting the phone serial. Inspect Flutter logs and the `com.aiglasses.nutrition` native logs.
- When more than one ADB device is connected, use an explicit serial, for example `adb -s <phone-serial> install -r ...` and `adb -s <rv101-serial> install -r ...`.

## Expected Streams

- WebRTC preview remains continuously active while the session changes state.
- Camera2 preview frames continue to feed both WebRTC and low-resolution gesture sampling. Scene frames are approximately 1 FPS, 640x480-class JPEG, quality 58.
- High-resolution Camera2 JPEG capture is event-driven only: one `meal_before` after start and one `meal_after` after end. The still request uses JPEG quality 95 and does not intentionally destroy the WebRTC publisher or frame reporter.

## Test Matrix

| Test | Expected | Actual Result | PASS/FAIL | Notes |
| --- | --- | --- | --- | --- |
| WebRTC | Continuous live video before, during, and after capture |  |  |  |
| Scene frame | Approximately 1 FPS | RV101 repeatedly generated 640x480 frames; no receiver | PARTIAL | Reporter attempted 1 FPS uploads; absent phone server produced handled `ConnectException`. |
| RV101 camera open / preview | Camera opens and 640x480 session runs | Camera 0 opened; preview session configured; about 18 FPS | PASS | Automated 2026-08-13. |
| RV101 high-resolution JPEG | Select closest JPEG and preserve preview | Selected/actual 4032x3024 valid JPEG; preview restored | PASS | Debug-only token-protected diagnostic capture; see `rv101_hardware_validation_report.md`. |
| OPEN_PALM frame 1 | Remains `IDLE`; no command |  |  |  |
| OPEN_PALM frame 2 | Enters `STARTING` |  |  |  |
| Settle delay | Two seconds lets the hand leave the frame |  |  |  |
| Meal before | One high-resolution JPEG with `trigger=meal_start`, `scene=meal_before` |  |  |  |
| Remove hand | Session remains `EATING` |  |  |  |
| FIST frame 1 | Remains `EATING`; no command |  |  |  |
| FIST frame 2 | Enters `ENDING` |  |  |  |
| Meal after | One high-resolution JPEG with `trigger=meal_end`, `scene=meal_after` |  |  |  |
| Session ID | Before/after metadata has the same non-empty `mealSessionId` |  |  |  |
| OK while idle | Existing Packaging capture behavior |  |  |  |
| OK while eating | No Packaging capture |  |  |  |
| Disconnect during starting | Returns to `IDLE` with a visible failure |  |  |  |
| Disconnect during ending | Returns to `EATING` with a visible failure |  |  |  |

## Evidence To Record

- Phone screen or Logcat showing `IDLE`, `STARTING`, `EATING`, and `ENDING`.
- The two capture metadata JSON objects, their image dimensions/source, and matching `mealSessionId`.
- Whether the WebRTC frame counter and low-resolution scene frame counter continue through both still captures.
- Any camera fallback, upload timeout, wrong-session upload, or reconnect behavior.

Hardware status: RV101 automated camera rows above are verified. WebRTC remote video, phone ACK/session rows, packaging OCR, and real-person gesture rows remain `PENDING USER INTERACTION` or `PENDING PHONE HARDWARE` until the phone and user are available.
