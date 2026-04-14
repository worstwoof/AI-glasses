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

1. 用 Android Studio 打开当前目录 `D:\program\AI-glasses`
2. 等待 Gradle 和 Flutter 索引完成
3. 执行 `flutter pub get`
4. 连接 Android 模拟器或真机后运行

## 已新增能力

- 支持浅色模式，默认使用浅色模式
- 个人档案页可以切换浅色 / 深色
- 中间相机按钮支持拍照和从相册选图
- 识别页支持调用 AI 视觉接口分析餐食

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
  --dart-define=AI_VISION_MODEL=你的视觉模型名
```

如果没有配置 `AI_API_KEY`，应用会自动退回到本地演示识别模式。
