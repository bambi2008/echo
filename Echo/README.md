# Echo iOS

Echo 是一款本地优先的关系反思 App。默认体验围绕四周关系梳理，而不是联系人排名、销售漏斗或 AI 功能陈列。

## 在 Xcode 运行

打开 `Echo/Echo.xcodeproj`，选择 `Echo` scheme 和 iPhone 模拟器后运行。工程要求 iOS 17+，使用 SwiftUI、SwiftData，并引用仓库根目录的本地 `EchoAI` Swift Package。

## 当前完整流程

- 第一屏用“有些人不是突然离开的”引导用户停下来想一想。
- 从系统联系人中只选择 1–10 人，或手动新建；不会强制整本通讯录权限。
- 为每个人选择更靠近、保持、轻松保留、给些空间或暂时不知道。
- 可键盘或语音记录一句本地关系背景。
- 计划一件小行动，或明确选择本周不行动。
- 在 Echo 首页恢复四周旅程、处理行动并记录结果。
- 在 Relationships 查看全部联系人及“还没想清楚”分组，可按电话/邮箱筛选、导入 VCF、扫描名片、搜索和修改关系。
- 在 Insights 查看完全由本地记录生成、带原因说明的模式。

## 设置与兼容能力

- 周提醒、行动提醒和行动后回顾提醒都由本地通知完成，且只在用户主动开启相应开关后生效。
- 完整 iPhone 通讯录导入是 Settings 中的可选操作。
- DeepSeek API Key 为可选增强能力，保存在 Keychain；Settings 只显示 `Configured` 等状态，并可执行最小连接测试。
- 快速模型与高级模型 ID 可随时修改，模型路由不依赖重新发布。
- Pipeline 已升级为关系中心的 Agentic Pipeline：支持多个流程、组织与多人、Human Attention、AI 洞察、证据和可审计行动；入口仍保留在 Business tools，需人工关注时首页会直接出现提醒。
- Pipeline 阶段可以新增、改名与排序；已使用阶段和 Won/Lost 终点受到数据保护。
- Pipeline 可调用 DeepSeek 生成结构化洞察和邮件草稿，也可读取组织官网形成带来源的证据。
- Gmail 连接、联系人导入、邮件历史同步和人工确认发送位于 Settings；旧连接需要重新授权一次邮件发送权限。
- 旧联系人、笔记、Interaction（包括历史 Gmail Interaction）、VCF 导入、电话、邮件、社交跳转和模糊语音找人能力均保留并有可达入口。
- 支持接收 Kip 的联系人提醒：按姓名匹配联系人，展示原提醒背景，进入电话、短信或邮件，并可返回 Kip 将事项标记完成。

## 明确的隐私边界

- 生产启动不创建演示联系人，也不自动同步 Gmail。
- Gmail 不会自动连接、自动同步或自动发送；任何外发邮件都必须先预览并再次确认。
- 选择式联系人导入不读取系统联系人 Note。
- 核心反思、关系地图与 Insights 无网络、无 API Key 仍可使用。
- 联系某人时先生成设备端草稿；只有用户看过上下文说明并主动点击 AI 按钮后，才会调用 DeepSeek。
- 用户数据默认保存在设备端；关系背景不会写回系统通讯录。
- Kip 与 Echo 之间使用经校验的本机跳转参数，不会互相读取或合并对方的本地数据库。

更完整的产品行为见仓库根目录 `product-spec.md`。

Agentic Pipeline 的模型、迁移和扩展边界见 [`docs/agentic-pipeline.md`](../docs/agentic-pipeline.md)。

提交 TestFlight 前请逐项完成 [`docs/release-checklist.md`](../docs/release-checklist.md)。
