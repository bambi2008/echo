# Echo App Icon — AI 图像生成提示词

> 可以使用 DALL·E 3 / Midjourney / Stable Diffusion / ComfyUI 生成。
> 最终尺寸：1024×1024，导出为 PNG，无透明背景。

---

## Prompt 1: 极简波形（推荐 — 和品牌名一致）

```
A minimalist iOS app icon design. Dark navy background (#090A0E). 
A single, elegant blue (#3B82F6) waveform/soundwave line in the center, 
curving smoothly like an audio echo. Flat design, no gradients, 
no text, no rounded corners (iOS applies them automatically). 
Clean geometric shapes. Professional, premium feel.
```

---

## Prompt 2: 双重波形（"回响"的视觉化）

```
A minimalist iOS app icon. Dark navy (#090A0E) background. 
Two overlapping blue (#3B82F6) waveform lines — one solid, one with 
lower opacity — representing "echo" and "reply." The lines form a 
circular or semi-circular shape in the center. 
Flat design, no text, no gradients. Clean and modern.
```

---

## Prompt 3: 波形 + 点（"一个人 → 回响"）

```
A minimalist iOS app icon. Dark navy background (#090A0E).
On the left, a small blue (#3B82F6) dot (representing a person).
From the dot, expanding blue waveform arcs radiate to the right, 
like ripples in water — representing reaching out and hearing back.
Flat design, clean lines, no text, no gradients.
```

---

## Prompt 4: SF Symbol "waveform" 风格

```
A minimalist iOS app icon. Solid dark navy (#090A0E) background.
A stylized sound waveform made of 5-7 vertical bars in blue (#3B82F6),
ascending in height from left to right then descending — like an 
audio equalizer. The bars are rounded at the top.
Flat design, centered, no text, professional.
```

---

## Prompt 5: 字母 E + 波形

```
A minimalist iOS app icon. Dark navy (#090A0E) background.
The letter "E" formed by a continuous blue (#3B82F6) waveform line.
The top and bottom bars of the "E" are straight, the middle bar 
is a curved sine wave — subtly suggesting both "Echo" and sound.
Flat design, bold line weight, no text other than the letterform itself.
```

---

## 推荐排序

| # | 风格 | 理由 |
|---|------|------|
| 1 | 极简单波形 | 和品牌名 "Echo" 最直接关联。iOS 系统 App 通常只用单一图标。 |
| 3 | 波纹扩散 | "一个人发出声音 → 收到回响" 的视觉叙事。更有故事性。 |
| 5 | 字母 E + 波形 | 品牌识别度高。但字母图标在 App Store 容易被忽略。 |

---

## 生成后处理

1. 用 Preview/Photoshop 裁剪到 1024×1024
2. 确保背景完全是 #090A0E（不要有任何渐变或杂色）
3. 图标元素用 #3B82F6（不要偏紫或偏绿）
4. 导出为 PNG（不透明）
5. 拖入 Xcode → Assets.xcassets → AppIcon

---

## 如果你有 ComfyUI

可以装 `comfyui` skill 直接用工作流生成。推荐用 SDXL + ControlNet 精确控制构图。

或者用 FAL.ai API（更快）：
```python
import fal_client
result = fal_client.subscribe("fal-ai/flux-pro", arguments={
    "prompt": "Minimalist iOS app icon, dark navy #090A0E background, single elegant blue #3B82F6 waveform line in center, flat design, no text",
    "image_size": "square_hd"
})
```
