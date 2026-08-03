# Echo Pro StoreKit 配置

这轮代码已经接入 StoreKit 2，产品 ID 固定为：

- `com.bambi2008.echo.ai.pro.monthly` — 月订阅，建议价格 US$3.99/月
- `com.bambi2008.echo.ai.pro.annual` — 年订阅，建议价格 US$29.99/年

两档订阅共用一个 subscription group，并配置 7 天免费试用。订阅页已经展示：

- 试用时长
- 试用结束后的续费说明
- 当前价格与周期
- Restore Purchases
- 账户入口
- Apple ID 设置中的管理/取消说明

## 模拟器验收

当前 Debug 模拟器没有绑定 App Store Connect 商品时，Echo Pro 页面会明确提示 StoreKit 商品尚未连接，并提供“Preview AI Pro on this simulator”。这个入口只在 Debug 构建出现，不会进入正式包，也不会触发真实扣费。

## 上架前

1. 在 App Store Connect 创建以上两个自动续期订阅。
2. 为它们配置同一个订阅组、7 天 introductory offer 和各地区价格。
3. 在 Xcode 的 StoreKit Configuration 或 Sandbox Apple ID 中验证购买、恢复、取消和试用到期路径。
4. 将正式环境的产品可用性作为发布前检查项；若产品不可用，App 仍保留本地关系层，不会阻塞联系人数据。
