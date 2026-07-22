# Echo AI 模型切换接口

该模块保持 Echo 原有的 DeepSeek 架构，但移除了业务代码中的模型硬编码。

## 切换优先级

1. 单次请求的 `modelOverride`
2. `AIModelRouter` 中持久化的任务配置
3. 包内默认的 DeepSeek V4 配置

模型 ID 使用开放字符串，不是固定枚举。DeepSeek 发布新模型后，可以立即写入新 ID，无需修改模块代码。

## App 中初始化

```swift
let client = DeepSeekClient {
    guard let key = KeychainManager.get("deepseek_api_key") else {
        throw AIServiceError.noAPIKey
    }
    return key
}

let ai = AIService(client: client)
```

## 修改某个任务的模型

```swift
try await ai.setModel(
    "deepseek-v4-pro",
    for: .salesCoach,
    fallbacks: ["deepseek-v4-flash"]
)
```

任意未来模型同样可用：

```swift
try await ai.setModel(
    AIModelID(rawValue: "deepseek-future-best-model"),
    for: .conversationOpener
)
```

## 单次请求临时指定模型

```swift
let result = try await ai.chat(
    task: .relationshipInsight,
    systemPrompt: "You are Echo.",
    userMessage: prompt,
    modelOverride: "deepseek-v4-pro"
)

print(result.model) // API 实际返回的模型
```

## 远程热更新全部任务

将 `AIModelConfiguration` 的 JSON 放在自有 HTTPS 地址：

```swift
let source = URLModelConfigurationSource(
    url: URL(string: "https://example.com/echo-models.json")!
)
try await ai.refreshModels(from: source)
```

远程配置会先完整校验，再原子替换本地配置。下载或校验失败时继续使用上一次可用配置。

如果新配置效果不佳，可以立即回滚：

```swift
try await ai.rollbackModels()
```

## 旧版本自动迁移

模块读取本地持久化配置时，会自动迁移下列已退役别名：

- `deepseek-chat`
- `deepseek-reasoner`
- `deepseek-vision`

迁移目标由任务类型决定：高频任务默认进入 V4 Flash，复杂推理、销售教练和图片提取默认进入 V4 Pro。任何自定义模型 ID 都会原样保留。

## 回退规则

以下错误会按顺序尝试 fallback：模型不存在、限流、超时、服务端错误、网络失败、空响应和解析失败。

鉴权失败、无 API Key、空图片和本地配置错误不会切换模型，避免无意义请求。

## 图片任务

图片请求同样走任务路由：

```swift
let result = try await ai.analyzeImage(
    jpegData,
    prompt: extractionPrompt,
    task: .businessCardOCR
)
```

模型是否接受图片取决于 DeepSeek 当前接口能力。可以单独调整 `.businessCardOCR` 与 `.policyOCR` 的模型，不影响文字任务。

## 业务功能接入

`EchoAIFeatures` 是现有页面和 `AIService` 之间的薄适配层，不改变 SwiftData、View 或 Service 架构。它提供开场白、关系洞察、关系健康度、名片 OCR、保单 OCR、销售教练和每日简报入口，并自动选择对应的 `AITask`。

```swift
let features = EchoAIFeatures(service: ai)

let opener = try await features.conversationOpener(
    personAlias: "Person A",
    recentNote: anonymizedNote,
    daysSinceContact: 19,
    relationship: "friend"
)
```

传入 `personAlias` 等脱敏字段，真实姓名映射应在设备本地完成。OCR 返回强类型 `BusinessCardInfo` 或 `PolicyDocumentInfo`，不再由页面直接解析松散字典。
