#!/usr/bin/env bash
# Runs inside an Android emulator on GitHub Actions: installs the APK, opens
# the app, and reports whether it survived (or the crash log if it did not).
PKG=com.alaa.pixelcompress

adb install -r apk/app-release.apk
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 25

if adb shell ps -A | grep -q "$PKG"; then
  echo "=============================================="
  echo "SMOKE TEST RESULT: OK - the app is still running after 25 seconds"
  echo "=============================================="
  RESULT=0
else
  echo "=============================================="
  echo "SMOKE TEST RESULT: FAILED - the app crashed or closed"
  echo "=============================================="
  RESULT=1
fi

echo "---- crash-related log lines ----"
adb logcat -d | grep -E "FATAL EXCEPTION|AndroidRuntime|Process: $PKG|MobileAds|GoogleMobileAds|Ads:|flutter" | head -60

exit $RESULT
