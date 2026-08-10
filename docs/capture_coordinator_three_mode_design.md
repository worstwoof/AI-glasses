# 三模式采集链路与包装 OCR 设计

## 当前软件实现

系统保留三条独立数据流：Camera2/WebRTC 实时预览、约 1 FPS 的低分辨率手势帧，以及按需触发的高清 JPEG。高清任务统一经 `CaptureCoordinator` 调度，所有任务都带有 `captureTaskId`；DataChannel、眼镜 `GlassesCaptureRequest`、上传 metadata 和手机 ACK 都保留该字段。

`CaptureCoordinator` 负责单一 in-flight、优先级、延迟、自动任务冷却、取消、真实上传 ACK、质量结果和有界重拍。`EatingSessionController` 仅维护 `IDLE/STARTING/EATING/ENDING`：餐前和餐后均在精确匹配的真实 ACK 后才推进状态；未知手势和无手不会结束进食；FIST 会先取消同一 Session 的自动任务。

手动食品、手动包装、OK 包装、餐前/餐后和重拍均通过 Coordinator。包装仍与 Food VLM、`MealRecord` 隔离；OCR 结果可编辑、重算风险，并在用户确认后保存独立的 `PackagingScanRecord`。

实时预览页显示：

- 采集模式分段控制：手动、自动、混合；
- 食品模型可用性；
- 当前 Eating Session、餐前/餐中/餐后数量；
- 当前 Coordinator 任务、任务 ID、状态和队列长度；
- 非 IDLE 时的取消当前进食采集命令。

## 食品分类器状态

仓库审计仅发现 `phone-app/android/app/src/main/assets/hand_landmarker.task`，这是 MediaPipe 手势模型，不是食品二分类 TFLite。不存在可验证的 `food_scene/not_food_scene` 模型、输入 shape、归一化、标签或阈值。

因此 `FoodSceneClassifier` 仅提供接口和 `UnavailableFoodSceneClassifier` 安全降级。默认模式为手动；自动和混合的自动部分在 UI 中禁用，并显示“食品场景模型未加载，自动采集不可用。”。绝不使用手势输出代替食品分类结果。

`AutoCandidateTracker` 已具备稳定帧、置信度阈值、冷却和指纹去重策略；在接入真实食品模型前不会提交任何自动食物抓拍。

## 待硬件验证

下列能力均为软件实现或接口状态，不代表设备验证成功：WebRTC、低清手势帧、OPEN_PALM/FIST、高清上传 ACK、质量过滤、包装 OCR、取消流程，以及未来食品模型的自动餐前/餐中采集。

接入食品模型时必须补充模型路径、输入输出 shape、RGB/BGR、归一化、标签、food index、推荐阈值、端侧延迟和推理测试；之后再启用自动/混合的自动抓拍与真机联调。
