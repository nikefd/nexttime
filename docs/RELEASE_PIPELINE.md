# NextTime release pipeline

The repository contains three GitHub Actions workflows:

- `iOS CI`: tests every pull request and every push to `main`.
- `Bootstrap iOS Signing`: manually creates or repairs the encrypted Match signing assets.
- `Publish TestFlight`: publishes manually or when a `beta-vX.Y.Z` tag is pushed.
- `Submit App Store Release`: manually builds a version, submits it for App Review, and releases it automatically after approval.

## One-time Apple setup

1. Confirm that `com.zhangyangbin.NextTime` exists in App Store Connect.
2. In App Store Connect, open **Users and Access → Integrations → App Store Connect API**.
3. Create a Team API key with the least role that can upload builds and submit releases. Download the `.p8` file immediately; Apple only permits one download.
4. Create a private GitHub repository to hold Fastlane Match signing assets.
5. After saving the GitHub secrets, run **Bootstrap iOS Signing** once. This creates the distribution certificate and provisioning profile used by CI and stores their encrypted forms in the private Match repository.

## GitHub environments and secrets

Create two GitHub environments:

- `testflight`
- `app-store-production`

Add a required reviewer to `app-store-production` so a production submission always has an explicit approval gate.

Add these secrets to both environments (or as repository secrets):

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID |
| `ASC_KEY_CONTENT` | Base64-encoded contents of the downloaded `.p8` file |
| `MATCH_GIT_URL` | SSH URL of the private Match repository |
| `MATCH_PASSWORD` | Strong password used to encrypt Match assets |
| `MATCH_GIT_PRIVATE_KEY` | Private half of a write-enabled deploy key scoped to the Match repository |

Generate the encoded Apple key locally without printing it into shell history:

```bash
base64 < AuthKey_ABC123.p8 | tr -d '\n'
```

## Publishing

To publish a TestFlight build automatically from a tag:

```bash
git tag beta-v1.1.0
git push origin beta-v1.1.0
```

You can also run **Publish TestFlight** from the GitHub Actions page and supply a version and release notes.

For production, run **Submit App Store Release** manually and enter the new version. GitHub pauses at the `app-store-production` environment when required reviewers are configured. After approval, Fastlane uploads the binary and submits it for App Review. Apple releases the version automatically after it passes review.

App Store Connect must already contain all required metadata, screenshots, privacy answers, export-compliance answers, agreements, and in-app purchase review information. Apple can reject or block a submission when any of these are incomplete.
