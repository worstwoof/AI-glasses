# AI Glasses Monorepo

This repository contains the two local-network apps for the AI glasses food-health prototype.

## Folders

- `phone-app/`: Flutter Android health-management App. It receives local HTTP/WebRTC traffic, renders RV101 preview, keeps the user profile and displays food or packaging analysis.
- `glasses-app/`: Rokid RV101 Android App. It drives Camera2, sends WebRTC preview/scene frames, captures JPEGs and uploads them to the phone.

## Runtime Flow

1. Put the phone and RV101 on the same Wi-Fi network or phone hotspot.
2. Open the phone App and enter `识别 -> 实时预览`.
3. The phone listens on port `8080`, discovers the RV101 control server on `8088`, then establishes WebRTC preview.
4. The RV101 sends low-rate scene frames to `POST /api/v1/scene/frames`; the phone runs MediaPipe locally.
5. A phone-side OK pinch can enter ingredient-label mode. It is not a verified RV101 hardware thumb event.

## Packaging Pipeline

```text
OK pinch or 包装抓拍 button
  -> DataChannel { type: capture, captureType: packaging }
  -> RV101 Camera2 high-resolution JPEG
  -> POST /api/v1/captures multipart metadata.type=packaging
  -> GlassReceiverService saves the original JPEG
  -> PackagingAnalysisPage
  -> vivo OCR -> NutritionFactsParser -> PackagingRiskEngine
  -> OCR text, nutrition facts, risks and profile-aware guidance
```

- `food` captures retain the original `VivoFoodVisionServiceV3` path and can be confirmed as `MealRecord` by the existing food UI.
- `packaging` captures clear the food-image selection, are denied by the food route policy, bypass the food VLM, and never auto-create a `MealRecord`; a packaging page remains in `NEED_CONFIRMATION` after analysis.
- The automatic packaging trigger is a rising edge of the phone-side `ingredientLabel` state. An 8-second cooldown starts only after a successful DataChannel send and automatic capture is suppressed while packaging analysis is active; manual requests use `packaging_button`.
- The glasses JPEG is the OCR source of truth. `PackagingAnalysisPage` passes `XFile(capture.imageFile.path)` directly to OCR without `ImagePicker`, `imageQuality`, resize, or re-encoding.
- RV101 chooses the supported JPEG closest to the `4032x3024` target; it does not claim a guaranteed `4032x3024 -> 1920x1080` retry sequence. If JPEG capture is unavailable, the tagged `640x480` preview fallback is shown with a quality warning.
- The separate manual `IngredientLabelPageFast` intentionally remains an ImagePicker flow and may use `imageQuality`/`maxWidth`; it is not the glasses packaging OCR path.

## Configuration

Packaging OCR requires a runtime key. Do not commit real values:

```powershell
flutter build apk --debug --dart-define=AI_API_KEY=$env:AI_API_KEY
```

`IngredientLabelServiceV2` retains the existing vivo OCR endpoint and reads the original `XFile` bytes into base64. The current default OCR URL is the existing HTTP endpoint; verify vendor HTTPS support before changing it. Rotate any credential that may have existed in repository history.

## Build

Phone App:

```powershell
cd phone-app
flutter pub get
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --debug --dart-define=AI_API_KEY=$env:AI_API_KEY
```

RV101 glasses App:

```powershell
cd glasses-app
.\gradlew.bat :app:assembleDebug --console=plain
```

Install only with an explicit device serial:

```powershell
adb -s <phone-serial> install -r phone-app\build\app\outputs\flutter-apk\app-debug.apk
adb -s <rv101-serial> install -r glasses-app\app\build\outputs\apk\debug\app-debug.apk
```

## Validation Documents

- `PACKAGING_OCR_IMPLEMENTATION_REPORT.md`: implementation, evidence, limitations and next steps.
- `docs/packaging_ocr_test_plan.md`: 13 packaging-image scenarios for real-device testing.
- `glasses-app/docs/AI眼镜采集与手机App衔接说明.md`: local-network, Camera2 and WebRTC integration reference.
## Packaging Rule Limits

`NutritionFactsParser` parses an explicit nutrition-table candidate when OCR contains `营养成分表` or `营养标签`; it falls back to full text only when no title exists. Risk thresholds have separate per-100g food and per-100mL drink fields, but their prototype defaults are not medical or regulatory standards and require product/domain validation. The packaging path uses vivo OCR plus deterministic parsing/rules; it does not call a text-generation model.