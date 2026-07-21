# Competitor Triple Deep-Dive: Close.com + Dex + Streak

> 三竞品联合分析，按对 Echo 的威胁度排序：Dex（B2C 直接竞品）> Close.com（AI 电话销售）> Streak（Gmail CRM）

---

## 一、Dex — B2C 直接竞品

### 产品定位
"The Rolodex, Reimagined." — 个人关系管理，不是销售 CRM。

### 核心功能

| 功能 | 描述 | Echo 对标 |
|------|------|----------|
| **多源导入** | Facebook, LinkedIn, iCloud, Gmail, Twitter | Echo 只做通讯录导入。Dex 覆盖面更广。 |
| **iMessage Sync Utility** | 读取 iMessage 历史，自动记录互动 | ❌ Echo 做不到（Apple 隐私限制） |
| **Keep-in-touch 提醒** | 设定联系频率目标，到时提醒 | Echo AI Pro 节奏检测对标此功能 |
| **互动时间线** | 自动记录邮件 + Linkedin + iMessage 互动 | Echo 手动记录 + AI 推断 |
| **备注** | 手动添加，支持富文本 | ✅ Echo 相同 |
| **键盘快捷键** | ⌘K 快速搜索和操作 | ❌ Echo 不需要（移动端） |
| **Groups** | 联系人分组 | Echo Layer / People Library / Priority Contacts |
| **重要日期提醒** | 纪念日、产品发布、毕业等 | Echo 生日 + 自定义提醒 |

### 关键数据
- **30,000+ 用户**（2025 年数据）
- **7 天免费试用**
- **定价未公开**（需要注册才能看到，但根据 HN 用户推测在 $12-20/月）
- **平台：** Web（桌面） + iOS App + Android App + 浏览器扩展
- **YC S19** 投资

### 用户画像（从 testimonials 提取）
- MBA 学生（network for job search）
- 投资人（manage LP relationships）
- 创业者（keep track of investors and partners）
- 纪录片导演（remember people met through work）
- "让我在忙碌的世界里，成为我想成为的那种朋友"

### Dex 的优势（对 Echo 的威胁）

| 维度 | Dex 赢在哪 |
|------|-----------|
| **数据源广度** | 可以从 5+ 个平台导入联系人。Echo 只有通讯录。 |
| **iMessage 同步** | 自动记录 iMessage 互动。这是 Echo 永远做不到的。 |
| **自动互动记录** | 邮件 + LinkedIn + iMessage 自动生成时间线。Echo 需要手动记录。 |
| **桌面端** | Web + Mac App。覆盖桌面场景。 |
| **品牌 + 融资** | YC S19，3 万用户，有品牌知名度。 |
| **Group 功能** | 联系人分组管理。Echo 目前没有。 |

### Dex 的劣势（Echo 的机会）

| 维度 | Echo 赢在哪 |
|------|-----------|
| **移动端体验** | Dex 有 iOS App 但本质是 web 套壳。Echo 是原生 SwiftUI。 |
| **AI 深度** | Dex 的提醒是规则驱动的（"每两周提醒一次"）。Echo 的 AI 是语义驱动的（"你该说什么"）。 |
| **免费版** | Dex 只有 7 天试用。Echo Personal 永远免费。 |
| **本地隐私** | Dex 是云端 SaaS。Echo 本地优先。 |
| **AI 开场白** | 无。Echo 的 DeepSeek 生成个性化开场白。 |
| **语音** | 无。Echo 有火山引擎 ASR + TTS。 |
| **拍照 OCR** | 无。Echo 有名片/保单扫描。 |
| **B2B 模式** | 没有。明确说 "Your relationships don't belong in a sales CRM." |
| **Kanban 管线** | 无。 |

### 战略威慑

**Dex 的 iMessage Sync Utility 是 Echo 最大的功能短板。** 如果用户的核心需求是"自动记录所有互动"，Dex 完胜 Echo。

**但这里有产品哲学的分歧：**
- Dex = 被动记录（自动抓取你在别处的行为）
- Echo = 主动行为（你打开 Echo，决定联系谁）

Dex 的价值是"不让你忘记"；Echo 的价值是"让你真的去联系"。两者满足的是同一个用户的同一个需求的不同环节。**理论上应该共存，但用户不会同时用两个 CRM。**

---

## 二、Close.com — AI 电话销售 CRM

### 产品定位
"The CRM built for action." — 内置通话、短信、邮件、管线。有 AI 销售代理 Chloe。

### 核心功能

| 功能 | 描述 |
|------|------|
| **Power Dialer** | 内置 VoIP 拨号器。在 CRM 内直接拨打电话。 |
| **AI Agent "Chloe"** | 自动外呼、对话、资格审查、预约会议、记录笔记。 |
| **SMS + Email + Calling** | 三合一收件箱。所有沟通在一个界面。 |
| **自动记录** | 通话自动转录、短信自动存档、邮件自动关联联系人。 |
| **Pipeline 管理** | 多阶段管线，拖动式管理。 |
| **Workflows** | 自动触发序列。新线索 → 自动发邮件 → 3 天后自动打电话。 |
| **AI Deep Dives** | 分析销售通话，给出改进建议。 |
| **预测拨号** | 同时拨打多个号码，接通的第一个转给销售。 |

### 定价（2025年）

| 计划 | 价格 | AI Credits |
|------|------|-----------|
| Startup | $49/人/月 | 500/人/月 |
| Professional | $99/人/月 | 1,000/人/月 |
| Business | $129/人/月 | 1,500/人/月 |
| Enterprise | $149/人/月 | 2,000/人/月 |

### Chloe — AI 销售代理详解

Chloe 是目前市场上最激进的 CRM AI：
1. **呼出电话** — 新线索进入 CRM → Chloe 在几分钟内自动致电
2. **真实对话** — 通过内置拨号器进行真实的语音对话（不是聊天机器人）
3. **资格审查** — 判断线索是否合格
4. **预约会议** — 合格后自动在销售日历上预定
5. **自动记录** — 通话转录、摘要、下一步自动写回 CRM
6. **冷线索复活** — 检测到冷线索 → 自动重新联系 → 发给销售
7. **跟进自动化** — 报价后自动跟进 → 更新管线阶段

**这是 Echo B2B 最大的威胁来源。** 如果 Close 把 Chloe 降到一个 solo agent 能承受的价格（比如 $20-30/月），Echo 的 B2B 价值主张会大幅削弱。

### Close 的优劣势

| Close 优势 | Close 劣势 |
|-----------|-----------|
| 内置通话（VoIP）| $49/月起，远超 Echo 的 $15 |
| AI 代理 Chloe（主动外呼）| 面向团队，不是 solo |
| SMS + Email + Call 三合一 | 没有通讯录导入（手动录入 leads） |
| 自动转录 + 记录 | 没有关系健康度分析 |
| 预测拨号 | 没有个人生活场景 |
| 企业级管线 + 报表 | 没有真正的移动原生 App |

---

## 三、Streak — Gmail 内 CRM

### 产品定位
"CRM in your inbox." — Gmail 插件，管理销售管线不离开邮箱。

### 核心功能
- **Pipeline 在收件箱里** — Gmail 侧边栏显示销售管线
- **邮件自动关联** — 发送邮件时自动关联到对应的 deal
- **Snippets** — 邮件模板快速插入
- **Mail Merge** — 批量个性化邮件
- **Shared Pipelines** — 团队共享管线
- **Google Workspace 集成** — Sheets, Drive, Calendar 深度整合

### 定价
- Free: 基础功能
- Solo: $15/月
- Pro: $49/月
- Enterprise: $129/月

### 为什么威胁最低

Streak 的 DNA 是 **Gmail-first, email-first, desktop-first。** 
- 不做 iMessage
- 不做电话通话
- 不做 AI 销售教练
- 不做移动端原生体验
- 锁死在 Google 生态

这和 Echo 的 **phone-first, mobile-first, AI-first** 是完全正交的赛道。Streak 的用户永远不会是 Echo 的用户，反之亦然。

**唯一值得学习的是他们的 "CRM where you already work" 理念。** Echo 的类比是：用户已经在用电话和 iMessage 了，Echo 在这些动作发生的那一瞬间记录，而不是要求用户事后录入。

---

## 四、三竞品 vs Echo 汇总

| 维度 | Echo | Dex | Close.com | Streak |
|------|------|-----|-----------|--------|
| **定位** | 移动 AI 关系助手 | 个人 CRM | 电话销售 CRM | Gmail CRM |
| **价格（个人）** | $0 | 未公开（~$15/月） | — | $15/月 |
| **价格（B2B）** | $15/月 | — | $49-149/月 | $49-129/月 |
| **移动端** | 🔥 iOS 原生 | ⚠️ Web 套壳 | ⚠️ 有 App | ❌ |
| **AI** | 🔥 DeepSeek 多模态 + 语音 | ❌ | 🔥 Chloe（电话 AI） | ❌ |
| **通讯录导入** | ✅ 一键 | ✅ 多源 | ❌ 手动 | ❌ |
| **iMessage 记录** | ❌ | ✅ iMessage Sync | ❌ | ❌ |
| **邮件集成** | ❌ | ✅ | ✅ | 🔥 |
| **通话集成** | 跳转系统电话 | ❌ | ✅ 内置 VoIP | ❌ |
| **隐私** | 🔥 本地优先 | ❌ 云端 | ❌ 云端 | ❌ 云端 |
| **B2B 管线** | 🔥 Kanban | ❌ "不是销售 CRM" | 🔥 企业级 | ✅ |
| **语音** | 🔥 ASR+TTS | ❌ | ⚠️ 转录 | ❌ |
| **用户量** | 0（新品） | 30,000+ | 未公开 | 未公开 |

---

## 五、对 Echo 的战略启示

### 1. Dex 的 iMessage Sync 是最大威胁，但不是决赛

Dex 的自动互动记录是一个真正好用的功能。但它是被动记录——"你已经在 iMessage 里聊过了，Dex 帮你记住"。Echo 的价值是主动行为——"你还没联系，Echo 建议你联系"。

**两种需求都存在，但 Echo 解决的问题更根本：** 人们的问题不是"忘了上次聊了什么"，而是"忘了去聊"。

### 2. Close 的 Chloe 指明了一个方向

Chloe 证明了 **AI 主动代理** 在销售 CRM 里的价值。Echo 不需要做到 Chloe 的级别（自动外呼），但可以借鉴：
- 推送时机智能化（不只是早上 8 点，而是"Sarah 通常周三下午有空"）
- 跟进建议自动化（"你发了报价 3 天没回复，建议打电话"）
- B2B v2.0 可以做 AI 自动短信（用户批准后，Echo 代发一条 follow-up 短信）

### 3. Streak 教我们：工具应该去用户所在的地方

Streak 在 Gmail 里做 CRM，因为用户在 Gmail 里工作。Echo 的类比：用户在电话和 iMessage 里工作。Echo 的 Reach Action（一键跳转到电话/iMessage）就是这个理念的实现。

**可以做的更好：** 在 Reach Action 完成后，Echo 自动弹出一个轻量级的 "Log this?" 提示——就像 Streak 在你发完邮件后自动问你要不要关联到 deal。

### 4. 价格锚点确认

- Dex ~$15/月（个人）
- Streak $15/月（Solo）
- Close $49/月（最低）
- LACRM $15/月

**Echo 的 $4 AI Pro 和 $15 B2B Pro 价格完全在市场上限之内，且有免费版做差异化入口。**

---

## 六、行动建议

| # | 行动 | 优先级 |
|---|------|--------|
| 1 | **在 Reach Action 后加 "Log this" 自动弹出**（对标 Streak 的自动关联 + Dex 的自动记录） | P0 |
| 2 | **研究 Dex 的 iMessage Sync Utility 的技术实现方式**。如果它用的是 Mac 端的 Accessibility API 或 Screen Time API，Echo 或许也能做。 | P1 |
| 3 | **关注 Close 的 Chloe 定价趋势**。如果他们出 $20/月的 solo 计划，立即加速 Echo B2B 的 AI 代理功能。 | P1 |
| 4 | **Onboarding 中加 "Connect Calendar" 引导**（对标 Close 的自动日程集成） | P0 |
