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

- 在联系人详情中选择短信或邮件时，针对这个人生成可编辑的开场白
- 关系洞察按机会价值、重点关系、商务关系或上下文充分度筛选前 5/10 人
- 关系健康按个人历史联系节奏的异常程度、长期未联系、互动偏少或健康活跃筛选前 5/10 人
- 根据联系人优先级生成每日人脉简报
- 结合 Pipeline、互动记录和备注生成销售跟进建议
- 从 People 首页的新增菜单识别名片并添加联系人；从 Echo AI 识别保单字段
- 图片先在设备端使用 Apple Vision 识别文字，再由 DeepSeek 整理为结构化字段
- 在 Settings 连接 Gmail，仅同步发件人、收件人、主题和时间，并把匹配到现有联系人的邮件写入互动记录
- Gmail 首次检查最近 200 封邮件，之后使用 Gmail History 增量同步；App 启动时最多每 15 分钟自动检查一次
- People 支持按姓名、公司、邮箱或电话搜索；通讯录重复导入会更新已有联系人，不重复创建
- Gmail 邮件在联系人时间线中标记收件/发件方向，并进入关系洞察、健康分析、每日简报和联系建议上下文

## 工程说明

- iOS 17+
- SwiftUI + SwiftData
- 本地依赖根目录中的 `EchoAI` Swift Package
- 联系人、互动记录、备注与交易管道保存在设备端
- 名片与保单图片本身不上传；图片文字识别在设备端完成
- Gmail OAuth Token 保存在 Apple Keychain；Echo 不下载邮件正文和附件
- Outlook 同步需要单独的 Microsoft Entra 应用 Client ID，尚未绑定任何虚构或共享凭据
