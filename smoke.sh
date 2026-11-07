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

echo "---- library versions inside the APK ----"
for f in androidx.work_work-runtime androidx.room_room-runtime androidx.startup_startup-runtime androidx.sqlite_sqlite com.google.android.gms_play-services-ads com.google.android.gms_play-services-ads-lite; do
  v=$(unzip -p apk/app-release.apk "META-INF/$f.version" 2>/dev/null | tr -d '\n')
  echo "$f = ${v:-not found}"
done

echo "---- is WorkDatabase_Impl present in the APK? (count per dex file) ----"
rm -rf /tmp/dex && mkdir -p /tmp/dex && unzip -o -q apk/app-release.apk 'classes*.dex' -d /tmp/dex
for d in /tmp/dex/*.dex; do echo "$(basename $d): $(grep -c -a 'WorkDatabase_Impl' $d)"; done

echo "---- start of the crash (first lines after FATAL EXCEPTION) ----"
adb logcat -d | grep -A25 "FATAL EXCEPTION" | head -45

echo "---- crash-related log lines ----"
adb logcat -d | grep -E "FATAL EXCEPTION|AndroidRuntime|Caused by|Process: $PKG|MobileAds|GoogleMobileAds|Ads:|flutter" | head -150

exit $RESULT
