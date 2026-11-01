# 食品场景模型接入说明

手机端内置 `food_presence.tflite`，只用于低频场景帧的本地食品存在性判断，不处理高清图片，也不调用千问。

模型来源：<https://huggingface.co/maia2000/mobilenet-food-binary/resolve/main/tflite_int8_io_float.tflite>

## 输入输出约定

- 输入：`FLOAT32 [1, 224, 224, 3]`，RGB，像素范围 `0..255`。
- 输出：`FLOAT32 [1, 3]`，类别顺序为 `[healthy, unhealthy, not_food]`。
- 手机端食品概率：`output[0] + output[1]`；`output[2]` 是非食品概率。
- `foodProbability >= 0.80` 判定为 `food_scene`，否则为 `not_food_scene`。
- 连续两个低频帧达到阈值，且距离上次自动拍摄至少 8 秒，才允许自动生成餐前拍摄任务。

模型文件大小为 1,219,312 bytes，SHA-256：
`F6141ED56F78CE3B5EDA6EC8D1726E877D885D46453305B44DE36FC6182A6D55`。

该模型来自 Food-101 衍生数据，尚未针对 RV101 的第一视角画面做专门评估。因此它是手机端的粗筛器，不能直接作为菜品识别、营养分析或餐后剩余量估计结果。后续应使用眼镜实拍图片建立验证集，再调整阈值或替换模型。

模型的 Android 推理入口是 `FoodPresenceClassifier.kt`，Flutter 通过 `foodModelStatus` 和
`predictFoodProbability` MethodChannel 调用。当前华为真机使用关闭 XNNPACK 的 CPU runtime，
避免部分设备在模型节点准备阶段出现 `failed to create XNNPACK runtime`。
模型加载失败时只关闭自动食品采集，手势识别和手动拍摄仍可用。
