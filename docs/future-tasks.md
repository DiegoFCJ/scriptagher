# Future Distribution Tasks

This checklist captures the high-level actions required to publish the application in the major consumer app stores and to record the resulting installer metadata. Use it as a starting point for planning more detailed release runbooks.

## Google Play Store
- **Account prerequisites**
  - Enroll in the [Google Play Console](https://play.google.com/console/about/) with an organization or individual developer account and pay the one-time registration fee.
  - Configure merchant profile and tax information if the app offers in-app products or paid distribution.
- **Packaging format**
  - Build an Android App Bundle (`.aab`) that targets the desired device architectures.
  - Generate a signed release bundle with a secure upload key registered in Play Console.
- **Submission steps**
  1. Create a new application entry in Play Console, setting the default language and app name.
  2. Complete the store listing, content rating questionnaire, target audience, and compliance declarations (privacy policy, data safety, ads, etc.).
  3. Upload the signed `.aab` in the **Production** (or desired track) release, add release notes, and review artifact validation results.
  4. Submit the release for review and roll out once approved.
- **Capture store URL**
  - After approval, copy the public store page URL (`https://play.google.com/store/apps/details?id=<packageName>`).
  - Record it under the Android entry in `installers.json` alongside the platform metadata and current version identifier.

## Apple App Store
- **Account prerequisites**
  - Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) with an individual or organization account (annual fee applies).
  - Configure App Store Connect access roles and agree to the latest program license.
  - Set up Certificates, Identifiers & Profiles for distribution signing.
- **Packaging format**
  - Produce an archived iOS build in Xcode and export an `.ipa` signed with a distribution certificate and App Store provisioning profile.
  - Enable the appropriate capabilities (Push, Sign In with Apple, etc.) prior to archiving.
- **Submission steps**
  1. Create the app record in App Store Connect with bundle ID, platform, and pricing schedule.
  2. Upload the `.ipa` via Xcode Organizer or Transporter and wait for processing to complete.
  3. Provide App Store metadata (descriptions, screenshots, keywords, privacy details, app review information) and attach the processed build to a new version.
  4. Submit the version for App Review and monitor the resolution center for feedback.
- **Capture store URL**
  - When the app is approved and released, note the public store URL (`https://apps.apple.com/app/id<appId>`).
  - Store the link in `installers.json` under the iOS platform entry, including the latest version number and build metadata.

## Microsoft Store (Windows)
- **Account prerequisites**
  - Register for a [Microsoft Partner Center](https://partner.microsoft.com/dashboard/account/v3/enrollment/introduction) developer account (one-time fee, varies by country).
  - Verify publisher identity and complete payout/tax information if distributing paid apps or in-app purchases.
- **Packaging format**
  - Package the application as an MSIX bundle (`.msix` or `.msixbundle`) using the Windows App Packaging project or MSIX Packaging Tool.
  - Sign the package with a trusted code signing certificate that matches the Partner Center publisher identity.
- **Submission steps**
  1. Reserve a new app name in Partner Center and configure product details (category, pricing, distribution markets).
  2. Upload the signed MSIX package in the **Packages** section and specify device family targeting, minimum system requirements, and update options.
  3. Complete the Store listings (description, images, age rating) and any required compliance questionnaires.
  4. Submit the product for certification and release it to the chosen distribution channels once approved.
- **Capture store URL**
  - After the product goes live, copy the Microsoft Store listing URL (`https://apps.microsoft.com/detail/<storeId>` or legacy `https://www.microsoft.com/store/apps/<storeId>`).
  - Add the link to the Windows section in `installers.json`, ensuring the Store ID and version metadata align with the published package.

## Updating `installers.json`
- Keep the JSON sorted by platform for readability.
- Include fields such as `platform`, `storeUrl`, `version`, and any architecture-specific notes.
- When a new store release is published, update the relevant entry and commit the change alongside release tags so the web client surfaces the latest links.
