# Firebase Setup Guide for EnergySmart Admin Chat System

This guide will help you set up Firebase for the EnergySmart Admin Chat Support System.

## 🔥 Firebase Project Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `energysmart-admin-chat`
4. Enable Google Analytics (optional)
5. Click "Create project"

### 2. Enable Authentication

1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable the following providers:
   - **Email/Password**: Enable
   - **Google**: Enable (configure OAuth consent screen)

### 3. Create Firestore Database

1. Go to **Firestore Database**
2. Click "Create database"
3. Choose "Start in test mode" (we'll update rules later)
4. Select your preferred location
5. Click "Done"

### 4. Set up Firebase Storage

1. Go to **Storage**
2. Click "Get started"
3. Choose "Start in test mode"
4. Select same location as Firestore
5. Click "Done"

### 5. Enable Cloud Messaging

1. Go to **Cloud Messaging**
2. Click "Get started"
3. No additional setup needed for now

## 📱 Flutter App Configuration

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### 4. Configure Firebase for Flutter

Run this command in your project root:

```bash
flutterfire configure
```

- Select your Firebase project
- Choose platforms: Android, iOS, Web
- This will generate `firebase_options.dart`

### 5. Android Configuration

#### Add to `android/app/build.gradle`:

```gradle
android {
    compileSdk 34
    
    defaultConfig {
        minSdkVersion 21  // Required for Firebase
        targetSdkVersion 34
        multiDexEnabled true
    }
}

dependencies {
    implementation 'com.android.support:multidex:1.0.3'
}
```

#### Add to `android/build.gradle`:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

#### Add to `android/app/build.gradle` (bottom):

```gradle
apply plugin: 'com.google.gms.google-services'
```

### 6. iOS Configuration

#### Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_REVERSED_CLIENT_ID` with the value from `GoogleService-Info.plist`.

## 🔐 Security Rules Setup

### 1. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 2. Storage Rules

Create `storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Chat images and files
    match /chat_images/{chatId}/{fileName} {
      allow read, write: if request.auth != null 
                        && isParticipantInChat(chatId);
    }
    
    match /chat_files/{chatId}/{fileName} {
      allow read, write: if request.auth != null 
                        && isParticipantInChat(chatId);
    }
    
    function isParticipantInChat(chatId) {
      return request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
    }
  }
}
```

Deploy storage rules:

```bash
firebase deploy --only storage
```

## 👥 User Management

### 1. Create Admin Users

You can create admin users in several ways:

#### Option A: Firebase Console
1. Go to **Authentication** > **Users**
2. Click "Add user"
3. Enter email and password
4. After creation, go to **Firestore Database**
5. Create document in `users` collection:

```json
{
  "id": "USER_UID",
  "name": "Admin Name",
  "email": "admin@example.com",
  "role": "admin",
  "createdAt": "2024-01-01T00:00:00Z",
  "lastSeen": "2024-01-01T00:00:00Z",
  "isOnline": false
}
```

#### Option B: Using the App
Use the `createTestAdmin` method in development:

```dart
final authService = FirebaseAuthService();
await authService.createTestAdmin(
  email: 'admin@energysmart.com',
  password: 'securePassword123',
);
```

### 2. Create Regular Users

Regular users should have `role: "user"` in their Firestore document.

## 🔔 Push Notifications Setup

### 1. Android Setup

#### Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<application>
    <!-- Firebase Messaging Service -->
    <service
        android:name=".java.MyFirebaseMessagingService"
        android:exported="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
    
    <!-- Default notification channel -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="high_importance_channel" />
</application>
```

### 2. iOS Setup

#### Add to `ios/Runner/AppDelegate.swift`:

```swift
import Firebase
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    UNUserNotificationCenter.current().delegate = self
    
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: {_, _ in })
    
    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 📊 Firestore Indexes

### Required Composite Indexes

Create these indexes in Firebase Console > Firestore Database > Indexes:

1. **Chats Collection**:
   - Collection ID: `chats`
   - Fields: `participants` (Array), `lastMessageTime` (Descending)

2. **Messages Subcollection**:
   - Collection ID: `messages`
   - Fields: `chatId` (Ascending), `timestamp` (Descending)

### Auto-generated Indexes

These will be created automatically when you first query:
- Single field indexes for all fields used in queries

## 🧪 Testing the Setup

### 1. Test Authentication

```dart
final authService = FirebaseAuthService();

// Test email/password sign in
try {
  final user = await authService.signInWithEmailAndPassword(
    email: 'admin@test.com',
    password: 'password123',
  );
  print('Signed in: ${user?.name}');
} catch (e) {
  print('Sign in error: $e');
}
```

### 2. Test Chat Creation

```dart
final chatService = FirebaseChatService();
await chatService.initialize();

// Create a test chat
final chatId = await chatService.createChat(
  userId: 'user123',
  subject: 'Test Support Request',
  priority: ChatPriority.normal,
);

// Send a test message
await chatService.sendMessage(
  chatId: chatId,
  text: 'Hello, this is a test message!',
);
```

## 🚀 Deployment Checklist

### Before Production:

1. **Update Firestore Rules**: Change from test mode to production rules
2. **Update Storage Rules**: Ensure proper security
3. **Set up Cloud Functions**: For advanced notifications (optional)
4. **Configure App Check**: For additional security
5. **Set up Monitoring**: Enable Firebase Performance and Crashlytics
6. **Backup Strategy**: Set up Firestore backups

### Environment Variables:

Create different Firebase projects for:
- Development
- Staging  
- Production

## 🔧 Troubleshooting

### Common Issues:

1. **"Permission denied" errors**: Check Firestore rules
2. **Authentication not working**: Verify Firebase configuration
3. **Messages not syncing**: Check internet connection and Firestore rules
4. **Push notifications not working**: Verify FCM setup and permissions

### Debug Commands:

```bash
# Check Firebase project
firebase projects:list

# Test Firestore rules
firebase firestore:rules:test

# View logs
firebase functions:log
```

## 📚 Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [Cloud Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)

---

## 🎯 Quick Start Commands

After setting up Firebase project:

```bash
# 1. Configure Firebase
flutterfire configure

# 2. Install dependencies
flutter pub get

# 3. Deploy rules
firebase deploy --only firestore:rules,storage

# 4. Run the app
flutter run
```

Your Firebase chat system should now be ready! 🚀
