# PixelCompress
Flutter photo compressor / resizer / cropper / blur / converter (JPG, PNG, WEBP, HEIC, PDF)
with AdMob banner + interstitial ads. Built to APK by GitHub Actions - no Android Studio needed.

## Quick start
1. Create a new GitHub repository (private or public).
2. Upload everything in this folder (keep `.github/workflows/build-apk.yml`).
3. Open the **Actions** tab -> **Build Android APK** -> wait ~5-8 minutes for the green check.
4. Open the finished run -> **Artifacts** -> download **PixelCompress-APK** (zip) -> unzip -> install `app-release.apk`.

## Enable real ads
Edit only `lib/config/ad_config.dart`: paste your AdMob App ID + two ad unit IDs, set `kUseTestAds = false`, commit.
