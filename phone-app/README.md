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

App 启动后会自动启动手机端接收服务，默认监听 `8080` 端口。食物存在度接口不需要额外启动 Python 服务。

## 已新增能力

- 支持浅色模式，默认使用浅色模式
- 个人档案页可以切换浅色 / 深色
- 中间相机按钮支持拍照和从相册选图
- 识别页支持调用 AI 视觉接口分析餐食
- 识别页支持 RV101 局域网 WebRTC 实时预览
- 可接收 RV101 上传的高清 JPEG 抓拍，并继续走原 AI 识图与饮食记录写回流程
- 手机 APK 内置 MediaPipe Hand Landmarker，使用眼镜低频预览帧做粗场景分类
- 手机 APK 内置 MobileNetV3-Small 食物存在度模型，使用眼镜低频预览帧返回 `foodProbability`

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

## 手机端低频图像接口

眼镜会把约每秒一帧的低清 JPEG 发送到手机：

```text
POST http://<手机IP>:8080/api/v1/scene/frames
X-Device-Token: <配对令牌>
```

手机 App 在 Android 原生层运行本地 MobileNetV3-Small 模型，直接返回图片中存在食物的概率。
旧版 MediaPipe Hand Landmarker 手势分类实现仍保留在 Android 通道中，供兼容旧页面状态使用，
但不再由这个低频图片接口调用。高清 JPEG 仍由手机端“眼镜抓拍”按钮触发，后续再接入配料表 OCR 或餐食 AI 分析。

## 手机端食物存在度识别

`POST /api/v1/scene/frames` 接收眼镜端的单张 JPEG 后，手机端 Android 原生模型返回：

```json
{
  "accepted": true,
  "status": "classified",
  "foodProbability": 0.91
}
```

模型输入为保持宽高比缩放并 padding 到 `224x224` 的 RGB 图片。模型文件为
`android/app/src/main/assets/food_presence.tflite`，输出顺序实际为
`[healthy, not_food, unhealthy]`，因此 `foodProbability` 等于第 0 和第 2 项之和。
模型来源、SHA-256 和许可证记录在 `FOOD_PRESENCE_MODEL.md`。

可用电脑上的 `curl.exe` 直接联调：

```powershell
$phoneIp = '手机局域网 IP'
$token = 'CsF8V6pEOWqlfcktClawh60N'
$image = 'C:\path\to\food.jpg'
curl.exe -X POST "http://${phoneIp}:8080/api/v1/scene/frames" `
  -H "X-Device-Token: $token" `
  -F "image=@$image;type=image/jpeg"
```

成功响应中的 `foodProbability` 是 `0.0` 到 `1.0` 的食物存在度。

## AI 识图配置

当前代码支持通过 `--dart-define` 配置一个 OpenAI 兼容的视觉接口：

```bash
flutter run --dart-define=AI_API_KEY=你的Key
```

可选参数：

```bash
flutter run ^
  --dart-define=AI_API_KEY=你的Key ^
  --dart-define=AI_API_URL=https://你的接口地址/v1/chat/completions ^
  --dart-define=AI_VISION_MODEL=Doubao-Seed-2.0-mini
```

如果不额外传 `AI_VISION_MODEL`，拍照识别默认会使用 `Doubao-Seed-2.0-mini`。

如果没有配置 `AI_API_KEY`，应用会自动退回到本地演示识别模式。
