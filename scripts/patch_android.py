"""Run in CI after `flutter create`: permissions, app name, minSdk (no ads)."""
import pathlib, re

m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
t = m.read_text()
t = re.sub(r'android:label="[^"]*"', 'android:label="PixelCompress"', t, count=1)
perms = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>\n'
)
t = t.replace('<application', perms + '    <application', 1)
m.write_text(t)

for name in ('build.gradle.kts', 'build.gradle'):
    f = pathlib.Path('android/app') / name
    if f.exists():
        s = f.read_text()
        s = re.sub(r'minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion', 'minSdk = 24', s)
        f.write_text(s)

print('Patched Android project (no ads).')
print(m.read_text())
