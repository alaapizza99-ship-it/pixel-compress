"""Run in CI after `flutter create`: permissions, app name, minSdk,
dark launch screen and release signing (uses android/key.properties if present)."""
import pathlib, re, sys

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
print('AdMob app id:', app_id)

for name in ('build.gradle.kts', 'build.gradle'):
    f = pathlib.Path('android/app') / name
    if f.exists():
        s = f.read_text()
        s = re.sub(r'minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion', 'minSdk = 24', s)
        f.write_text(s)

# Dark launch background so there is no white flash before the first frame.
launch = ('<?xml version="1.0" encoding="utf-8"?>\n'
          '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <item><shape android:shape="rectangle">'
          '<solid android:color="#FF12141A"/></shape></item>\n'
          '</layer-list>\n')
for d in ('drawable', 'drawable-v21'):
    f = pathlib.Path('android/app/src/main/res') / d / 'launch_background.xml'
    if f.exists():
        f.write_text(launch)

# ---- release signing ----
# If android/key.properties exists (written by the workflow from GitHub secrets)
# the release build is signed with the upload key; otherwise it falls back to the
# debug key so test builds keep working.
strict = pathlib.Path('android/key.properties').exists()
kts = pathlib.Path('android/app/build.gradle.kts')
ok = False
if kts.exists():
    s = kts.read_text()
    if 'keystoreProperties' not in s:
        imports = 'import java.util.Properties\nimport java.io.FileInputStream\n\n'
        props = (
            'val keystoreProperties = Properties()\n'
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            'if (keystorePropertiesFile.exists()) {\n'
            '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
            '}\n\n'
        )
        block = (
            '    signingConfigs {\n'
            '        create("release") {\n'
            '            if (keystorePropertiesFile.exists()) {\n'
            '                keyAlias = keystoreProperties["keyAlias"] as String\n'
            '                keyPassword = keystoreProperties["keyPassword"] as String\n'
            '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
            '                storePassword = keystoreProperties["storePassword"] as String\n'
            '            }\n'
            '        }\n'
            '    }\n\n'
        )
        s2, n1 = re.subn(r'(\n[ \t]*buildTypes\s*\{)', lambda mo: '\n' + block.rstrip('\n') + mo.group(1), s, count=1)
        s2, n2 = re.subn(
            r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
            'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
            s2)
        # the property loading must come AFTER the plugins {} block, before android {}
        s2, n3 = re.subn(r'(\n)(android\s*\{)', lambda mo: '\n' + props + mo.group(2), s2, count=1)
        if n1 == 1 and n2 >= 1 and n3 == 1:
            kts.write_text(imports + s2)
            ok = True
    else:
        ok = True

if ok:
    print('Signing configured (release key used when key.properties exists).')
elif strict:
    print('ERROR: could not patch release signing into build.gradle.kts')
    sys.exit(1)
else:
    print('WARNING: signing patch not applied (no key.properties, debug-signed build).')

print('Patched Android project.')
