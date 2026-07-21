# Echo — 设计交付物

## B1: App Icon 规格

### 设计稿

```
┌─────────────────────────────┐
│                             │
│          #090A0E             │
│                             │
│           〰️ 〰️              │
│         〰️  〰️  〰️           │
│       〰️    〰️    〰️         │
│         〰️  〰️  〰️           │
│           〰️ 〰️              │
│                             │
│        #3B82F6 蓝色          │
│        SF Pro 圆形           │
│        waveform 波形         │
│                             │
└─────────────────────────────┘
```

### 参数

| 属性 | 值 |
|------|-----|
| 尺寸 | 1024×1024 px |
| 格式 | PNG (无透明) |
| 背景色 | #090A0E |
| 图标 | waveform（SF Symbol `waveform`） |
| 图标色 | #3B82F6 |
| 图标大小 | 约占画布 50% |
| 圆角 | iOS 自动应用系统圆角遮罩 |
| 风格 | 扁平、极简、暗色 |

### 制作方式

**Option A: SF Symbols App（推荐）**
1. 打开 SF Symbols app（Mac）
2. 搜索 "waveform"
3. 导出为 1024×1024 PNG
4. 用 Preview/Photoshop 放在 #090A0E 背景上

**Option B: Figma**
1. 创建 1024×1024 画板
2. 背景 #090A0E
3. 添加 waveform 图标，颜色 #3B82F6
4. 导出 3x PNG

**Option C: AI 生成**
可尝试用 DALL-E / Midjourney 生成，prompt:
```
Minimalist app icon, dark navy background #090A0E, a blue #3B82F6 waveform/soundwave icon, flat design, no text, iOS app icon style, centered, simple geometric shapes
```

---

## B2: Tab Bar 图标选择

### Personal Tab
- **SF Symbol:** `waveform` （代表 Echo/声音/回响）
- **备选:** `person.2.fill`, `heart.fill`
- **推荐:** `waveform` — 和 App Icon 一致，品牌连贯

### AI Tab
- **SF Symbol:** `sparkles` （代表 AI/智能/魔法）
- **备选:** `wand.and.stars`, `brain.head.profile`
- **推荐:** `sparkles` — Apple 原生 AI 功能常用图标

### Business Tab
- **SF Symbol:** `briefcase.fill` （代表工作/商务）
- **备选:** `chart.bar.fill`, `building.2.fill`
- **推荐:** `briefcase.fill` — 直观、通用

### Settings Tab
- **SF Symbol:** `gear` （标准设置图标）

---

## 颜色系统

在 Assets.xcassets 中创建以下 Color Sets（sRGB, 8-bit）：

| 名称 | Hex | 用途 |
|------|-----|------|
| `background` | #090A0E | 主背景 |
| `surface` | #1A1B1F | 卡片、面板背景 |
| `accent` | #3B82F6 | 主色调（按钮、高亮） |
| `textPrimary` | #FFFFFF | 标题、主要文字 |
| `textSecondary` | #8E8E93 | 副标题 |
| `textMuted` | #636366 | 时间戳、辅助文字 |
| `hot` | #FF453A | 热线索（B2B） |
| `warm` | #F59E0B | 温线索（B2B） |
| `cold` | #636366 | 冷线索（B2B） |
| `won` | #34C759 | 已成交 |
| `lost` | #8E8E93 | 已丢失 |

---

## 字体

- **全 App:** SF Pro（iOS 系统字体，无需额外配置）
- **标题:** `.largeTitle` (34pt, Bold)
- **卡片名:** `.body` (17pt, Semibold)
- **正文:** `.body` (17pt, Regular)
- **辅助文字:** `.caption` (12pt, Regular)

---

## 间距

遵循 4pt 网格：

| 元素 | 间距 |
|------|------|
| 卡片间距 | 12pt |
| 屏幕边距 | 16pt |
| 卡片内边距 | 16pt |
| 按钮内边距 | 14pt 垂直 |
| 头像大小 | 48pt（卡片）, 80pt（详情） |
