# NextTime App Review 提交说明

适用版本：1.3.x  
准备日期：2026-10-12  
状态：可复制到 App Store Connect；提交前按实际构建复核。

## English review notes (copy-ready)

NextTime is a wellness education and guided-practice app for adults aged 18 and over. It supports pelvic-floor contraction and relaxation, body awareness, and respectful partner communication. It does not diagnose, treat, prescribe, or claim guaranteed improvement of any medical or sexual condition.

No account or demo credentials are required. On first launch, the reviewer will see adult-age, safety, and local-privacy disclosures. Confirm the disclosures, optionally select goals, and the app generates a seven-day starter plan. The five tabs are Today, Practice, Progress, Learn, and Settings.

All practice history, optional check-ins, goals, and partner-card progress remain on the device in an iOS Data Protection-protected local store that is excluded from backup. The app has no developer backend, cloud sync, third-party analytics, advertising, HealthKit, location, camera, microphone, or AI service. Face ID / Touch ID app lock and reminders are optional. Sensitive notification wording is hidden by default. All local records can be erased from Settings → Data → Clear All Data.

Digital Pro features use Apple In-App Purchase. Core safety information, basic practice, and data deletion are available without purchase. Partner cards are used on the same device and do not connect two accounts or transmit messages.

- Safety information: https://nikefd.github.io/nexttime-site/safety_en.html
- Privacy policy: https://nikefd.github.io/nexttime-site/privacy_en.html
- Terms: https://nikefd.github.io/nexttime-site/terms_en.html
- Sources and content-review status: https://nikefd.github.io/nexttime-site/sources_en.html
- Support: https://nikefd.github.io/nexttime-site/support_en.html

## 提交前 App Store Connect 核对

- 年龄分级问卷按实际内容回答；产品主动限制为 18+，在允许的市场使用更高年龄覆盖设置。
- App Privacy 按实际实现选择“开发者不收集数据”；如之后加入诊断、分析或后端，先重新评估。
- 医疗器械状态：按当前非诊断、非治疗的生活方式定位，建议选择“不是受监管医疗器械”；这不是法律意见，内容或市场变化后需重新确认。
- Privacy Policy URL 使用 `/privacy_en.html`（或 App Store Connect 对应本地化页面）。
- Support URL 使用 `/support_en.html`。
- 审核备注中的功能路径、IAP 商品、版本号和 URL 必须与提交构建一致。
- 不要声称“医学认证”或“专业审阅完成”，除非 `CONTENT_REVIEW.md` 已有真实、可验证记录。

## Apple 依据

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)：健康准确性、敏感数据隐私和完整审核信息。
- [Provide information for a complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review)：受众、变化、测试路径与外部服务说明。
- [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)：年龄问卷与更高年龄覆盖设置。
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)：隐私政策 URL 与数据收集披露。
- [Declare regulated medical device status](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status/)：健康类 App 的医疗器械状态声明。

