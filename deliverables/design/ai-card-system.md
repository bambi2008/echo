# Echo AI 名片系统设计

> 用户导入通讯录后，AI 自动识别联系人身份，生成差异化名片。不是千篇一律的卡片——是"这个人在你生命中的角色"的视觉表达。

---

## 一、AI 身份识别引擎

### 输入信号

| 信号 | 来源 | 权重 |
|------|------|------|
| 通讯录标签（家人/同事） | CNContact.contactType, CNLabeledValue | ⭐⭐⭐⭐⭐ |
| 公司名 + 职位 | CNContact.organizationName, jobTitle | ⭐⭐⭐⭐ |
| 互动频率 | Echo 本地计算（通话/iMessage/见面） | ⭐⭐⭐⭐ |
| 称呼（Mom, Dad, Dr., Prof.） | CNContact.namePrefix, givenName 匹配 | ⭐⭐⭐⭐⭐ |
| 备注内容 | 用户手动备注 | ⭐⭐⭐ |
| DeepSeek 语义分析 | 备注 + 互动内容的语义理解 | ⭐⭐⭐ |

### 身份分类

```
Echo Engine AI 分析所有信号 → 自动归类：

  🏠 Family    — "Mom", "Dad", 姓相同, 备注含"birthday"/"parents"
  💼 Business  — 有公司名+职位, 通话内容含"quote"/"renewal"
  👥 Friend    — 高频互动, 无工作关系, 备注含情感内容
  🎓 Mentor    — 备注含"mentor"/"coach", 互动规律（每月一次）
  🌐 Network   — LinkedIn 导入, 低频互动, 有公司名
  ❓ Unknown   — 只有名字和电话, 无其他信号
```

---

## 二、六种名片类型

### 2.1 家人卡 | Family Card

```
┌──────────────────────────────────┐
│                            ❤️    │
│       ┌────────────┐             │
│       │   Mom       │             │
│       │  (emoji)    │             │
│       └────────────┘             │
│                                  │
│       最近通话: 7天前             │
│       📞 每周日固定通话           │
│                                  │
│       生日: 11月8日               │
│       🎂 还有110天               │
│                                  │
│       备注:                      │
│       "喜欢园艺，退休教师"        │
│                                  │
│       [📞 打电话] [💬 发消息]    │
└──────────────────────────────────┘
```

**视觉特征：**
- 主色：暖粉/珊瑚色（#F2A59D）
- 图标：❤️ 或自定义 emoji
- 优先显示：生日倒计时、固定联系节奏
- AI 生成："你每周日给妈妈打电话，已坚持 18 周。"

### 2.2 商务卡 | Business Card

```
┌──────────────────────────────────┐
│  🔥 HOT              $85K/年     │
│                                  │
│  ┌──────┐  Tom Brown             │
│  │  TB  │  Senior Agent          │
│  └──────┘  Acme Insurance        │
│                                  │
│  📋 续保提醒: 10月15日 (87天)     │
│  📝 上次联系: 昨天               │
│                                  │
│  关键备注:                       │
│  "儿子明年大学毕业，需要单独车险"  │
│                                  │
│  Pipeline: Quoted → Negotiating  │
│  [📞] [💬] [📧] [📋 更新进展]    │
└──────────────────────────────────┘
```

**视觉特征：**
- 主色：蓝/红色（Hot）/ 琥珀色（Warm）
- 标识：🔥 Hot / 🟡 Warm / ❄️ Cold
- 优先显示：续保日期、年产值、管线阶段
- AI 生成："Tom 的续保还有 87 天。他儿子明年毕业——主动推荐独立车险。"

### 2.3 好友卡 | Friend Card

```
┌──────────────────────────────────┐
│                                  │
│       ┌────────────┐             │
│       │   Sarah     │             │
│       │   Chen      │             │
│       └────────────┘             │
│                                  │
│  ⚠️ 通常每两周联系 — 已过19天     │
│                                  │
│  上次聊到:                       │
│  "她妈妈手术恢复得很好"           │
│                                  │
│  AI 建议:                        │
│  "问问她妈妈恢复得怎么样 ❤️"      │
│                                  │
│  [👋 联系]  [📝 备注]            │
└──────────────────────────────────┘
```

**视觉特征：**
- 主色：蓝紫色（#3B82F6 Echo 主色）
- 优先显示：节奏异常提醒、AI 生成的开场白
- 语气：温暖、个人化

### 2.4 导师卡 | Mentor Card

```
┌──────────────────────────────────┐
│                            🎓    │
│       ┌────────────┐             │
│       │   Lisa Park  │             │
│       │  Executive Coach         │
│       └────────────┘             │
│                                  │
│  📅 每月固定见面: 下次8月10日     │
│  ⏱️ 导师关系: 已持续18个月        │
│                                  │
│  AI 洞察:                        │
│  "这是你最稳定的职业关系。        │
│   考虑请她介绍她的network。"      │
│                                  │
│  [📅 约下次] [💬 发消息]         │
└──────────────────────────────────┘
```

### 2.5 新人脉卡 | Network Card

```
┌──────────────────────────────────┐
│  NEW                              │
│                                  │
│  ┌──────┐  Jessica Miller        │
│  │  JM  │  VP Marketing          │
│  └──────┘  Figma                 │
│                                  │
│  📅 认识于: 7月5日                │
│       (行业大会上交换的名片)       │
│                                  │
│  ⚡ 建议: 7天内发一条follow-up     │
│  💡 "Nice meeting you at Config!  │
│      Loved your talk on..."      │
│                                  │
│  [💬 发follow-up] [📝 记笔记]    │
└──────────────────────────────────┘
```

**视觉特征：**
- 标识：NEW 标签（蓝色高亮）
- 优先显示：认识场景、AI follow-up 建议
- 7天后自动降级为普通好友卡或归档

### 2.6 基础卡 | Default Card

```
┌──────────────────────────────────┐
│  ┌──────┐  Chris Thompson        │
│  │  CT  │  (无额外信息)           │
│  └──────┘                        │
│                                  │
│  上次联系: 30天前                 │
│  备注: "大学室友。住在LA。"       │
│                                  │
│  [👋 联系]                       │
└──────────────────────────────────┘
```

最低信息量。用户可以通过加备注来升级卡片类型。

---

## 三、AI 身份识别 Prompt

```swift
// AIService.swift
func classifyContact(
    givenName: String,
    familyName: String?,
    company: String?,
    title: String?,
    notes: [String],
    interactionCount: Int,
    hasBirthday: Bool,
    contactLabel: String?  // from CNContact: "mother", "father", "brother", etc.
) async throws -> ContactCardType {
    
    let prompt = """
    Classify this contact into ONE category based on the available data.
    Categories: family, business, friend, mentor, network, default
    
    Name: \(givenName) \(familyName ?? "")
    Company: \(company ?? "none")
    Title: \(title ?? "none")
    iOS Contact Label: \(contactLabel ?? "none")
    Notes: \(notes.joined(separator: "; "))
    Interactions: \(interactionCount)
    Has Birthday: \(hasBirthday)
    
    Return JSON: {"type": "family|business|friend|mentor|network|default", "confidence": 0.0-1.0}
    """
    
    let result = try await chat(systemPrompt: "You are a contact classifier. Return JSON only.", userMessage: prompt)
    // Parse result
}
```

**但大多数情况下不需要 DeepSeek：** 通讯录自带的标签（CNContact.contactType）和称呼（namePrefix = "Dr."）已经足够判断。DeepSeek 只用于边缘情况（有公司名但可能是朋友创业）。

---

## 四、名片交互设计

### 卡片操作差异化

| 卡片类型 | 主操作 | 副操作 | 快捷手势 |
|---------|--------|--------|---------|
| 家人 | 📞 打电话 | 💬 发消息 | 长按 → 直接拨号 |
| 商务 | 📞 打电话 | 📧 发邮件 + 📋 更新进展 | 左滑 → 移到下一管线阶段 |
| 好友 | 💬 发消息 | 📞 打电话 | 长按 → 查看 AI 建议开场白 |
| 导师 | 📅 约见面 | 💬 发消息 | 长按 → 查看历史笔记 |
| 人脉 | 💬 Follow-up | 📝 记笔记 | 长按 → 生成 follow-up 消息 |
| 基础 | 👋 联系 | 📝 加备注 | — |

### 卡片排序

不同模式的默认排序：
- Personal Tab → 按"最需要关注"排序（AI 综合评分）
- Business Tab → 按"紧急度"排序（Hot → Warm → Cold）
- 全部列表 → 按字母排序

---

## 五、原型更新计划

在 `prototype-v2.html` 中实现：

1. 6 种卡片类型的视觉差异化
2. 每个联系人的 `cardType` 字段
3. AI Insights Tab 显示"刚刚识别了 12 个商务联系人，3 个家人"
4. 卡片长按/右键切换类型
