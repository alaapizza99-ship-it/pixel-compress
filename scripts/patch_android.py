"""Run in CI after `flutter create`: wires AdMob, permissions, app name, minSdk."""
import pathlib, re

cfg = pathlib.Path('lib/config/ad_config.dart').read_text()
app_id = re.search(r"kAdmobAppId\s*=\s*'([^']+)'", cfg).group(1)

m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
t = m.read_text()
t = re.sub(r'android:label="[^"]*"', 'android:label="PixelCompress"', t, count=1)
perms = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n'
    '    <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>\n'
    '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>\n'
)
t = t.replace('<application', perms + '    <application', 1)
meta = ('        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" '
        f'android:value="{app_id}"/>\n')
t = t.replace('</application>', meta + '    </application>', 1)
m.write_text(t)

for name in ('build.gradle.kts', 'build.gradle'):
    f = pathlib.Path('android/app') / name
    if f.exists():
        s = f.read_text()
        s = re.sub(r'minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion', 'minSdk = 24', s)
        f.write_text(s)

print('Patched Android project. AdMob app id:', app_id)
