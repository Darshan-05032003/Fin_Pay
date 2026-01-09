# Release Keystore Setup Guide

## Step 1: Generate Keystore

Run this command in your terminal (replace with your details):

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important Information:**
- **Keystore password**: Remember this! You'll need it for every release
- **Key password**: Can be same as keystore password
- **Name**: Your name or organization name
- **Organizational Unit**: Your department (optional)
- **Organization**: Your company name
- **City**: Your city
- **State**: Your state/province
- **Country Code**: Two-letter country code (e.g., US, IN)

## Step 2: Create key.properties File

Create a file `android/key.properties` with the following content:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=YOUR_KEYSTORE_PATH
```

**Example:**
```properties
storePassword=MySecurePassword123!
keyPassword=MySecurePassword123!
keyAlias=upload
storeFile=/home/darshan/upload-keystore.jks
```

## Step 3: Update build.gradle.kts

The build.gradle.kts has been updated to use the keystore. You need to:

1. Create `android/key.properties` file (see Step 2)
2. Update `android/app/build.gradle.kts` to load the properties

## Step 4: Add key.properties to .gitignore

**CRITICAL**: Never commit your keystore or key.properties to version control!

Add these lines to `.gitignore`:
```
android/key.properties
*.jks
*.keystore
upload-keystore.jks
```

## Step 5: Backup Your Keystore

**IMPORTANT**: Keep a secure backup of your keystore file. If you lose it:
- You cannot update your app on Play Store
- You'll need to publish a new app with a new package name

**Backup locations:**
- External hard drive
- Secure cloud storage (encrypted)
- Password manager

## Step 6: Test Release Build

After setup, test your release build:

```bash
flutter build appbundle --release
```

Or for APK:
```bash
flutter build apk --release
```

## Troubleshooting

### Error: "Keystore file not found"
- Check the path in `key.properties`
- Use absolute path or path relative to `android/` directory

### Error: "Wrong password"
- Double-check your keystore password
- Make sure there are no extra spaces in `key.properties`

### Error: "Alias does not exist"
- Verify the alias name matches what you used when creating the keystore
- Default alias is "upload"

## Security Best Practices

1. **Never share your keystore** with anyone
2. **Never commit** keystore or key.properties to Git
3. **Use strong passwords** (at least 16 characters)
4. **Store backups securely** (encrypted)
5. **Use different keystores** for different apps

