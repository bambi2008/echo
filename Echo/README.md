# Echo iOS App

## 在 Xcode 中打开

双击 `Echo.xcodeproj`，等待 Xcode 顶部状态完成后，选择 `Echo` 和一个 iPhone 模拟器，再点击左上角的三角形运行按钮。

也可以在项目根目录执行：

```sh
open Echo/Echo.xcodeproj
```

## AI 在哪里

App 启动并完成三页引导后，底部第二个 **Echo AI** 就是 AI 入口。第一次使用前，在底部 **Settings** 中填写 DeepSeek API Key；快速模型和高级模型都可以直接输入任意模型 ID，修改后无需重新发布 App。

Echo AI 当前提供：

- 针对重点联系人的开场白建议
- 单个联系人的关系洞察与关系健康分析
- 根据联系人优先级生成每日人脉简报
- 结合 Pipeline、互动记录和备注生成销售跟进建议
- 通过系统相册选择名片或保单图片，在设备端使用 Apple Vision 识别文字，再由 DeepSeek 整理为结构化字段

## 工程说明

- iOS 17+
- SwiftUI + SwiftData
- 本地依赖根目录中的 `EchoAI` Swift Package
- 联系人、互动记录、备注与交易管道保存在设备端
- 名片与保单图片本身不上传；图片文字识别在设备端完成
