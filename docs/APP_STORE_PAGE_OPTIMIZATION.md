# App Store product page optimization

Last updated: 2026-10-14

## Public-page audit

The live 1.3.4 page correctly shows the current release and the CNY 12 one-time
in-app purchase, but its acquisition content predates the local-first wellness
milestones:

- The description still advertises 14 courses instead of the current 24.
- The five screenshots show the legacy dashboard, timer, learning page, and
  settings UI. The first screenshot contains zero activity and none of the
  screenshots explain the six-week plan or privacy model.
- The primary category is Utilities even though the current product is a
  wellness practice app.
- The page has no subtitle that explains the product's benefit.

## Positioning

Primary promise: a privacy-first, six-week pelvic-floor practice plan that
balances contraction with full release.

Proof points:

1. 24 guided courses across four routes.
2. A 42-day plan with recovery days and recent-course avoidance.
3. Natural Chinese and English voice guidance.
4. No account, third-party behavioral analytics, or cloud health profile.
5. Four free foundation courses; one-time Pro unlocks 20 advanced courses and
   the full plan without a subscription.

## Metadata

The source-controlled Simplified Chinese copy lives in
`fastlane/store_metadata/zh-Hans/`.

The `store_metadata` Fastlane lane updates fields Apple allows to be edited on
the live version: description, promotional text, support URL, marketing URL,
and privacy URL. Subtitle, keywords, category, and screenshots should be
applied with the next App Store version.

Recommended next-version settings:

- Subtitle: `6 周渐进盆底训练与放松`
- Primary category: Health & Fitness
- Secondary category: Utilities

## Screenshot sequence

Use five 1242 x 2688 Simplified Chinese screenshots with short, benefit-led
headlines. Avoid medical claims and performance guarantees.

1. `6 周渐进，每天知道练什么` — populated plan home screen.
2. `24 节课程，收缩与放松同样重要` — four practice routes.
3. `自然语音引导，无需一直看屏幕` — guided practice.
4. `无账户、无广告，记录只留在本机` — privacy and app lock.
5. `一次买断 Pro，不订阅` — Pro value page.

Do not reuse the legacy screenshots as final assets. Capture the current UI
from the latest build, with representative local-only sample data and no real
user data.
