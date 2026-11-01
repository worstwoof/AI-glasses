# AI Glasses Nutrition App

一个使用 Flutter 构建的 Android 原型应用，用于模拟：

- 连接 AI 眼镜
- 拍摄餐食
- 自动识别菜品和营养成分
- 汇总每日热量与三大营养素
- 结合用户档案给出饮食建议

## 当前版本

这个版本是可运行的 UI 原型，已经包含完整的产品闭环与演示数据：

- 首页
- 日历
- 健康分析
- 档案
- 中间识别入口

## 打开方式

1. 用 Android Studio 打开当前目录 `D:\大创\AI-glasses`
2. 等待 Gradle 和 Flutter 索引完成
3. 执行 `flutter pub get`
4. 连接 Android 模拟器或真机后运行

## 已新增能力

- 支持浅色模式，默认使用浅色模式
- 个人档案页可以切换浅色 / 深色
- 中间相机按钮支持拍照和从相册选图
- 识别页支持调用 AI 视觉接口分析餐食
- 识别页支持 RV101 局域网 WebRTC 实时预览
- 可接收 RV101 上传的高清 JPEG 抓拍，并继续走原 AI 识图与饮食记录写回流程
- 手机 APK 内置 MediaPipe Hand Landmarker，使用眼镜低频预览帧做粗场景分类

## RV101 实时预览

手机和 RV101 眼镜需要在同一 Wi-Fi 或手机热点下。打开 App 中间“识别”入口后，切到“实时预览”，页面会显示：

- 上传地址：`http://<手机IP>:8080/api/v1/captures`
- 信令地址：`http://<手机IP>:8080/api/v1/webrtc/offer`
- 配对令牌：写入眼镜端的 `X-Device-Token`

当前版本已支持手机端直接连接眼镜：

1. 手机和眼镜加入同一 Wi-Fi，或打开手机热点并让眼镜连接该热点。
2. 确认眼镜端 `RV101 Camera Probe` 已经运行过一次，进入待机或采集状态。
3. 打开手机 App，进入中间“识别”入口，停留在“实时预览”页。
4. 页面会自动搜索 RV101；也可以点“连接眼镜”立即重试。
5. 连接成功后应看到“视频已连接”“局域网路径已连通”“控制 可抓拍”。

眼镜端会监听 `8088` 控制端口，手机端会把上传地址和配对令牌发给眼镜，眼镜再自动推导 WebRTC 信令地址。正常使用不需要每次通过电脑 ADB 启动。

限制：RV101 当前固件会拦截第三方 App 的冷启动广播。眼镜完整重启、系统杀掉采集进程、或刚安装后，仍需要先在眼镜端打开一次 `RV101 Camera Probe`，之后手机 App 才能直接连接并启动预览。

实时预览只做局域网连接，不配置 TURN/STUN。眼镜端不再运行水果识别或手势模型，只负责 Camera2、WebRTC、低频分类帧和高清 JPEG 抓拍。

## 手机端粗场景分类

眼镜会把约每秒一帧的低清 JPEG 发送到手机：

```text
POST http://<手机IP>:8080/api/v1/scene/frames
X-Device-Token: <配对令牌>
```

手机 App 在 Android 原生层运行 MediaPipe 手势识别和内置 TFLite 食品二分类。两者使用同一张低频 JPEG；食品概率达到 `0.80` 且连续两帧命中后，才允许自动生成餐前抓拍任务：

- OK 手势：`ingredient_label`，进入“配料表识别模式”准备状态。
- 张开手掌：手动或混合模式下连续两次命中，提交 `meal_before`。
- 握拳：连续两次命中，提交 `meal_after`；如果自动餐后候选已经生成，则直接确认候选，不重复拍摄。
- 食品概率 `>= 0.80`：`food_scene`，自动或混合模式下可开始餐前采集。
- 其他画面：`not_food_scene`，自动餐前触发计数清零。

采集模式有三种：手动模式只由手势和 App 按钮触发；自动模式由食品二分类启动餐前采集，并在进餐至少 3 分钟、连续无手且画面稳定时生成 `meal_after_candidate`；混合模式同时启用两条链路，明确手势优先。第一版不自动拍摄 `meal_during`。自动餐后候选需要用户握拳或点击“确认餐后”才会提升为正式 `meal_after`，也可以点击“继续进食”取消。

包装 OCR 始终显式触发：OK 手势或 App 包装抓拍按钮 -> `ingredient_label` 高清图片 -> 千问视觉 OCR -> 本地营养成分解析和过敏风险判断。食品二分类不会触发包装 OCR。

模型输入输出约定和局限见 [FOOD_PRESENCE_MODEL.md](FOOD_PRESENCE_MODEL.md)。

## 千问 AI 配置

食品识别、营养分析和包装 OCR 默认使用阿里云百炼的 `qwen3.8-flash`。API Key 只通过本机环境变量传入，不要写入源码或提交到 GitHub。

PowerShell 构建示例：

```powershell
$env:QWEN_API_KEY = "新创建的API Key"
$env:QWEN_API_URL = "https://ws-xx2967i3d388t86v.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions"

D:\flutter\bin\flutter.bat build apk --debug `
  --dart-define="AI_API_KEY=$env:QWEN_API_KEY" `
  --dart-define="AI_API_URL=$env:QWEN_API_URL" `
  --dart-define="AI_VISION_MODEL=qwen3.8-flash" `
  --dart-define="AI_TEXT_MODEL=qwen3.8-flash" `
  --dart-define="AI_OCR_MODEL=qwen3.8-flash"
```

也可以使用 `flutter run`，参数保持一致。未配置 `AI_API_KEY` 时，食品识别会退回本地演示数据，包装 OCR 会提示缺少 API Key。

当前包装 OCR 直接把图片发送给千问视觉接口，返回的文字会继续进入本地营养成分解析、过敏原识别和风险评估流程。

“健康分析”页现在是千问饮食顾问对话页。它会在每次提问前自动整理个人档案、今日饮食汇总、近 14 天饮食记录和最近一次识别结果，发送给千问生成解释与建议；对话只读，不会自动修改饮食记录。对话记录最多保留 50 条，单次请求只发送最近 12 条历史消息。未配置 API Key 或请求失败时，页面会显示明确错误，不生成虚假的个性化分析。

正式发布时应改为由后端代理调用千问，避免 API Key 被打包进 APK 后泄露。

## Eating Session Hardware Validation

Use adb devices and select explicit serials for the Android phone and RV101. Run the Flutter app on the phone, open Recognition -> Live Preview, and inspect Flutter plus com.aiglasses.nutrition logs. Open glasses-app in Android Studio, select the RV101 device, run/debug, and inspect the rv101_capture Logcat tag. The live WebRTC preview and approximately 1 FPS scene frames must continue during both still captures. The complete matrix is in ../docs/eating_session_hardware_test_plan.md.
