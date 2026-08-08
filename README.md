# AI Glasses Monorepo

This repository contains the two local-network apps for the AI glasses food
capture prototype.

## Folders

- `phone-app/`: Flutter Android phone app. It hosts the local HTTP/WebRTC
  receiver, renders the RV101 live preview, receives JPEG captures, and runs the
  phone-side coarse scene classifier.
- `glasses-app/`: Rokid RV101 Android app. It captures Camera2 preview frames,
  publishes WebRTC video, reports low-rate JPEG frames to the phone, and handles
  high-resolution JPEG capture/upload.

## Current Runtime Flow

1. Put the phone and RV101 on the same Wi-Fi network or phone hotspot.
2. Open the phone app and enter `识别 -> 实时预览`.
3. The phone listens on port `8080`, scans the local subnet, and sends a start
   request to the RV101 control server on `8088`.
4. The RV101 starts Camera2 capture and WebRTC preview.
5. The RV101 sends low-rate scene frames to
   `POST /api/v1/scene/frames`; the phone app classifies OK/open-palm gestures
   locally with MediaPipe.
6. High-resolution JPEG capture still flows through
   `POST /api/v1/captures` and then into the original AI food analysis path.

The old RV101-side fruit model has been removed. Coarse scene classification now
runs on the phone:

- OK gesture: ingredient-label/OCR mode.
- Open palm: eating-environment mode.
- Other frames: waiting/unknown.

## Build

Phone app:

```powershell
cd phone-app
flutter pub get
flutter build apk --debug
```

RV101 glasses app:

```powershell
cd glasses-app
.\gradlew.bat :app:assembleDebug --console=plain
```

Always install with an explicit device serial:

```powershell
adb -s <phone-serial> install -r phone-app\build\app\outputs\flutter-apk\app-debug.apk
adb -s <rv101-serial> install -r glasses-app\app\build\outputs\apk\debug\app-debug.apk
```
