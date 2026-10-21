# App Store product page optimization

Last updated: 2026-10-20

### 2026-10-21 release preparation

Re-captured six unmodified 1320×2868 iPhone 17 Pro Max screenshots from the
1.3.8 app source: Today, practice, Progress, privacy settings, Pro comparison,
and optional course catalog. Replaced the five older composed screenshots;
their previous versions remain recoverable in Git. The screenshot UI test
passes, including waiting for the course sheet to finish appearing. Sample
history is DEBUG-only seeded data, not a real user's health history. The Chinese
public store's one-time IAP price was rechecked as CNY 12 on this date.
The original marketing composition script/assets are historical and must not
be run over these captures without refreshing their source images first.

Added version-specific review notes to the release lane and updated What's New.
Application source is unchanged from beta-v1.3.8; only tests, store assets and
release metadata changed. Submission result will be recorded after the workflow.

## Current ASO revision (supersedes the historical plan below)

Status: prepared in source control; not uploaded, submitted, or live.

Apple's China lookup API for `com.zhangyangbin.NextTime` currently returns
**NextTime 1.3.5**, App ID **6757946762**, Health & Fitness, and the old
24-course/four-route description. The latest internal build is 1.3.8.
Do not publish personal-training copy onto the older live binary.

| Field | New copy | Characters |
| --- | --- | --- |
| Name | 下一次 NextTime：凯格尔与盆底肌训练 | 22/30 |
| Subtitle | 每日个人练习，呼吸放松与6周渐进计划 | 18/30 |
| Keywords | Kegel,提肛,收紧,协调,身体觉察,语音引导,震动提示,打卡,习惯,隐私 | 38/100 |

Keywords also fit within 100 UTF-8 bytes (86 bytes). Preserve both brand names,
target relevant practice intent, and avoid repeating title/subtitle phrases.
These are functional relevance hypotheses, not measured search-volume or
ranking findings. Chinese tokenization and actual discoverability need
post-release observation. Removed unsupported postpartum-recovery positioning;
do not promise treatment, sexual performance improvements, or clinical results.

The description now explains today's practice, the optional course list,
18 personal practices, 3 free introductions and 15 Pro practices. It explicitly
states that a daily recommendation may require Pro. Promotional copy explains
the value and one-time purchase, rather than stuffing search terms.

`name.txt` is now wired into the formal `release` lane, alongside existing
subtitle and keywords. Name availability remains subject to App Store Connect
validation. README now links to https://apps.apple.com/cn/app/id6757946762.

### Release gate

- Submit all new metadata with the next formal personal-training app version.
- Do not run the legacy `store_metadata` / `edit_live` lane for this new copy.
  Its historical claim below that the entire description can simply be changed
  on the live version is not a reliable publication procedure.
- Existing screenshots are 1.3.6 assets, not newly captured in this revision.
  Check them against 1.3.8 before submission, particularly optional course
  browsing, Pro benefits, short cues, and region-specific price claims.
- After approval, verify the public name, version, description, screenshots
  and category. TestFlight upload does not publish store metadata.

### Measurement

Export the preceding 14 days from App Store Connect before release. Fix the
territory to mainland China and source to App Store Search. Record impressions,
product-page views, first-time downloads and Apple's conversion metric.
Record any Apple Ads activity, since search-source reporting may include ads.
No account analytics were accessed in this revision; baseline is still pending.
The user's reported 24 downloads / 2 purchases are not search attribution and
are too small a sample to forecast acquisition economics.

Observe the same metrics for 14 days after release (28 if volumes remain low),
comparing matching weekdays. Avoid changing keywords daily. If impressions
increase without downloads, inspect positioning and the first three screenshots;
if impressions stay flat, revisit keyword relevance and actual search visibility.
A whole-page update cannot isolate the effect of an individual word.
Track purchases separately without inventing source attribution. Do not add
tracking SDKs, buy reviews, or reward positive reviews.

Sources:
- https://developer.apple.com/app-store/search/
- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- https://developer.apple.com/app-store/review/guidelines/

## Historical 2026-10-14 plan (superseded)

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
