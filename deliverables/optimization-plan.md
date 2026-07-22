# Echo — P0 产品优化方案（留存 + 裂变 + 首次体验 + 设计 + AI）

> 基于产品力评估（6.28/10），优先修复 5 个拖分维度。全部为客户端改动，零后端。

---

## 一、留存机制（5 → 8）

### 问题
Echo 的使用频率是每周 1-3 次，没有"明天还来"的钩子。

### 方案

#### 1.1 Streak 系统

```
用户完成 Reach 操作后：
  → 弹出 Streak 动画：
     🔥 "Weekly Streak: 4 weeks!"
  → 如果中断：
     "Your streak reset. Reach out today to start a new one."

存储：UserDefaults
触发：每次 Reach 操作后检查
显示：Personal Tab 顶部 Streak bar
```

**Swift 实现：**
```swift
// Services/StreakManager.swift
struct StreakManager {
    static let defaults = UserDefaults.standard
    
    static var currentStreak: Int {
        defaults.integer(forKey: "echo_weekly_streak")
    }
    
    static func recordReach() {
        let calendar = Calendar.current
        let thisWeek = calendar.component(.weekOfYear, from: Date())
        let lastWeek = defaults.integer(forKey: "echo_last_reach_week")
        
        if thisWeek == lastWeek + 1 || (lastWeek == 0 && thisWeek > 0) {
            defaults.set(currentStreak + 1, forKey: "echo_weekly_streak")
        } else if thisWeek != lastWeek {
            defaults.set(1, forKey: "echo_weekly_streak")
        }
        defaults.set(thisWeek, forKey: "echo_last_reach_week")
    }
    
    static var streakEmoji: String {
        switch currentStreak {
        case 0..<2: return "🌱"
        case 2..<5: return "🔥"
        case 5..<12: return "⭐"
        case 12..<24: return "💎"
        default: return "👑"
        }
    }
}
```

#### 1.2 每周回顾卡片

**每周一自动生成一张特殊卡片插入 Echo Layer 顶部：**

```
┌──────────────────────────────────┐
│  📊 Your Week in Echo             │
│                                  │
│  This week you connected with     │
│  5 people across 12 interactions. │
│                                  │
│  Most responsive: Sarah (3x)     │
│  Longest gap closed: David (42d) │
│  New this week: Alex             │
│                                  │
│  [Share Your Week]  [Dismiss]    │
└──────────────────────────────────┘
```

**Swift 实现：** 在 `EchoLayerView` 中，每周一检查是否生成本周的回顾卡片。存储在本地的 `WeeklySummary` SwiftData 模型中。

#### 1.3 AI 惊喜卡片

**每 30 天，AI 分析互动数据变化，生成一张洞察卡片：**

```
"Echo noticed your relationship with Mike has deepened 40% this month.
You went from 2 messages/week to almost daily contact since he started his new job."
```

**触发时机：** AI Pro 用户，距上次惊喜卡片 > 30 天。

---

## 二、社交裂变（2 → 6）

### 问题
零传播机制。用户不会主动告诉别人 Echo。

### 方案

#### 2.1 分享联系人卡片

**在 ContactDetailView 中增加 "Share Card" 按钮：**

```swift
// Generate a shareable image of the contact card
func generateShareCard(for contact: EchoContact) -> UIImage {
    let renderer = ImageRenderer(content: ShareCardView(contact: contact))
    renderer.scale = 3.0
    return renderer.uiImage ?? UIImage()
}
```

**分享图片包含：**
- Echo logo + "Stay in touch with Echo"
- 模糊化的联系人信息（保护隐私）："Sarah · Last reached out 3 days ago"
- "I use Echo to remember what matters. echo-app.com"
- 底部二维码链接到 App Store

#### 2.2 里程碑分享

```
用户达成里程碑时弹出：
  "🎉 You've reached out 50 times!"
  [Share] [Dismiss]

  "📅 3 months on Echo — you've connected with 28 people!"
  [Share Your Stats] [Dismiss]
```

**分享内容：** 一张精美的统计卡片（不含具体联系人名字，只含数字）。

#### 2.3 App Store 评分引导

```
用户完成第 10 次 Reach 操作后：
  → 弹出系统评分对话框
  → 如果评分 ≥ 4 星 → "Thanks! Would you tell a friend?"
  → 如果评分 < 4 星 → "What can we improve?" → 打开反馈表单
```

使用 `SKStoreReviewController.requestReview()`（iOS 原生的评分 API，每年最多弹 3 次）。

#### 2.4 邀请机制（B2B）

```
Business 用户：
  Settings → "Invite team member" → 生成邀请链接
  → 接收方下载 Echo → 自动加入团队
  → 邀请人和被邀请人各得 1 个月免费 Business
```

---

## 三、首次体验（6 → 8）

### 问题
导入后用户看到一堆卡片，不知道该做什么。

### 方案

#### 3.1 3 步交互式引导 Tour

**导入完成后，在 Echo Layer 上方叠加 3 个步骤：**

```
Step 1: "This is your Echo Layer — the people you care about most."
        → 高亮第一张卡片，周围暗下来
        → [Next]

Step 2: "Tap 'Reach out' to call, message, or email in one tap."
        → 高亮 Reach 按钮
        → [Next]

Step 3: "Echo remembers every interaction. Come back anytime."
        → 显示互动时间线预览
        → [Got it!]
```

**Swift 实现：** `OnboardingOverlayView` 使用 SwiftUI `.overlay` + 毛玻璃背景。

#### 3.2 Demo 模式（通讯录权限被拒）

```
用户拒绝通讯录权限：
  → 不要显示空白屏幕
  → 显示 3 张 demo 卡片（Mom, Sarah, Mike）带真实数据
  → 每张卡片上有一个 "Add to Echo" 按钮
  → 底部提示："Grant Contacts access to import all your people."
  → [Open Settings]
```

#### 3.3 导入后即时行动提示

```
导入完成 → 跳转到 Personal Tab
  → 顶部出现一个横幅（3 秒后自动消失）：
     "👋 Sarah was last contacted 19 days ago. Say hi?"
     [Reach out now]
  → 用户点击 → 直接打开 Reach Sheet
  → 完成第一次 Reach → "✓ First connection! Echo will keep track."
```

---

## 四、设计品质（7 → 8）

### 问题
缺少 iOS 原生级的动效和手势交互。

### 方案

#### 4.1 手势交互

| 手势 | 位置 | 操作 |
|------|------|------|
| **右滑卡片** | Echo Layer | 标记为 "Reached out today"（快捷操作） |
| **左滑卡片** | Echo Layer | 移到 People Library（降级） |
| **长按卡片** | Echo Layer | Context Menu：Call / Message / Email / Edit Note |
| **下拉刷新** | Echo Layer | 强制刷新 AI 排序 |
| **双击头像** | Contact Detail | 快速拨号 |

**Swift 实现：** `.swipeActions(edge: .leading)` / `.contextMenu`

#### 4.2 动效

| 动效 | 场景 | 实现 |
|------|------|------|
| **卡片弹簧动画** | 导入完成后卡片逐个弹出 | `.spring(duration: 0.4, bounce: 0.3)` |
| **✓ 扩散波纹** | Reach 成功后 | SF Symbol `checkmark.circle.fill` + `.scaleEffect` |
| **Streak 火焰** | Streak 更新时 | Lottie 动画或 SF Symbol `flame.fill` + 粒子效果 |
| **Tab 切换** | Tab 切换时 | `.matchedGeometryEffect` 平滑过渡 |
| **卡片翻转** | 点击卡片进入详情 | 3D `.rotation3DEffect` |

#### 4.3 SF Symbol 动画

```
iOS 17+ 的 symbolEffect:
  - Reach 按钮: .bounce
  - AI Tab 刷新: .variableColor
  - 推送通知到达: .pulse
  - Streak 更新: .bounce.up.byLayer
```

#### 4.4 Dynamic Island + Live Activity

```
用户点击 Reach out → Call：
  → Dynamic Island 展开显示：
     "📞 Calling Sarah Chen · Last note: mom recovering"
  → 通话结束后自动收起
```

---

## 五、AI 智能度（7 → 9）

### 问题
AI 被动等待用户打开。应该主动推送、学习行为、提供惊喜。

### 方案

#### 5.1 AI 主动推送卡片

**每天在 Echo Layer 顶部插入一张 AI 生成的特殊卡片（不占联系人名额）：**

```
"👋 Today's Suggestion"
"3 people in your Echo Layer haven't heard from you in over 2 weeks.
 Sarah (19d), David (42d), Chris (30d)."
[Reach out to Sarah] [See all 3]
```

**生成逻辑（本地 + DeepSeek）：**
1. 本地扫描所有 Echo Layer 联系人 → 找出 >14 天未联系的
2. DeepSeek 根据优先级排序："谁最需要联系？"
3. 生成一句话建议

#### 5.2 行为学习（本地）

```
Echo 观察用户行为模式（纯本地，不上传）：
  ✅ 你通常周日下午 3-5 点联系家人
  ✅ 你通常周三上午查看 AI Insights
  ✅ 你对 Sarah 的回复率最高
  ✅ 你对 LinkedIn 联系人几乎不联系

学习结果驱动：
  → 推送时机：周日 3pm 推"Don't forget to call Mom"
  → AI Tab 更新时机：周三早上预先生成 insights
  → 排序优化：Sarah 类联系人排前面
```

**存储：** `UserDefaults` + 轻量统计（纯数学，不需要 ML）。

#### 5.3 离线 AI 缓存

```
用户打开 AI Tab：
  → 如果有缓存（< 24 小时）→ 显示缓存
  → 如果无缓存/过期 → 显示加载 + "Pull to refresh"
  → 如果离线 → 显示最后一次缓存 + "Offline — last updated 3h ago"

缓存存储：SwiftData 中的 AICache 模型
```

#### 5.4 被动 → 主动提醒

```
当前：用户打开 AI Tab → 看到 insights
优化：AI 在合适的时机主动通知

触发条件：
  - 用户刚和某人打完电话 → "Want me to log this and suggest next steps?"
  - 用户三天没打开 Echo → "👋 7 people are waiting to hear from you."
  - 用户的 Streak 即将中断（周日 8pm 还没 Reach）→ "🔥 Your 4-week streak ends today!"
```

---

## 六、对构建计划的影响

| 优化项 | 新增 Swift 文件 | Phase |
|--------|----------------|-------|
| Streak 系统 | `Services/StreakManager.swift` | Phase 3 |
| 每周回顾 | `Models/WeeklySummary.swift` | Phase 3 |
| AI 惊喜卡片 | `Views/Personal/SurpriseCardView.swift` | Phase 4 |
| 分享卡片 | `Views/Share/ShareCardView.swift` | Phase 7 |
| 里程碑 | `Services/MilestoneManager.swift` | Phase 7 |
| 引导 Tour | `Views/Onboarding/OnboardingTourView.swift` | Phase 3 |
| Demo 模式 | 修改 `EchoLayerView` | Phase 3 |
| 手势交互 | 修改所有卡片 View | Phase 3 |
| 动效系统 | `Helpers/AnimationPresets.swift` | Phase 3 |
| Dynamic Island | `EchoLiveActivity.swift` | Phase 7 |
| AI 主动推送 | `Services/AIScheduler.swift` | Phase 4 |
| 行为学习 | `Services/BehaviorLearner.swift` | Phase 4 |

---

## 七、预估提升

| 维度 | 当前 | 优化后 | 提升幅度 |
|------|:--:|:--:|:--:|
| 首次体验 | 6 | 8 | +2 |
| 设计品质 | 7 | 8 | +1 |
| AI 智能度 | 7 | 9 | +2 |
| 留存机制 | 5 | 8 | +3 |
| 社交裂变 | 2 | 6 | +4 |
| **加权总分** | **6.28** | **~7.9** | **+1.62** |
