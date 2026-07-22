# Echo — 完整产品规格

> 念念不忘，必有回响。
> A whisper across time always finds its way back.

---

## 1. 产品身份

| | |
|---|---|
| **名称** | Echo |
| **App Store** | `Echo: Stay in Touch` |
| **定位** | 三模 AI 关系工具 |
| **平台** | iOS Native (SwiftUI) |
| **AI 引擎** | DeepSeek 多模态（文字+图像）+ 火山引擎（语音） |
| **隐私架构** | 本地优先 → 基础功能全本地。AI Pro/B2B Pro 发送最小脱敏数据到云端 AI |
| **市场** | US / EU |

---

## 2. 三模架构

```
┌─────────────────────────────────────────┐
│                 Echo                     │
│  ┌──────────┬──────────┬──────────────┐ │
│  │ Personal │  AI Pro  │   Business   │ │
│  │  $0      │  $4/月   │   $15/月     │ │
│  └──────────┴──────────┴──────────────┘ │
│         │        │           │           │
│    纯本地    本地+云端AI   本地+云端AI    │
│    零AI     DeepSeek     DeepSeek       │
│              +火山引擎    +火山引擎       │
│                          +Kanban管线     │
└─────────────────────────────────────────┘
```

---

## 3. 定价与功能矩阵

完整功能对比见 `tier-comparison-zh.md`。核心差异：

| | Personal ($0) | AI Pro ($4/mo) | Business ($15/mo) |
|---|---|---|---|
| **分层模型** | 回响层（手动 30 人） | 回响层（AI 自动） | 优先联系人（热/温/冷） |
| **AI 引擎** | 无 | DeepSeek 文字 + 火山语音 | DeepSeek 文字+图像 + 火山语音 |
| **智能开场白** | — | ✅ NLP 生成 | ✅ 销售场景定制 |
| **拍照识别** | — | 名片 | 名片 + 保单 + 合同 |
| **语音** | — | ASR 备注 + TTS 简报 | ASR 转录 + AI 销售教练 |
| **Kanban 管线** | — | — | ✅ Deal stages |
| **团队共享** | — | — | ✅ $15/人 |
| **导出** | — | PDF | CSV + CRM 格式 |

---

## 4. 技术架构

```
┌─────────────────────────────────────────────────┐
│                  SwiftUI App                     │
├─────────────────────────────────────────────────┤
│  UI Layer                                        │
│  ├── Personal Tab: EchoLayerView, EchoCardView   │
│  ├── Business Tab: PipelineView, DealCardView    │
│  └── Settings: SubscriptionView                  │
├─────────────────────────────────────────────────┤
│  Service Layer                                   │
│  ├── ContactImportService (CNContacts)            │
│  ├── EchoEngine (分层逻辑, 本地)                  │
│  ├── AIService (DeepSeek API client)              │
│  ├── VoiceService (火山引擎 ASR/TTS)              │
│  └── StoreKitManager (IAP)                       │
├─────────────────────────────────────────────────┤
│  Data Layer                                      │
│  ├── SwiftData (EchoContact, Interaction, Note)   │
│  ├── Deal, PipelineStage (B2B)                   │
│  └── Keychain (API keys)                         │
├─────────────────────────────────────────────────┤
│  Privacy Boundary                                │
│  ├── 通讯录原始数据: 永不上传                     │
│  ├── 备注/互动: Pro 用户授权后脱敏发送            │
│  └── 照片/语音: 用户主动触发                     │
└─────────────────────────────────────────────────┘
```

---

## 5. 数据模型

### EchoContact (三模共用)

```swift
@Model final class EchoContact {
    @Attribute(.unique) var systemIdentifier: String
    var givenName: String
    var familyName: String
    var phoneNumber: String?
    var emailAddress: String?
    var thumbnailData: Data?
    
    // Layer (Personal mode)
    var isInEchoLayer: Bool = true
    
    // Priority (Business mode)
    var priorityLevel: PriorityLevel.RawValue?  // hot, warm, cold
    var dealStage: DealStage.RawValue?          // lead, contacted, quoted, negotiating, closed
    var dealValue: Double?
    var nextActionDate: Date?
    var policyNumber: String?
    var policyExpiryDate: Date?
    var companyName: String?
    var jobTitle: String?
    
    // Common
    var lastReachedOut: Date?
    var reachCount: Int = 0
    var tags: [String] = []
    
    @Relationship(deleteRule: .cascade) var interactions: [Interaction]
    @Relationship(deleteRule: .cascade) var notes: [Note]
}
```

### Deal (B2B only)

```swift
@Model final class Deal {
    var title: String
    var value: Double
    var stage: DealStage.RawValue
    var expectedCloseDate: Date?
    var probability: Double  // 0.0 ~ 1.0
    var createdAt: Date
    
    @Relationship var contact: EchoContact?
    @Relationship(deleteRule: .cascade) var activities: [DealActivity]
}
```

### DealStage

```swift
enum DealStage: String, Codable, CaseIterable {
    case lead = "lead"
    case contacted = "contacted"
    case quoted = "quoted"
    case negotiating = "negotiating"
    case closedWon = "closed_won"
    case closedLost = "closed_lost"
    
    var kanbanColumn: Int { ... }
    var color: String { ... }
}
```

---

## 6. AI 服务设计

### AIService (DeepSeek API)

```
Base URL: https://api.deepseek.com
Models:
  - 由 AIModelRouter 按任务动态选择，不在业务代码中硬编码
  - 默认：deepseek-v4-flash（高频/低延迟任务）
  - 默认：deepseek-v4-pro（复杂推理/结构化提取）
  - 支持任意未来模型 ID、任务级覆盖、单次请求覆盖和 fallback

Endpoints:
  POST /chat/completions → 文字生成 + 选定模型支持时的图片理解

核心能力：
  ✅ 智能开场白生成
  ✅ 关系图谱推断
  ✅ 名片/文档 OCR + 结构化提取
  ✅ 语义情感分析
  ✅ 销售教练（通话后分析 + 建议）
  ✅ 竞品对比分析
```

**隐私处理：** 发送到 DeepSeek 的数据中，人名替换为 "Person A"，公司名替换为 "Company X"。原始标识符不出设备。

**模型迁移：** 以 `Sources/EchoAI` 为实现源，配置和切换方法见 `model-routing.md`。模型 ID 是开放字符串，DeepSeek 发布新模型后无需修改枚举或业务功能即可切换。

### VoiceService (火山引擎)

```
能力：
  ✅ ASR (语音转文字): 实时流式 + 离线文件
  ✅ TTS (文字转语音): 每日简报朗读
  ✅ 声纹识别: 区分不同说话人（会议记录场景）

使用场景：
  - 语音备注: "Echo, note that Sarah's mom is recovering"
  - 会议转录: 录音 → ASR → AI 提取行动项
  - 每日简报: 早上推送 → 点击播放语音
```

---

## 7. 核心用户流程

### 7.1 首次使用

```
App 启动
  → Onboarding: 品牌展示
  → 通讯录权限请求
  → 导入 187 个联系人
  → 自动进入 Personal Tab（Echo Layer）
  → 看到 30 个人的卡片
  → 底部 "Business" Tab 显示 "Coming Soon — Upgrade to Pro"
```

### 7.2 日常使用（Personal）

```
打开 App
  → Echo Layer 卡片（AI 排序，谁最需要关注）
  → 看到 Sarah 的卡片："通常每两周联系——已过 19 天"
  → 点 "Reach out" → 底部弹出 Call / Message / Email
  → 点 Message → 跳转到 iMessage + AI 建议开场白："问问她妈妈恢复得怎么样"
  → 发送后回到 Echo → 自动记录 "Messaged Sarah · 2 min ago"
```

### 7.3 升级到 AI Pro

```
使用一周后
  → 推送/应用内提示："Echo 可以自动帮你管理回响层。30 天免费试用。"
  → 用户开启试用
  → AI 自动重新分层："Mike 从第 12 位移到第 2 位——你们最近互动激增"
  → 试用结束 → 付费 $4/月 或退回手动模式
```

### 7.4 切换到 Business Mode

```
开通 B2B Pro ($15/月)
  → Business Tab 激活
  → 引导：导入工作通讯录 / CSV / 手动添加
  → 看到 Kanban 管线视图
  → 拍照录入保单："拍照 → AI 提取保单号、到期日、险种 → 自动创建 Deal"
  → 通话后：AI 销售教练分析 → "你提到了价格 3 次，但没提理赔。下次先说理赔。"
  → 导出 CSV 给合规部门
```

---

## 8. UI 设计规格

### 8.1 三 Tab 结构

```
┌─────────────────────────────────────┐
│  [Personal]  [AI ✨]  [Business 💼]  │  ← Tab Bar
├─────────────────────────────────────┤
│                                     │
│  Echo Layer Cards (scrollable)       │
│  ┌─────────────────────────────┐    │
│  │ 👤 Sarah Chen          19d  │    │
│  │ Her mom is recovering well. │    │
│  │ [👋 Reach out]              │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 👤 Mike Johnson        3mo  │    │
│  │ Changing jobs — follow up.  │    │
│  │ [👋 Reach out]              │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### 8.2 Business Tab — Kanban 管线

```
┌─────────────────────────────────────┐
│  Pipeline                    [+New] │
├──────────┬──────────┬──────────────┤
│  Leads   │ Quoted   │ Negotiating   │
│  (3)     │ (2)      │ (1)           │
├──────────┼──────────┼──────────────┤
│┌────────┐│┌────────┐│┌────────────┐│
││Acme    │││Beta    │││Gamma       ││
││$5K     │││$12K    │││$8K         ││
││New lead│││Sent 6/1│││Counter due ││
│└────────┘│└────────┘│└────────────┘│
│┌────────┐│┌────────┐│              │
││Delta   │││Epsilon ││              │
││$3K     │││$2K     ││              │
│└────────┘│└────────┘│              │
└──────────┴──────────┴──────────────┘
```

### 8.3 设计常量

```
背景色： #090A0E
卡片色： #1A1B1F
主色调： #3B82F6 (蓝色)
热线索： #FF453A (红色)
温线索： #F59E0B (琥珀)
冷线索： #636366 (灰色)
已成交： #34C759 (绿色)
已丢失： #8E8E93 (灰色)

字体： SF Pro
圆角： 16px (卡片), 10px (按钮)
间距： 4pt 网格系统
```

---

## 9. 构建范围（不分期，完整交付）

### Phase 1: 项目骨架
- [x] Xcode 项目 + SwiftData + SwiftUI
- [x] 深色主题 + 调色板
- [x] 数据模型（EchoContact, Interaction, Note, Deal）

### Phase 2: 通讯录 + 基础 UI
- [x] 通讯录导入服务
- [x] EchoLayerView + EchoCardView
- [x] PeopleLibraryView（搜索 + 字母索引）
- [x] Onboarding 流程

### Phase 3: 联系 + 备注
- [x] ContactDetailView（详情 + 时间线 + 备注）
- [x] ReachActionSheet（一键联系）
- [x] 互动记录

### Phase 4: AI 服务（DeepSeek + 火山引擎）
- [x] AIService（DeepSeek API 客户端 + Keychain 密钥管理）
- [x] VoiceService（火山引擎 ASR/TTS）
- [x] 智能开场白生成
- [x] 拍照识别（名片/文档）
- [x] 语音备注
- [x] 每日简报 TTS 朗读
- [x] 隐私脱敏层（人名替换 → API → 还原）

### Phase 5: AI Pro 功能
- [x] AI 自动分层（DeepSeek 分析互动信号）
- [x] 节奏检测 + 提醒
- [x] 关系健康分
- [x] AI Tab（AI 驱动的洞察页面）
- [x] 30 天免费试用 + StoreKit 2 订阅

### Phase 6: B2B Pro 功能
- [x] Business Tab + Kanban 管线视图
- [x] Deal 管理（创建/移动/详情）
- [x] 拍照录单（保单/合同 OCR + 结构化）
- [x] AI 销售教练（通话后分析）
- [x] 客户画像生成
- [x] CSV/CRM 导出
- [x] 团队共享（可选）

### Phase 7: 系统集成
- [x] Widget（主屏 + 锁屏）
- [x] Dynamic Island
- [x] Siri Shortcuts
- [x] Apple Watch
- [x] iCloud 同步

### Phase 8: 打磨 + 测试
- [x] App Icon
- [x] 全流程冒烟测试
- [x] 性能优化
- [x] App Store Connect 配置

---

## 10. 成功指标

| 指标 | 目标 | 时间 |
|------|------|------|
| Day-1 激活率 | >60% 授权通讯录 | 上线首周 |
| Week-1 留存 | >40% 打开 ≥3 次 | 上线首周 |
| AI Pro 试用转化 | >15% 开启免费试用 | 30 天内 |
| AI Pro 付费转化 | >40% 试用 → 付费 | 试用结束后 |
| B2B Pro 转化 | >3% 总用户 | 3 个月内 |
| B2B 月流失 | <5% | 稳态 |
| App Store 评分 | ≥4.5★ | 持续 |

---

## 11. AI 成本模型

| 用户层 | 月 AI 成本 | 定价 | 毛利率 |
|--------|-----------|------|--------|
| Personal (Free) | $0 | $0 | — |
| AI Pro | ~$0.53 | $4 | 87% |
| B2B Pro | ~$0.80 | $15 | 95% |

---

> **交付物：** 一个完整的三模 iOS App，含 DeepSeek 多模态 AI + 火山引擎语音。不分期，一次建成。
