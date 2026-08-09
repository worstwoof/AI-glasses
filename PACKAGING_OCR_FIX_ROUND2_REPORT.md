# Packaging OCR Fix Round 2 Report

## 1. Summary

本轮不是新增功能，而是针对第一轮静态审查发现的 correctness 问题进行定点修复、回归测试和重新验证。

## 2. Git Sync

- Before local HEAD: `d88089a feat: add packaging OCR capture pipeline`
- Before origin HEAD: `2a27bd5 document ai glasses technical route`
- Sync action: `git fetch origin` followed by `git rebase origin/codex/organize-aiglasses-monorepo`
- Conflicts: none
- After sync base: `927243a feat: add packaging OCR capture pipeline` on top of `2a27bd5`
- This report is written before the second-round local commit; final commit is recorded in the final verification checklist.

## 3. Issue-by-Issue Fixes

### ISSUE 1 — Packaging leaking into Food VLM

- Before/root cause: `RecognitionPageFast` assigned every capture to `_selectedImage` before checking `CaptureType.packaging`, so a closed packaging page could leave its image eligible for “分析最新图”.
- Fix: packaging clears the food selection, records its type, opens only `PackagingAnalysisPage`, and `CaptureType.canUseFoodAnalysis` rejects packaging before `VivoFoodVisionServiceV3`.
- Regression test: food and unknown values remain food-compatible; packaging is denied by `capture_type_test.dart`.
- Result: a packaging capture cannot reach the food VLM or create an `AnalysisResult`/`MealRecord` through the latest-image action.

### ISSUE 2 — JPEG resolution strategy mismatch

- Before: `HIGH_RESOLUTION_PREFERENCES` listed 4032x3024 and 1920x1080, but its index never changed; code actually chose the size nearest to the first target.
- Decision: retain the safer existing best-available JPEG strategy rather than inventing a runtime Camera2 session retry.
- Fix: remove the dead preference/index path; a pure `CameraOutputSizeSelector` chooses the supported output closest to 4032x3024. Camera2 maps only at its boundary; unavailable JPEG capture retains existing preview fallback.
- Test: pure JVM tests cover target present and target absent/1920x1080 available.
- Documentation: README, implementation report and test plan no longer claim a fixed 4032 -> 1920 -> 640 sequence.

### ISSUE 3 — Whole-document nutrition parsing

- Before: parser scanned the entire OCR text, allowing ingredient quantities to win before nutrition values.
- Failure example: `大豆分离蛋白 20g` could be returned instead of nutrition-table `蛋白质 8.5克`.
- Fix: detect `营养成分表`/`营养标签`, parse only its conservative candidate section and stop at the next packaging heading. Expose `sectionDetected`; if no title exists, safely fall back to full text.
- Regression tests: ingredient protein, sodium salt, title absence, section ending, and newline-split labels/values.

### ISSUE 4 — Generic “蛋白” egg allergen false positive

- Before: the generic alias `蛋白` classified soy/dairy proteins as egg allergen.
- Fix: remove that alias. Canonical ingredient/profile groups now use explicit egg, dairy, soy, peanut, wheat, sesame, fish, crustacean and tree-nut aliases.
- Regression tests: soy protein is not egg; egg protein is egg; dairy profile matches whey; soy profile matches soy protein.

### ISSUE 5 — Shared food/drink thresholds

- Before: one per-100 threshold set was used for both `per100g` and `per100ml`.
- Fix: `PackagingRiskThresholds` contains separate food-per-100g and drink-per-100mL fields. Per-serving and unknown bases receive no quantitative high-content classification.
- Basis handling: carbohydrate remains distinct from sugar; ingredient sugar only creates added-sugar caution.
- Source/limitations: defaults intentionally retain the prior prototype numbers until product/domain validation; they are not medical or regulatory standards.

### ISSUE 6 — Broad condition matching

- Before: the sodium personalization list contained the single character `肾`.
- Fix: use only explicit phrases such as `高血压`, `需要控制钠摄入`, `低钠饮食`, with restrained non-diagnostic wording.
- Regression test: a profile containing `肾功能检查中` does not automatically personalize the sodium warning.

### ISSUE 7 — Cooldown on failed send

- Before: automatic capture updated its cooldown timestamp before DataChannel send success was known.
- Fix: `PackagingCaptureTriggerState` starts an in-flight attempt and records cooldown only in `complete(sent: true)`.
- Regression tests: failed send does not consume cooldown; successful send does.

### ISSUE 8 — Capture during active packaging analysis

- Before: route gate avoided duplicate pushes but the receiver could continue automatic requests while the first packaging page was active.
- Fix: the same lightweight trigger state tracks `analysisActive`; `RecognitionPageFast` sets it for the active route, automatic capture is suppressed, and manual packaging requests show a visible message.
- Regression test: active analysis suppresses automatic capture eligibility.

### ISSUE 9 — `usedAi` semantics

- Before: the packaging result set `usedAi=true` merely because cloud OCR was used, although no text LLM analyzed the result.
- Fix: replace it with `PackagingAnalysisSource`: `vivoOcrDeterministic` or `deterministicText`.
- Result: the packaging path is accurately described as vivo OCR plus deterministic parser/risk rules, without text-generation AI.

## 4. Changed Files

- `M README.md` — corrects runtime strategy and packaging-rule documentation.
- `M PACKAGING_OCR_IMPLEMENTATION_REPORT.md` — appends round-two correctness and verification corrections.
- `A PACKAGING_OCR_FIX_ROUND2_REPORT.md` — records this review, fixes and evidence.
- `M docs/packaging_ocr_test_plan.md` — records actual JPEG strategy and basis-separated rule checks.
- `M glasses-app/app/src/main/java/com/example/rv101cameraprobe/CameraCaptureController.kt` — uses the pure size selector at the Camera2 boundary.
- `A glasses-app/app/src/main/java/com/example/rv101cameraprobe/CameraOutputSizeSelector.kt` — provides testable closest-supported-size selection.
- `A glasses-app/app/src/test/java/com/example/rv101cameraprobe/CameraOutputSizeSelectorTest.kt` — verifies high-resolution target and absent-target behavior.
- `M phone-app/lib/packaging_models.dart` — adds food-route policy, nutrition section provenance and analysis source semantics.
- `M phone-app/lib/recognition_page_fast.dart` — isolates package ownership from food selection and coordinates active analysis.
- `M phone-app/lib/services/glass_receiver_service.dart` — catches send failure and uses the automatic trigger state.
- `M phone-app/lib/services/nutrition_facts_parser.dart` — extracts nutrition sections before parsing.
- `M phone-app/lib/services/packaging_analysis_service.dart` — records OCR/deterministic provenance instead of `usedAi`.
- `A phone-app/lib/services/packaging_capture_trigger_policy.dart` — owns cooldown, in-flight and analysis-active eligibility.
- `M phone-app/lib/services/packaging_risk_engine.dart` — canonicalizes allergens, separates thresholds and narrows conditions.
- `M phone-app/test/capture_type_test.dart` — covers food/package route eligibility.
- `M phone-app/test/nutrition_facts_parser_test.dart` — covers nutrition-section adversarial cases.
- `M phone-app/test/packaging_analysis_service_test.dart` — covers corrected analysis source semantics.
- `A phone-app/test/packaging_capture_trigger_policy_test.dart` — covers cooldown and active-analysis suppression.
- `M phone-app/test/packaging_risk_engine_test.dart` — covers aliases, basis thresholds and conservative conditions.

## 5. Test Results

Command:

```text
D:\flutter\bin\cache\dart-sdk\bin\dart.exe D:\flutter\bin\cache\flutter_tools.snapshot test
```

Result: PASS, `34` tests passed, including the explicit `perServing` high-content boundary regression.

Command:

```text
D:\flutter\bin\cache\dart-sdk\bin\dart.exe D:\flutter\bin\cache\flutter_tools.snapshot analyze --no-fatal-infos --no-fatal-warnings
```

Result: PASS, exit code `0`; 71 existing Flutter API deprecation infos.

Command:

```text
gradlew.bat --offline --no-daemon :app:compileDebugKotlin :app:compileDebugUnitTestKotlin --console=plain
```

Result: PASS; main and unit-test Kotlin sources compiled.

Command:

```text
gradlew.bat --no-daemon :app:testDebugUnitTest --console=plain
```

Result: PASS; Gradle resolved the previously missing AndroidX runtime artifacts and all four local JVM tests completed successfully.

## 6. Remaining Risks

Not verified in this environment:

- valid vivo OCR credentials and real provider response variants;
- RV101 capture/control protocol on hardware;
- actual selected 4032x3024 or 1920x1080 device outputs;
- preview fallback on hardware;
- reflective, curved, wrinkled, oblique or motion-blurred packaging;
- real OCR nutrition-table layout quality and latency.

The code is ready for those validation steps but does not claim their results.