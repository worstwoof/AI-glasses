# Packaging OCR Implementation Report

## 1. Executive Summary

本次完成了“眼镜包装食品高清抓拍 -> OCR -> 营养字段解析 -> 配料/风险筛查 -> 用户档案提示 -> 手机展示”的软件闭环。`food` 仍走 `VivoFoodVisionServiceV3`，`packaging` 走独立的 OCR、规则解析和 UI，且不会自动写入 `MealRecord`。实现已通过 Flutter 的 19 项业务测试与静态分析；真实 RV101、有效 vivo OCR 凭据、反光/曲面等场景仍未实测。

## 2. Initial State

父提交 `11f8d85` 已具备 Camera2 预览、高分 JPEG 抓拍、HTTP multipart 上传、手机 WebRTC 接收、MediaPipe OK/open-palm 分类和 food VLM。它没有 `CaptureRequest`/`CaptureType`、包装领域模型、包装页面、营养 parser、风险引擎、包装业务测试或测试矩阵；所有眼镜图片都会保留在原 food 交互路径。父提交没有 `phone-app/test/` 和 packaging 相关文件。当前父提交代码检索确认 `RecognitionPageFast` 监听 captures，但只调用 food VLM。

基线未对父提交重新切换并运行测试，避免覆盖本次工作；当前实现的可运行验证结果见第 13 节。父提交后本次运行环境的 Android Gradle 离线缓存缺少部分 runtime artifact，见第 13 节。

## 3. Architecture After Changes

```text
Phone OK pinch / 包装抓拍 button
      -> DataChannel { type: capture, captureType: packaging, trigger, timestamp }
      -> GlassesCaptureRequest / CaptureType
      -> Camera2 chooses the supported JPEG closest to the 4032x3024 high-resolution target; JPEG capture failure falls back to preview
      -> PhotoUploader multipart metadata.type=packaging
      -> GlassReceiverService saves original imageFile
      -> RecognitionPageFast routes packaging
      -> PackagingAnalysisPage
      -> IngredientLabelServiceV2 vivo OCR
      -> NutritionFactsParser + PackagingRiskEngine + AppUserProfile
      -> PackagingAnalysisResult
      -> image, OCR text, nutrition, risks and guidance UI
```

`food` capture continues as `RecognitionPageFast -> VivoFoodVisionServiceV3 -> AnalysisResult -> existing confirmation/MealRecord` and does not enter the packaging page.

## 4. Files Changed

- `A glasses-app/.../CaptureRequest.kt`: adds typed `CaptureType` and `GlassesCaptureRequest`; keeps missing/unknown commands safe.
- `M glasses-app/.../WebRtcPreviewPublisher.kt`: parses DataChannel `captureType`, `trigger`, and `timestamp` into the request model.
- `M glasses-app/.../CaptureService.kt`: preserves request metadata through capture/upload and now reserves it before Camera2 fallback can callback.
- `A glasses-app/.../CaptureRequestTracker.kt`: small pure tracker prevents duplicate requests and stale metadata during capture startup.
- `M glasses-app/.../PhotoUploader.kt`: serializes `type`, `captureSource`, timestamp and actual JPEG dimensions in multipart metadata.
- `A glasses-app/.../CaptureRequestTrackerTest.kt`: JVM regression test for tracker reservation and duplicate rejection.
- `M phone-app/lib/services/glass_receiver_service.dart`: sends typed commands, parses receives safely, and adds automatic rising-edge/cooldown behavior.
- `A phone-app/lib/packaging_models.dart`: dedicated capture, nutrition, risk and packaging-result models.
- `A phone-app/lib/services/glass_capture_extensions.dart`: type-safe access to capture metadata and fallback detection.
- `A phone-app/lib/services/nutrition_facts_parser.dart`: deterministic, pure nutrition parser.
- `A phone-app/lib/services/packaging_risk_engine.dart`: deterministic allergen/nutrition/profile rule engine.
- `A phone-app/lib/services/packaging_analysis_service.dart`: OCR orchestration into a packaging result.
- `A phone-app/lib/services/packaging_analysis_route_gate.dart`: prevents duplicate packaging navigation.
- `M phone-app/lib/recognition_page_fast.dart`: manual packaging capture action and food/packaging routing.
- `A phone-app/lib/packaging_analysis_page.dart`: packaging-specific result and retry UI.
- `M phone-app/lib/services/ingredient_label_service_v2.dart`: exposes existing OCR entry point and removes embedded key.
- `M phone-app/lib/services/vivo_food_vision_service_v3.dart`: removes embedded key from food VLM service.
- `A phone-app/test/capture_type_test.dart`: backward compatibility and unknown type behavior.
- `A phone-app/test/nutrition_facts_parser_test.dart`: parser fixtures and missing-value checks.
- `A phone-app/test/packaging_analysis_service_test.dart`: end-to-end text orchestration and OCR source marker.
- `A phone-app/test/packaging_risk_engine_test.dart`: risk/profile behavior.
- `A phone-app/test/packaging_analysis_route_gate_test.dart`: single active packaging page behavior.
- `A docs/packaging_ocr_test_plan.md`: 13 real-world packaging test scenarios.
- `M README.md`: documents food/packaging split, original-image handling and key configuration.
- `A PACKAGING_OCR_IMPLEMENTATION_REPORT.md`: this report.

## 5. Protocol Changes

Before DataChannel:

```json
{"type":"capture","trigger":"app_button"}
```

After DataChannel:

```json
{"type":"capture","captureType":"packaging","trigger":"packaging_button","timestamp":123456789}
```

Before multipart metadata had device, timestamp, trigger, scene, confidence, width and height. After it additionally contains `type=food|packaging` and `captureSource=high_res_jpeg|preview_fallback`. Missing `captureType` and missing metadata `type` default to `food`; unknown values become `unknown` and do not throw.

## 6. High-resolution Image Handling

1. Yes. `PackagingAnalysisPage` sends `XFile(widget.capture.imageFile.path)` directly to OCR.
2. No default resize occurs. The original file is retained; no derived-copy retry exists yet.
3. No ImagePicker is used in the glasses packaging path.
4. `captureSource=preview_fallback` or dimensions at or below 640 mark a low-resolution result and show a warning.
5. Yes. The receiver persists upload bytes; no packaging code overwrites that file.
6. Camera2 uses the supported JPEG closest to the 4032x3024 target. It does not implement a guaranteed 4032 -> 1920 runtime retry; when JPEG capture is unavailable it uses the existing preview fallback. A 20 MB receiver limit exists, while the vivo large-image/API limit remains unverified.

## 7. OCR Implementation

Provider remains `IngredientLabelServiceV2` with the existing vivo general OCR endpoint. It calls `image.readAsBytes()`, base64-encodes the original image, sends the configured business/request IDs, and joins `result.words`/`result.OCR` into raw text. OCR text is kept in `PackagingAnalysisResult.rawOcrText` and can be copied in UI.

`AI_API_KEY` is injected with `--dart-define`; no key is embedded in current source. Packaging uses deterministic parser/risk rules after OCR, not the optional text chat-completion analysis. Therefore a text-summary failure cannot erase parsed packaging data; an OCR failure itself becomes an explicit retryable error. The default OCR URL remains the pre-existing HTTP URL because official HTTPS equivalence was not independently verified.

## 8. Nutrition Parser

`NutritionFactsParser` first detects a conservative `营养成分表`/`营养标签` candidate section and stops at a subsequent packaging heading such as `配料` or `净含量`; only that section is parsed when available. Without a title it falls back to the full OCR text and records `sectionDetected=false`. It supports energy, protein, fat, carbohydrate, sodium and optional sugar; aliases `蛋白`, `总脂肪`, `碳水`, `Na`; units `kJ`, `kcal`, `千焦`, `千卡`, `g`, `mg`, `克`, `毫克`; and bases `per100g`, `per100ml`, `perServing`, `unknown`. Decimal comma is normalized only between digits. Each parsed value retains its raw substring; missing fields remain null, never zero.

Known limits: OCR table geometry is flattened, labels/values on distant lines are not paired, and ambiguous `O/I` character correction is intentionally not guessed.

## 9. Risk Rules

`PackagingRiskEngine` separately evaluates canonical common-allergen aliases, added-sugar ingredients, sodium, fat, optional quantitative sugar and caution ingredients. `PackagingRiskThresholds` now keeps independent food-per-100g and drink-per-100mL configuration fields; their current prototype defaults deliberately retain the former values pending product/domain validation and are not a claimed regulatory or medical standard. Per-serving and unknown bases never receive a per-100 quantitative classification.

Profile rules use `allergies`, `conditions`, `preference` and `goal` deterministically. Matched allergens become high priority; hypertension/low-salt, lipid/fatty-liver/low-fat, diabetes/glucose-control and weight-management wording only produces restrained guidance. Carbonhydrate is never treated as sugar. Keyword hits are not medical diagnoses.

## 10. UI

`RecognitionPageFast` has a manual `包装抓拍` request and routes uploaded `CaptureType.packaging` to `PackagingAnalysisPage`. Packaging clears the food-image selection and is additionally denied by the food route policy, so closing the packaging page cannot make that image available to `VivoFoodVisionServiceV3`. Automatic packaging capture is suppressed while a packaging analysis route is active; manual requests show a visible message in that state. The page displays the original image, source/dimensions, `RECEIVED`, `ANALYZING`, `NEED_CONFIRMATION`, `FAILED`, structured nutrition fields, ingredients, rule risks, profile suggestions, selectable OCR text and an OCR retry button. Low-resolution fallback shows a visible warning.

## 11. Food Regression

The food request still sends `captureType=food`; non-packaging uploads retain the existing food notification and `VivoFoodVisionServiceV3.analyzeImage` action. Packaging is never stored as the food selection in `_handleGlassCapture`, and `CaptureType.canUseFoodAnalysis` explicitly denies packaging before the food VLM call.

## 12. MealRecord Safety

`PackagingAnalysisPage` is pushed inside `RecognitionPageFast` and returns `void`; it never creates or returns `AnalysisResult`. `AppShellPro` only creates `MealRecord` from a returned `AnalysisResult`, so a packaging result cannot be automatically recorded as consumed food.

## 13. Tests Run

- PASS: `D:\flutter\bin\cache\dart-sdk\bin\dart.exe ... flutter_tools.snapshot test test/capture_type_test.dart test/nutrition_facts_parser_test.dart test/packaging_analysis_service_test.dart test/packaging_risk_engine_test.dart test/packaging_analysis_route_gate_test.dart` -> 19 tests passed.
- PASS: `D:\flutter\bin\cache\dart-sdk\bin\dart.exe ... flutter_tools.snapshot analyze --no-fatal-infos --no-fatal-warnings` -> exit 0; 71 existing Flutter deprecation infos, no new compile error.
- PASS: `git diff --cached --check` before commit -> no whitespace error; secret pattern scan had no result.
- PARTIAL: `glasses-app\gradlew.bat --offline --no-daemon :app:testDebugUnitTest --console=plain` -> `compileDebugKotlin` and `compileDebugUnitTestKotlin` passed, but runtime test task failed because four AndroidX artifacts were not cached offline.
- BLOCKED/NOT RUN: full online RV101 Gradle test did not finish in the command time budget; no Android unit test is claimed as passed.

## 14. Test Coverage

Parser tests cover Chinese per-100g, English units, spacing, per-100ml, per-serving/per-package, unknown basis, missing fields and carbohydrate-not-sugar. Risk tests cover matching/nonmatching peanut allergy, high sodium/fat only with comparable bases, added sugar without numeric sugar, conditions/preference/goal, caution ingredients and empty data. Service tests cover combined parsing/risk evaluation and real OCR-adapter provenance. Capture type and route gate tests cover compatibility and duplicate-navigation protection. The Kotlin tracker test compiles but did not execute because of the runtime classpath blocker above.

## 15. Hardware / Real-world Tests

### 实际已测试

Only local source, Flutter business tests, analyzer and Kotlin compilation tasks were tested. No physical package image, RV101 device or vivo OCR request was executed in this environment.

### 尚未测试

`NOT VERIFIED ON HARDWARE`: RV101 packaging command, 4032x3024 OCR, 1920x1080 OCR, 640x480 fallback, reflective package, curved text, wrinkles, motion blur, snack, drink bottle and instant-food package. The 13-scenario plan is in `docs/packaging_ocr_test_plan.md`.

## 16. Known Limitations

OCR loses table layout and may miss values after reflections, curves, blur, folds, oblique capture or small fonts. The API large-image limit, vendor response variants and network latency remain unverified. Sugar is often absent from domestic labels and stays null. There is no derived OCR copy retry, image fusion, perspective correction or barcode lookup. Rules are conservative health-management screening, not medical advice. Packaging analysis is not persisted as a separate history record yet.

## 17. Recommended Next Steps

1. Execute the 13-scenario RV101 test plan with valid vivo credentials and record actual dimensions/OCR quality.
2. Resolve Gradle runtime cache/network availability, then run `:app:testDebugUnitTest` and an APK build.
3. Based on real failures, add explicit crop/rotation/perspective/multi-frame selection rather than silent compression.
4. Add a user-confirmed packaging history model only if the product requires it.
5. Reuse `PackagingAnalysisService`/a shared view in `IngredientLabelPageFast` as a low-risk P1 cleanup.
## 18. Round 2 Correctness Corrections

The second review fixed the residual packaging-to-food selection leak, conservative nutrition-section extraction, egg-allergen false positives from generic `蛋白`, canonical profile matching, basis-separated threshold configuration, broad single-character condition matching, failed-send cooldown consumption, active-analysis automatic capture suppression, and the ambiguous `usedAi` flag. Packaging results now report `analysisSource`: cloud vivo OCR followed by deterministic parsing/risk rules, with no text-generation model in this pipeline.
## 19. Superseding Round 2 Verification

Round 2 supersedes the earlier offline-only Android result: `flutter test` passed 34 tests, including the explicit `perServing` high-content boundary regression; `flutter analyze --no-fatal-infos --no-fatal-warnings` exited 0 with 71 existing deprecation infos, and the online `:app:testDebugUnitTest` task passed after Gradle resolved its previously uncached AndroidX runtime artifacts. The detailed issue-by-issue evidence is in `PACKAGING_OCR_FIX_ROUND2_REPORT.md`.
