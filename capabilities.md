# Dibsly — 配置文档

生成时间：2026-11-08

---

## 一、⚠️ 手动配置（增强功能 — 不配置不影响基本使用）

> **重要说明**：以下配置项均为**增强功能**。不配置这些项，App 下载后仍可正常使用全部核心功能（浏览、发布、Dibs 认领、聊天、信任分、Wanted、安全见面、分享卡）。配置后可获得更好的上线体验。

### 🟡 iCloud / CloudKit（跨设备社区数据）

**增强功能**：让不同用户的免费物品帖、认领状态与聊天通过 CloudKit 公共库互通。
**不配置的影响**：App 自动退回本地 SwiftData 单机模式，地图、发布、Dibs、聊天、My Hauls、Wanted 全部照常工作，只是看不到其他设备的数据。
**当前状态**：App 已实现优雅降级，未配置时不崩溃、不阻塞任何核心流程。

**已自动配置部分**：
- ✅ Xcode entitlements 已写入 `com.apple.developer.icloud-container-identifiers`（`iCloud.com.zzoutuo.Dibsly`）与 CloudKit 服务
- ✅ 代码已实现 CloudKit 公共库发布、认领冲突检测、聊天同步
- ✅ 真机签名已验证通过（`Signing Identity: Apple Development: he zhou`）

**如需启用增强功能，请手动配置**：
1. 打开 [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. 选择容器 `iCloud.com.zzoutuo.Dibsly`
3. 先用 Xcode 真机运行一次 App（Debug），让 `DibsItem`、`DibsMessage` 两个 Record Type 自动生成
4. 进入 **Deploy Schema Changes**，把 Development 环境部署到 **Production**
5. ⚠️ 完成后再打包上架；Schema 未部署到 Production 时，TestFlight/正式版用户的公共库读写会失败（App 仍会本地降级，不会崩溃）

---

### 🔵 IAP StoreKit（订阅与 AI Credits）

**影响功能**：不创建 IAP 产品，用户无法完成 Pro 订阅、终身买断与 AI Credits 购买（其余功能不受影响）。

**配置步骤**：
1. 登录 [App Store Connect](https://appstoreconnect.apple.com) → 你的 App → **Monetization** → **Subscriptions**
2. 创建订阅组：Reference Name = `Dibsly Pro`
3. 按 `price.md` 创建以下产品（Product ID 必须逐字一致）：

| 产品 | Reference Name | Product ID | 价格 | 类型 |
|------|----------------|-----------|------|------|
| 月付 | Dibsly Pro Monthly | `com.zzoutuo.Dibsly.pro.monthly` | $4.99/月 | 自动续期订阅（7 天免费试用） |
| 年付 | Dibsly Pro Annual | `com.zzoutuo.Dibsly.pro.yearly` | $34.99/年 | 自动续期订阅 |
| 终身 | Dibsly Pro Lifetime | `com.zzoutuo.Dibsly.pro.lifetime` | $59.99 一次性 | 非消耗型 |
| 100 Credits | Dibsly AI Credits 100 | `com.zzoutuo.Dibsly.credits.100` | $2.99 | 消耗型 |
| 500 Credits | Dibsly AI Credits 500 | `com.zzoutuo.Dibsly.credits.500` | $9.99 | 消耗型 |

4. 每个产品填写 Display Name 与 Description（直接复制 `price.md`，均 ≤ 35 / ≤ 55 字符）
5. 月付与年付需在订阅组内配置 **7 天 Introductory Offer**（Free Trial）
6. ⚠️ 产品创建后状态为 "Missing Metadata" 时不会出现在沙盒，补齐审核截图后变为 "Ready to Submit"
7. 本地测试（可选）：Xcode → File → New → StoreKit Configuration File，把上面 5 个产品写入，并在 Scheme → Run → Options 选择该文件

---

### 🟢 App Review 审核信息

**影响功能**：不填写审核备注，审核员可能无法理解 UGC、位置、AI 与订阅的设计，存在被拒风险。

**配置步骤**：
1. App Store Connect → 你的 App → **App Review Information**
2. **Notes** 字段粘贴 `app_review_info.md` 的 "Review Notes" 部分
3. **Demo Account** 留空即可（App 无登录，匿名 Neighbor 直接可用）
4. **Privacy Policy URL** 填 `https://asunnyboy861.github.io/Dibsly/privacy.html`
5. **EULA / Terms** 填 `https://asunnyboy861.github.io/Dibsly/terms.html`
6. 说明：AI 使用 Apple Intelligence 端侧（审核设备 iPhone 15 Pro+ 可直接体验），也可在 App 内 Settings → AI 填自己的 Key；云 AI 需 Pro/credits 或自带 Key

---

### 🟣 CloudKit 容器注册（仅当 Archive 报缺容器时）

**已自动配置部分**：Xcode 自动签名通常已注册 `iCloud.com.zzoutuo.Dibsly`。
**如 Archive 报 "container not found"**：
1. 打开 [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list/cloudContainer)
2. **iCloud Containers** → **+** → 输入 `iCloud.com.zzoutuo.Dibsly`
3. 回到 Xcode，重新 `-allowProvisioningUpdates` 构建

---

## 二、✅ 自动配置记录（已由系统完成，无需操作）

### Capabilities 自动配置

| Capability | 说明 | 状态 |
|------------|------|------|
| Location Services | `NSLocationWhenInUseUsageDescription`，仅使用期间定位 | ✅ 已配置 |
| Camera | `NSCameraUsageDescription`，拍摄发布照片 | ✅ 已配置 |
| Photo Library | `NSPhotoLibraryUsageDescription`，选择发布照片 | ✅ 已配置 |
| iCloud / CloudKit | entitlements 三键 + 公共库服务 | ✅ 已配置 |
| In-App Purchase | StoreKit 2 代码路径，5 个 Product ID | ✅ 已配置 |
| Background Modes | `UIBackgroundModes = remote-notification`（CloudKit 推送要求） | ✅ 已配置 |
| Local Notifications | UserNotifications 授权与本地提醒 | ✅ 已配置 |
| 签名 Team | `DEVELOPMENT_TEAM = JP4TN5PTS3`（项目级，所有 target 继承） | ✅ 已配置 |
| Privacy Manifest | `PrivacyInfo.xcprivacy`（UserDefaults、文件时间戳、粗粒度位置、照片、用户内容） | ✅ 已配置 |

### AI 与密钥

| 项目 | 说明 | 状态 |
|------|------|------|
| Apple Intelligence | iOS 26+ 端侧 Foundation Models，免费无限，`@available` 守卫 | ✅ 已接入 |
| 本地规则兜底 | 无 AI 时仍可生成标题/分类/估价/审核结论，任何按钮都不会走到死路 | ✅ 已接入 |
| GLM 云代理 | 白名单已注册 `appId=dibsly` / `bundleId=com.zzoutuo.Dibsly`；E2E 200/400/401/405 通过 | ✅ 已接入 |
| 开发期 devKey | 只存在于本机 `Dibsly/GLMProxySecret.txt`（已 gitignore），Release 构建自动排除 | ✅ 已隔离 |
| 生产凭证 | StoreKit 2 订阅 JWS（`result.jwsRepresentation`），无需分发共享密钥 | ✅ 已实现 |
| BYO Key | Settings → AI 支持 GLM/OpenAI 兼容/DeepSeek/Gemini/Claude/自定义，Key 存 Keychain | ✅ 已实现 |

### 后端与用户支持

| 服务 | 说明 | 状态 |
|------|------|------|
| 联系客服后端 | `https://msg.calcs.top/api/feedback`，5 字段 + 7 主题磁贴 | ✅ 已对接 |
| 网络权限 | HTTPS 出站默认允许，无需 ATS 例外 | ✅ 已配置 |
| 政策页 | Landing / Support / Privacy / Terms 已部署 GitHub Pages（4 个 URL 均 200） | ✅ 已部署 |

### 代码与质量

| 模块 | 说明 | 状态 |
|------|------|------|
| 核心功能 | SwiftUI + MVVM + SwiftData，17 个功能全部实现 | ✅ 已完成 |
| 原子认领 | 幂等 `clientUUID` + CloudKit `ifServerRecordUnchanged` 冲突检测 | ✅ 已完成 |
| 信任分 | 双向确认 +3/+2，鸽子 -5，诈骗 -20，四级徽章 | ✅ 已完成 |
| 分享卡 | ImageRenderer 9:16 卡片 + 系统分享 | ✅ 已完成 |
| 单元测试 | 13 个测试覆盖发布、审核、认领、双向确认、信任、Wanted、Geohash | ✅ 13/13 通过 |
| 界面测试 | Nearby/Wanted/Post/Hauls/Profile/Settings/AI/Contact/Paywall 全跑通 | ✅ 通过 |
| iPhone / iPad 构建 | iPhone 16（iOS 26.4）与 iPad Pro 13（iOS 26.4）均 BUILD SUCCEEDED | ✅ 通过 |

### 💡 使用提示（非开发者配置，App 内操作即可）

**AI**：默认 Apple Intelligence；不支持时自动使用本地规则，或用户在 **Settings → AI** 填自己的 Key。云 AI 消耗 credits 或订阅 / 自带 Key，端侧 AI 永不消耗 credits。

**通知**：首次 Dibs 成功后才请求通知权限，可随时在 Settings 关闭。

---

## 三、能力检测详情

### Analysis

| Requirement | Keywords found in guide / us.md | Capability |
|---|---|---|
| 附近免费物品地图 | "地图" / "定位" / "map" / "near me" | Location Services（使用期间） |
| 拍照发布 | "拍照" / "photo" / "camera" | Camera + Photo Library |
| 社区数据互通 | "Realtime 订阅" / "同步" | iCloud / CloudKit（公共库） |
| Dibs 提醒、超时释放、匹配 | "推送" / "Time Sensitive" | 本地通知（无远程推送服务器） |
| Pro 订阅 + AI Credits | "订阅" / "IAP" / "credits" | In-App Purchase（StoreKit 2） |
| 图片管线与分享卡 | "图片" / "share" | 文件系统（Application Support / caches） |
| AI 审核 / 估价 / Wanted | "GLM" / "Apple Intelligence" / "BYO" | Apple Intelligence + GLM 共享 Worker + BYO Key |

### No Configuration Needed

- Sign in with Apple（未使用：匿名本地身份，首屏零摩擦）
- HealthKit、Siri、App Groups、Watch（本产品不需要）
- 远程推送证书（仅本地通知）
- 后台刷新任务（计时器都在前台/本地）

### Verification

- Debug 构建：✅ iPhone 16（iOS 26.4）/ iPad Pro 13（iOS 26.4）BUILD SUCCEEDED
- Release 真机构建与签名：✅ `Apple Development: he zhou (VX3Q75X27B)` + BUILD SUCCEEDED
- GLM E2E：✅ 200（content "OK"）、400、401、405
- Release 包密钥排除：✅ Release 产物无 `GLMProxySecret.txt`，Debug 产物包含
- GitHub Pages：✅ built，Landing / privacy 均返回 200
- 单元测试：✅ 13/13
