# Dosti app (Flutter)

Mobile app for the Dosti backend (`dosti-backend-updated.zip`). Android first.

## One-time setup

Run these inside this folder. Existing files (`lib/`, `test/`, `pubspec.yaml`, the debug
manifest) are kept; Flutter only adds the missing Android project files.

```bash
flutter create --org com.yourname --project-name dosti_app --platforms=android .
flutter pub get
```

Change `com.yourname` to your own reverse-domain id **now** (for example `com.rahul.dosti`).
It becomes the permanent app id on the Play Store, `com.example` is rejected, and it is painful to
change later.

Check that `android/app/src/debug/AndroidManifest.xml` still contains
`android:usesCleartextTraffic="true"` after `flutter create`. If it was replaced, put it back, otherwise
the app cannot talk to a backend running on your computer over plain `http://`.

## Run on your phone

1. Start the backend on your computer (`npm start` in the backend folder).
2. Phone and computer on the **same WiFi**, USB debugging on, phone plugged in.
3. Find your computer's WiFi IP (`ipconfig` on Windows, `ifconfig` / `ip a` elsewhere), e.g. `192.168.1.5`.
4. Run:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
```

On the login screen press **Test server connection**. It should say
`Server reachable` with MongoDB OK. If it fails, the message tells you why
(wrong IP, firewall, backend not running).

Android emulator instead of a phone: no flag needed, the default `http://10.0.2.2:3000` reaches your computer.

If the Windows firewall blocks it, allow Node.js on private networks, or the phone will time out.

## Tests

```bash
flutter analyze
flutter test
```

## Build and test on GitHub (no Flutter on your computer needed)

`.github/workflows/flutter.yml` makes GitHub run `flutter analyze`, `flutter test` and build a debug APK
every time files are uploaded to the repo. Open the repo's **Actions** tab to see the result, and
download the APK from the finished run's **Artifacts** section.

To bake your backend address into that APK: Actions -> "Flutter build and test" -> **Run workflow**
-> type the URL (for example `http://192.168.1.5:3000`).

## Release builds

Release builds refuse to start unless the backend is `https://`:

```bash
flutter build appbundle --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Step 8 adds the release `INTERNET` permission, app icon, signing and the Play Store checklist.

## If the build complains

* **minSdkVersion** error mentioning `flutter_secure_storage`: open `android/app/build.gradle(.kts)`
  and set `minSdk = 23` (or `minSdkVersion 23`).
* **pub get** version conflict: send me the message, the package versions in `pubspec.yaml`
  were written without being able to download them.

## Layout

```
lib/
  main.dart, app.dart          start-up and app widget
  core/
    config/app_config.dart     backend URL (set with --dart-define)
    network/api_client.dart    all HTTP calls: token, errors, auto sign-out
    network/api_exception.dart one error type with user-friendly messages
    session/                   "is the user logged in?" (single source of truth)
    storage/token_store.dart   token kept in encrypted storage
    router/app_router.dart     screens + login redirect
    theme/app_theme.dart
  features/
    splash/  auth/  home/      placeholders now, filled in by the next steps
test/
```
