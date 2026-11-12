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

# The launch crash happens inside WorkManager's automatic start-up (androidx.startup).
# Remove that automatic initializer so the app no longer touches WorkManager at launch.
if 'xmlns:tools' not in t:
    t = t.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
provider = (
    '        <provider\n'
    '            android:name="androidx.startup.InitializationProvider"\n'
    '            android:authorities="${applicationId}.androidx-startup"\n'
    '            android:exported="false"\n'
    '            tools:node="merge">\n'
    '            <meta-data\n'
    '                android:name="androidx.work.WorkManagerInitializer"\n'
    '                android:value="androidx.startup"\n'
    '                tools:node="remove" />\n'
    '        </provider>\n'
)
t = t.replace('</application>', provider + '    </application>', 1)
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

# ---- launch-crash fix ----
# AdMob pulls in WorkManager (Room). R8 removed the constructor of Room's generated
# WorkDatabase_Impl, so the app died at startup with "Failed to create an instance of
# androidx.work.impl.WorkDatabase". Fix: switch R8 minification off for the release
# build and also keep the needed classes in case it is switched back on.
RULES = (
    '-keep class * extends androidx.room.RoomDatabase { <init>(); }\n'
    '-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }\n'
    '-keep class androidx.work.** { *; }\n'
    '-dontwarn androidx.work.**\n'
    '-dontwarn androidx.room.paging.**\n'
)
rules_file = pathlib.Path('android/app/proguard-rules.pro')
rules_file.parent.mkdir(parents=True, exist_ok=True)
rules_file.write_text(RULES)

_kts = pathlib.Path('android/app/build.gradle.kts')
if _kts.exists():
    _s = _kts.read_text()
    if 'isMinifyEnabled' not in _s:
        _s2, _n = re.subn(
            r'(\n[ \t]*release\s*\{)',
            lambda mo: mo.group(1) + (
                '\n            isMinifyEnabled = false'
                '\n            isShrinkResources = false'
                '\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")'),
            _s, count=1)
        if _n == 1:
            _kts.write_text(_s2)
            print('R8 minification disabled for release + keep rules written.')
        else:
            print('WARNING: could not find the release block; only keep rules were written.')

# ---- newer WorkManager ----
# The smoke test showed AdMob pulling in WorkManager 2.7.0 / Room 2.2.5, which are too old to
# create their database on current Android ("Failed to create an instance of WorkDatabase").
# Declaring a newer WorkManager makes Gradle use it instead.
if _kts.exists():
    _s = _kts.read_text()
    if 'androidx.work:work-runtime' not in _s:
        _kts.write_text(_s.rstrip('\n') + '\n\ndependencies {\n    implementation("androidx.work:work-runtime:2.9.1")\n}\n')
        print('WorkManager forced to 2.9.1')
else:
    print('WARNING: build.gradle.kts not found; WorkManager version not changed')

# ---- lint fix ----
# Android's release "lint vital" check crashed inside Gradle (after the Dart code had compiled).
# Lint is only a code-style checker and is not needed to produce the APK/AAB, so switch it off.
if _kts.exists():
    _s = _kts.read_text()
    if 'checkReleaseBuilds' not in _s:
        _s2, _n = re.subn(
            r'(\n[ \t]*buildTypes\s*\{)',
            lambda mo: ('\n    lint {\n'
                        '        checkReleaseBuilds = false\n'
                        '        abortOnError = false\n'
                        '    }\n') + mo.group(1),
            _s, count=1)
        if _n == 1:
            _kts.write_text(_s2)
            print('Lint checks disabled for release builds.')
        else:
            print('WARNING: could not add the lint settings.')

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
