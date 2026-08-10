# CaptureCoordinator + 三模式采集第四轮实施报告

## 1. Executive Summary

本轮建立了统一的高清抓拍调度、`captureTaskId` 协议闭环、三模式框架、质量控制、取消与有界重拍，并完成包装识别的编辑确认保存闭环。当前状态为 `READY_FOR_FOOD_MODEL_INTEGRATION`：食品二分类模型未提供，自动和混合的自动部分被安全禁用。

## 2. Starting State

起点提交为 `ac0eada fix: complete eating session failure diagnostics`，分支为 `codex/organize-aiglasses-monorepo`。原系统已有独立 WebRTC 预览、低清手势帧、高清上传 ACK、Eating Session、包装 OCR、营养解析和风险引擎。

## 3. Preserved Better-than-Design Behaviors

- `EATING` 为锁存状态，`UNKNOWN`、无手、OK 和 OPEN_PALM 不会结束会话。
- OPEN_PALM/FIST 均需连续确认，且抓拍延迟由 Coordinator 管理。
- DataChannel 写入成功不代表抓拍成功；只有真实上传 ACK 才推进会话。
- ACK 必须匹配 `captureTaskId`、类型、scene 和 `mealSessionId`。
- 餐前失败不会进入伪造的 `EATING`；餐后失败保持原 Session。
- Packaging 不进入 Food VLM，也不自动写入 `MealRecord`。

## 4. Food Classifier Availability

**NOT FOUND。** 审计仅发现 `phone-app/android/app/src/main/assets/hand_landmarker.task`，它是手势模型。未发现食品 `food_scene/not_food_scene` TFLite，也没有可验证的输入 shape、RGB/BGR、归一化、标签、输出 tensor、food index、阈值或推理延迟。

实现只提供 `FoodSceneClassifier` 接口与 `UnavailableFoodSceneClassifier`，不会把 MediaPipe 手势分类伪装成食品分类。

## 5. CaptureCoordinator Architecture

`CaptureCoordinator` 是高清物理拍照的唯一入口，持有队列、优先级、统一延迟、单一 in-flight、ACK timeout、质量结果、取消和重拍。Eating Session FSM、OCR、风险规则和食品分类器不被塞入该类。

## 6. CaptureIntent / Task ID

`CaptureIntent` 以 task ID、capture type、scene、trigger、session、source、priority、delay、cooldown、quality policy 和 retry policy 描述一次高清任务。`captureTaskId` 经 Flutter DataChannel、眼镜 `GlassesCaptureRequest`、tracker、上传 metadata 和手机 `GlassCapture` ACK 往返；旧命令缺失 task ID 时仍可解析，但不能确认新任务。

## 7. Priority

使用 `critical`、`explicitUser`、`mealControl`、`automatic` 枚举，不使用散落整数。自动任务处于延迟阶段时，较高优先级的餐后或显式操作会取消它；同一时间仅允许一个高清任务等待 ACK。

## 8. Manual Mode

默认模式为手动，允许 App 食物/包装抓拍、OK 包装、OPEN_PALM 餐前和 FIST 餐后。所有入口进入 Coordinator。

## 9. Automatic Mode

自动模式的控制器、状态接口和 UI 已实现，但模型不可用时不可选择。没有食物模型就不会生成自动任务。

## 10. Hybrid Mode

混合模式的显式输入仍由手动路径支持；其自动部分在模型缺失时禁用。FIST 会取消同 Session 的自动任务，避免自动餐中抓拍妨碍餐后抓拍。

## 11. Auto Candidate Logic

`AutoCandidateTracker` 集中使用置信度阈值 `0.80`、稳定帧 `2`、自动冷却 `8s`、最新候选和指纹。低置信度、不稳定、not-food、冷却期和重复候选不会变成自动任务。由于缺少真实模型，这一逻辑尚未接收生产食品推理输出。

## 12. meal_before

两次 OPEN_PALM 后进入 `STARTING` 并提交有延迟的 `meal_before`。只有质量通过且 ACK 精确匹配后才进入 `EATING`；失败回到 IDLE。

## 13. meal_during

Coordinator、质量策略、去重和快照列表支持 `meal_during`。手机仅在精确 ACK 且质量通过后记录餐中图片；新 Session 开始时清空列表。自动触发本身因食品模型缺失不可用。

## 14. meal_after

两次 FIST 后进入 `ENDING`，自动任务先被取消，再提交延迟的 `meal_after`。质量策略对餐后不要求 food relevance，精确 ACK 后完成 Session；失败保留 `EATING`。

## 15. Quality Evaluation

`CaptureQualityEvaluator` 覆盖 JPEG 有效性、分辨率、亮度、局部对比度作为模糊代理、自动图片重复和 scene-specific food relevance。真实 JPEG 使用解码后的 RGBA 亮度/局部差异，不伪造食品相关性；无模型时不产生自动 food intent。

## 16. Duplicate Filtering

自动食品图使用抽样指纹预检；仅已接受的自动食品图更新最近指纹。重复的自动 `meal_during` 质量失败后直接丢弃且不重拍。

## 17. Retake

餐前、餐后和包装允许最多两次质量重拍；每次重拍生成新 task ID，旧 ACK 不会确认新任务。自动任务质量失败只丢弃，不进行无限重试。

## 18. Cancel

`EatingSessionController.cancel()` 取消该 Session 的 queued、delay 和 waiting-ACK 任务，清理 Session 状态。Coordinator 对取消任务的迟到 ACK 返回 false。实时页在非 IDLE 时提供“取消当前进食采集”。

## 19. Packaging Integration

OK 手势和 App 包装按钮通过 `requestPackagingCapture()` 进入 Coordinator；OK 路径带 2 秒稳定延迟。现有包装分析激活抑制、冷却和路由保护保留。

## 20. Packaging Confirmation/Storage

`PackagingAnalysisPage` 支持编辑配料和营养值、重新计算风险、重新 OCR、确认保存和取消。确认后保存独立 `PackagingScanRecord` 到 `local_packaging_scans`，不会写 MealRecord。

## 21. Regression Safety

会话测试覆盖 ACK 精确匹配、UNKNOWN 锁存、同 Session ID、失败恢复和取消。Coordinator 测试覆盖 single in-flight、优先级、冷却、timeout、重拍、新 task ID 和迟到 ACK；包装、营养和风险历史测试均保留。

## 22. Tests Run

| Command | Result | Evidence |
| --- | --- | --- |
| `flutter test` | PASS | 56 tests passed |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | PASS | 0 error；74 个弃用 info |
| `flutter test test/glass_receiver_capture_mode_snapshot_test.dart test/eating_session_debug_card_test.dart` | PASS | 2 tests passed |
| `phone-app/android/gradlew.bat testDebugUnitTest` | BLOCKED | Flutter plugin 的 D: build 与 C: Pub Cache 跨根相对路径错误 |
| `glasses-app/gradlew.bat :app:testDebugUnitTest :app:assembleDebug` | BLOCKED | 缺少眼镜工程 Android SDK 配置 |

## 23. Phone APK Status

`flutter build apk --debug` 于本轮成功，Gradle `assembleDebug` 用时约 165 秒。产物为 `phone-app/build/app/outputs/flutter-apk/app-debug.apk`。

## 24. Hardware Status

**NOT VERIFIED ON HARDWARE。** 本轮未连接 RV101 或手机进行任何真机流程。不能从单元测试、静态检查或 APK 构建推断 WebRTC、手势、上传、OCR、质量过滤或自动采集在设备上成功。

## 25. Remaining Risks

- external model dependency: 提供并验证食品二分类 TFLite 后才可启用自动/混合自动部分。
- hardware validation: 需要 RV101 和手机端验证所有 DataChannel、上传 ACK、手势、质量和包装流程。
- P1 environment: phone native JUnit 仍受 D:/C: Flutter plugin build-path 限制；眼镜工程需要有效的 `local.properties` 或 `ANDROID_HOME`。
- future work: 真实食品模型接入后补端侧推理、auto meal_before 和 meal_during 集成测试。

# FOURTH ROUND VERIFICATION CHECKLIST

## A. Git

- Branch: `codex/organize-aiglasses-monorepo`
- Starting HEAD: `ac0eada`
- Sync action: `git fetch origin --prune`
- Unrelated line-ending changes: 29 个 Flutter 文件保持未暂存，不纳入本轮提交。

## B. Preserved Existing Behaviors

- [PASS] WebRTC 和低清手势流未被本轮逻辑停止。
- [PASS] latched EATING、UNKNOWN 不结束、餐前/餐后真实 ACK、wrong scene/session 忽略均有 Flutter 测试覆盖。
- [PASS] Packaging 与 Food VLM/MealRecord 隔离；无自动 MealRecord。

## C. Food Scene Classifier

- [NOT FOUND] TFLite food model；仅有 `hand_landmarker.task`。
- [PASS] 自动与混合自动 UI 安全禁用。
- [PASS] 没有伪造 classifier。
- Automatic mode actually available: NO。

## D. CaptureCoordinator

- [PASS] single high-res entry、CaptureIntent、task ID、queue、priority、delay、cooldown、in-flight、cancel、timeout、retry、late ACK protection。

## E. Protocol

- [PASS] `captureTaskId` phone -> glasses -> uploader -> GlassCapture ACK。
- [PASS] 旧缺失 task ID 命令安全解析；不能错误确认新任务。

## F. Capture Modes

- Manual: [PASS] App、OPEN_PALM、FIST、OK 包装均保留。
- Automatic: [UNAVAILABLE] 模型缺失时不可选择。
- Hybrid: [UNAVAILABLE] 自动部分不可用；[PASS] 显式任务优先且 FIST 取消自动任务。

## G. Auto Candidate Policy

- Confidence threshold: `0.80`; Stable frames: `2`; Auto cooldown: `8s`。
- [PASS] 低置信度、不稳定、not-food、冷却和重复前置检查的单元测试。

## H. Eating Session

- [PASS] 手动 before/after、before ACK、餐中列表、FIST 优先、same session ID。
- [UNAVAILABLE] 自动 meal_before/meal_during，原因是无真实食品模型。

## I. Quality Evaluation

- [PASS] JPEG、分辨率、亮度、blur proxy、duplicate、餐后不要求 food scene。
- [UNAVAILABLE] 自动任务的真实 food relevance 推理。

## J. Retake and K. Cancel

- [PASS] 最多两次重拍、新 task ID、迟到旧 ACK 忽略、无无限循环。
- [PASS] STARTING/EATING/ENDING 取消与自动 pending 任务取消。

## L. Packaging

- [PASS] OK 经 Coordinator 和 2 秒 settle delay。
- [PASS] OCR、营养解析、风险引擎、编辑重算、明确确认、PackagingScanRecord、无 MealRecord。
- provider OCR confidence available: NO; fake confidence added: NO。

## M. UI

- [PASS] 手动、自动、混合可见；无模型状态明确；非空自动项禁用。
- [PASS] Eating state、before/during/after count、取消和 Coordinator debug state。

## N. Automated Tests / O. Flutter Phone Build / P. Glasses Build

- [PASS] Flutter test: 56。
- [PASS] Flutter analyze: 0 error。
- [PASS] Flutter debug APK。
- [BLOCKED] Phone native JUnit: cross-root path。
- [BLOCKED] Glasses Kotlin/JUnit/assemble: Android SDK missing。

## Q. Hardware Status

- [NOT TESTED] WebRTC、低清帧、OPEN_PALM、FIST、manual before/after、食品模型、auto before、meal_during、质量/重复过滤、Packaging OCR。

## R. Changed Files

- A `phone-app/lib/services/capture_intent.dart`, `capture_coordinator.dart`, `capture_mode_controller.dart`, `food_scene_classifier.dart`, `auto_candidate_tracker.dart`, `capture_quality_evaluator.dart`: 调度、模式、自动候选和质量基础设施。
- M `phone-app/lib/services/eating_session_controller.dart`, `glass_receiver_service.dart`, `glass_capture_extensions.dart`: ACK、任务调度、会话与上传闭环。
- M `phone-app/lib/recognition_page_fast.dart`, `phone-app/lib/services/eating_session_debug_card.dart`: 模式、取消、进食和 Coordinator 状态。
- M `phone-app/lib/packaging_analysis_page.dart`, `packaging_models.dart`, `services/packaging_analysis_service.dart`, `services/local_storage_service.dart`: 包装编辑确认保存。
- M `glasses-app/app/src/main/java/com/example/rv101cameraprobe/{CaptureRequest,CaptureService,PhotoUploader,WebRtcPreviewPublisher}.kt`: captureTaskId 协议传播。
- A/M `phone-app/test/*`、`glasses-app/app/src/test/*`: Coordinator、模式、质量、协议、包装和回归测试。
- A `docs/capture_coordinator_three_mode_design.md` 与本报告：当前实现和验证状态。

## S. Still Missing

- P0 software blocker: 无。
- external model dependency: 食品场景 TFLite。
- P1 improvement: 解决 phone native JUnit 的跨盘插件构建目录。
- hardware validation: 所有 RV101/手机端流程。
- future work: 食品模型端侧推理与自动采集集成。

## T. Design Document Consistency

- [PASS] `docs/capture_coordinator_three_mode_design.md` 区分当前实现和待真机验证。
- [PASS] 未把软件实现写成硬件验证。
- [PASS] 未把自动模式描述为可用。

## U. Final Status

**READY_FOR_FOOD_MODEL_INTEGRATION**

1. 第三轮的锁存 EATING、真实 ACK 和严格匹配均保留。
2. 统一 CaptureCoordinator 已建立，显式、会话和包装入口均已接入。
3. `captureTaskId` 已贯穿手机、眼镜和 ACK。
4. 手动模式可用；自动/混合自动因无食品模型安全禁用。
5. `meal_during`、优先级、冷却、质量、重复、重拍和取消均完成软件实现。
6. 包装 edit/recalculate/confirm/save 已完成且不写 MealRecord。
7. Flutter 56 项测试、分析和 debug APK 构建通过。
8. phone native JUnit 与眼镜 Gradle 分别被跨盘路径、SDK 配置阻断。
9. 全部硬件项仍为 NOT VERIFIED ON HARDWARE。
10. 下一步是提供真实食品模型并接入，然后进行真机验证。
