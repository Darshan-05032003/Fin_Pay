# Splash Screen Setup Guide

## Option 1: Using flutter_native_splash (Recommended)

### Step 1: Add Package

Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_native_splash: ^2.3.10
```

### Step 2: Configure Splash Screen

Add to `pubspec.yaml`:

```yaml
flutter_native_splash:
  color: "#000000"  # CRED black background
  image: assets/images/splash_logo.png  # Your FinPay logo
  android: true
  ios: false
  android_12:
    image: assets/images/splash_logo.png
    color: "#000000"
```

### Step 3: Generate Splash Screen

Run:
```bash
flutter pub get
dart run flutter_native_splash:create
```

## Option 2: Manual Configuration

### Android Splash Screen

1. Create splash screen drawable: `android/app/src/main/res/drawable/splash_background.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/cred_black" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/ic_launcher" />
    </item>
</layer-list>
```

2. Update `styles.xml` in `android/app/src/main/res/values/styles.xml`:

```xml
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@drawable/splash_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@color/cred_black</item>
    </style>
</resources>
```

3. Add color to `colors.xml`:

```xml
<color name="cred_black">#000000</color>
```

## Recommended Splash Screen Design

- **Background**: Pure black (#000000) matching CRED theme
- **Logo**: FinPay logo centered
- **Duration**: 2-3 seconds
- **Animation**: Fade in logo (optional)

## Assets Needed

1. **Splash Logo**: 512x512px PNG with transparent background
2. **App Icon**: Already exists in `android/app/src/main/res/mipmap-*/`

## Quick Setup (Minimal)

For now, the app uses the default Flutter splash screen. To customize:

1. Create `assets/images/splash_logo.png` (your FinPay logo)
2. Add to `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/images/splash_logo.png
   ```
3. Follow Option 1 or Option 2 above

