# RV101 Food Capture

AI glasses food-capture prototype for Rokid RV101, with local-network JPEG capture upload and WebRTC live preview.

## Modules

- `rv101-camera-probe`: Runs on Rokid RV101. Captures Camera2 preview frames, publishes WebRTC video, reports low-rate JPEG frames to the phone for classification, captures high-resolution JPEG images, and uploads them over the local network.
- `food-phone-receiver`: Legacy Android phone receiver prototype. It remains useful for upload protocol regression tests.
- `AI-glasses` Flutter app: The intended phone-side app. Its recognition page now listens on port 8080, answers WebRTC offers, renders the live preview, receives JPEG captures, and keeps the original single-image AI analysis flow.

## Local Network Protocols

Daily use is driven from the Flutter phone app:

1. Put the phone and RV101 on the same Wi-Fi network or phone hotspot.
2. Open the Flutter app and enter `识别 -> 实时预览`.
3. The phone listens on port 8080, scans the local subnet, and sends a start request to the RV101 control port `8088`.
4. The RV101 then starts Camera2 capture, publishes WebRTC preview frames, and keeps JPEG capture upload on the original HTTP endpoint.

The old RV101-side fruit ONNX detector and hand gesture model have been removed. Coarse gesture/scene classification now runs inside the Flutter phone APK through Android MediaPipe:

- OK gesture -> ingredient-label mode.
- Open palm -> eating-environment mode.
- Other frames -> waiting/unknown.

The current phase only changes the scene state shown in the phone app. It does not automatically create diet records yet.

The RV101 firmware blocks third-party cold autostart on full reboot. After a reboot, reinstall, or process kill, open `RV101 Camera Probe` once on the glasses so the local control server can run; after that the phone app can connect directly.

The glasses send a multipart request to the phone:

```text
POST http://<phone-ip>:8080/api/v1/captures
X-Device-Token: <pairing-token>

multipart/form-data
  image: JPEG
  metadata: JSON
```

The glasses also send a WebRTC offer to the same phone/port:

```text
POST http://<phone-ip>:8080/api/v1/webrtc/offer
X-Device-Token: <pairing-token>
Content-Type: application/json

{ "type": "offer", "sdp": "..." }
```

The phone returns an answer SDP. No TURN/STUN server is configured for this prototype; both devices must be connected to the same Wi-Fi network or phone hotspot. The RV101 app only needs the capture upload endpoint and pairing token. It derives the WebRTC signaling endpoint by replacing the upload path with `/api/v1/webrtc/offer`.

## Development Notes

- Do not commit Android Studio caches, Gradle build outputs, generated APKs, device captures, or `local.properties`.
- The two runtime model assets in the glasses project are intentionally tracked because the demo needs them to run.
- The current fruit detector is a small validation model, not a production food-recognition model.
- On Windows workspaces with non-ASCII paths, AGP requires `android.overridePathCheck=true`.

## Eating Session

The glasses keeps the Camera2 preview, WebRTC publisher, and PreviewFrameReporter running while the phone controls two event-driven food stills. It forwards scene and mealSessionId from meal_start/meal_end DataChannel commands into uploaded metadata. Still capture uses the existing Camera2 controller and JPEG quality 95; a received upload is the only phone-side session ACK. The phone remains responsible for gesture classification and the latched session state.