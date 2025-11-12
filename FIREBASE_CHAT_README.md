# 🔥 Firebase Chat Support System for EnergySmart Admin

A complete, production-ready admin chat support system built with Flutter and Firebase, designed specifically for the EnergySmart admin dashboard.

## 🌟 Features

### 💬 Real-time Chat
- **Instant messaging** with Firestore real-time updates
- **File and image sharing** with Firebase Storage
- **Message status tracking** (sent, delivered, seen)
- **Typing indicators** and online status
- **Message threading** and replies

### 👥 Admin-Focused Design
- **Reversed message alignment** (admin messages on right, user messages on left)
- **Role-based authentication** (admin-only access)
- **Chat assignment** to specific admins
- **Priority management** (low, normal, high, urgent)
- **Status tracking** (active, archived, closed)

### 📊 Advanced Features
- **Real-time statistics** and analytics
- **Push notifications** via Firebase Cloud Messaging
- **Responsive design** (mobile and desktop)
- **Professional UI** following EnergySmart design system
- **Comprehensive security** with Firestore rules

## 🏗️ Architecture

### Firebase Services Used
- **Authentication**: Email/password and Google Sign-In
- **Firestore**: Real-time database for chats and messages
- **Storage**: File and image uploads
- **Cloud Messaging**: Push notifications
- **Security Rules**: Role-based access control

### Flutter Packages
- `flutter_chat_ui`: Professional chat interface
- `flutter_chat_types`: Type-safe message handling
- `firebase_core`: Firebase initialization
- `cloud_firestore`: Real-time database
- `firebase_auth`: Authentication
- `firebase_storage`: File storage
- `firebase_messaging`: Push notifications
- `image_picker`: Image selection
- `file_picker`: File selection

## 📁 Project Structure

```
lib/admin/
├── models/
│   └── firebase_chat_models.dart          # Data models
├── services/
│   ├── firebase_chat_service.dart         # Chat functionality
│   └── firebase_auth_service.dart         # Authentication
├── screens/
│   └── firebase_chat_screen.dart          # Main chat UI
└── widgets/
    └── firebase_chat_fab.dart             # Floating action button

firestore.rules                            # Security rules
FIREBASE_SETUP_GUIDE.md                   # Setup instructions
```

## 🚀 Quick Start

### 1. Firebase Setup
Follow the detailed [Firebase Setup Guide](FIREBASE_SETUP_GUIDE.md) to configure your Firebase project.

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
```bash
flutterfire configure
```

### 4. Deploy Security Rules
```bash
firebase deploy --only firestore:rules,storage
```

### 5. Run the App
```bash
flutter run
```

## 💾 Database Structure

### Firestore Collections

#### `users/`
```json
{
  "id": "string",
  "name": "string",
  "email": "string",
  "role": "admin|user",
  "photoUrl": "string?",
  "createdAt": "timestamp",
  "lastSeen": "timestamp",
  "isOnline": "boolean",
  "fcmToken": "string?"
}
```

#### `chats/`
```json
{
  "id": "string",
  "participants": ["userId", "adminId"],
  "lastMessage": "string?",
  "lastMessageTime": "timestamp",
  "createdAt": "timestamp",
  "unreadCount": {
    "userId": "number"
  },
  "subject": "string?",
  "status": "active|archived|closed",
  "priority": "low|normal|high|urgent",
  "assignedAdminId": "string?",
  "metadata": "object?",
  "senderName": "string?",
  "senderEmail": "string?",
  "senderPhotoUrl": "string?"
}
```

#### `chats/{chatId}/messages/`
```json
{
  "id": "string",
  "chatId": "string",
  "senderId": "string",
  "text": "string",
  "timestamp": "timestamp",
  "type": "text|image|file|system",
  "status": "sending|sent|delivered|seen|error",
  "replyToId": "string?",
  "metadata": "object?",
  "attachments": [
    {
      "name": "string",
      "url": "string",
      "size": "number",
      "mimeType": "string"
    }
  ],
  "senderName": "string?",
  "senderEmail": "string?",
  "senderPhotoUrl": "string?"
}
```

## 🔐 Security Rules

The system implements comprehensive security rules:

- **Authentication required** for all operations
- **Role-based access** (admin vs user permissions)
- **Participant-only access** to chat data
- **Sender verification** for message creation
- **Admin-only collections** for sensitive data

## 🎨 UI Components

### Chat Interface
- **Professional chat UI** using flutter_chat_ui
- **Custom theme** matching EnergySmart design
- **Message bubbles** with proper alignment
- **File/image previews** and downloads
- **Status indicators** and timestamps

### Admin Dashboard Integration
- **Floating Action Button** with unread count
- **Statistics card** showing chat metrics
- **Priority indicators** for urgent messages
- **Responsive layout** for all screen sizes

## 📱 Mobile & Desktop Support

### Mobile Features
- **Touch-optimized** interface
- **Image/file picker** integration
- **Push notifications** support
- **Offline capability** with Firestore caching

### Desktop Features
- **Split-pane layout** (chat list + chat view)
- **Keyboard shortcuts** support
- **Drag & drop** file uploads
- **Multi-window** support

## 🔔 Push Notifications

### Setup
- **FCM token management** for each user
- **Background message handling**
- **Notification channels** for different priorities
- **Deep linking** to specific chats

### Notification Types
- **New message** notifications
- **High priority** chat alerts
- **Assignment** notifications for admins
- **Status change** updates

## 📊 Analytics & Statistics

### Real-time Metrics
- **Total chats** count
- **Active chats** monitoring
- **Unread messages** tracking
- **Priority breakdown** analysis
- **Response time** calculations

### Dashboard Integration
- **Statistics cards** on main dashboard
- **Real-time updates** via streams
- **Visual indicators** for urgent items
- **Performance metrics** tracking

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Firebase Emulator
```bash
firebase emulators:start
```

## 🚀 Deployment

### Development
- Use Firebase test project
- Enable debug logging
- Use emulators for testing

### Production
- Configure production Firebase project
- Update security rules
- Enable monitoring and analytics
- Set up backup strategies

## 🔧 Configuration

### Environment Variables
Copy `env.example` to a `.env` file and populate the required values before running the app.

- `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `CLOUDINARY_UPLOAD_PRESET` *(optional – only needed if you override the hardcoded defaults)*
- `NOTIFICATION_ICON_URL` (public URL to `assets/icon/update_icon.png`, e.g. upload to Cloudinary)
- Optional overrides: `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY`, `ONESIGNAL_ANDROID_SMALL_ICON`

The `.env` file is loaded automatically at start-up (`lib/main.dart`), so keep it out of source control.

Create different configurations for:
- Development
- Staging
- Production

### Firebase Projects
Maintain separate projects for each environment with appropriate security settings.

### OneSignal Notification Icon

For custom notification icons when new messages arrive:

1. Convert `assets/icon/update_icon.png` into monochrome 24×24 (or preferred) and copy it to `android/app/src/main/res/drawable/ic_notification.png`.
2. Set `ONESIGNAL_ANDROID_SMALL_ICON=ic_notification` in your `.env` (or keep the default).
3. Host a large icon (e.g. upload the same image to Cloudinary) and set `NOTIFICATION_ICON_URL` so OneSignal can render it in notifications.
4. Ensure your OneSignal App ID and REST API key are either defined in `.env` or left as the existing defaults.

### Cloudinary (Image Uploads)

- Default credentials (hardcoded in `CloudinaryConfig`)  
  `Cloud Name: duza86enw`  
  `API Key: 199568522614648`  
  `API Secret: WqTTy_PBHMZUIhJ3ZzY4Pdouhvk`  
  `Upload Preset: energysmart_upload` (unsigned)  
  `Asset Folder: test/data`
- If you need to switch environments, create a `.env` and provide overrides for the keys above. Otherwise, the defaults will be used.

### OneSignal Web Push

For Flutter web builds (including PWA/web APK packaging):

1. `web/index.html` loads the OneSignal Web SDK and calls `OneSignal.init` with App ID `741790af-bbf1-4480-9c92-18352b884ea3`.
2. `web/OneSignalSDKWorker.js` and `web/OneSignalSDKUpdaterWorker.js` are required so incoming notifications reach the app when it’s in the background.
3. In the OneSignal dashboard, enable the **Web Push** platform, set the site URL (must be HTTPS in production), and upload any web-specific icons if desired.
4. When running locally, OneSignal is configured with `allowLocalhostAsSecureOrigin: true` so you can test via `flutter run -d chrome`.

## 🛠️ Data Maintenance

### Normalize `unreadCount` Field

If older chat documents contain mis-typed `unreadCount` values (e.g. a bare number or string), you can normalize them in the Firebase Console using the snippet below:

```js
const normalizeUnreadMap = (raw, fallbackKey = 'admin') => {
  if (raw == null) return {};

  if (typeof raw === 'number') {
    const value = Math.max(0, Math.trunc(raw));
    return { [fallbackKey]: value };
  }

  if (typeof raw !== 'object') return {};

  return Object.entries(raw).reduce((acc, [key, value]) => {
    const parsed = parseInt(value, 10);
    const safeValue = Number.isNaN(parsed) || parsed < 0 ? 0 : parsed;
    if (key && key.trim()) {
      acc[key.trim()] = safeValue;
    }
    return acc;
  }, {});
};

firebase
  .firestore()
  .collection('chats')
  .get()
  .then((snapshot) => {
    const batch = firebase.firestore().batch();

    snapshot.forEach((doc) => {
      const normalized = normalizeUnreadMap(doc.get('unreadCount'));
      batch.update(doc.ref, { unreadCount: normalized });
    });

    return batch.commit();
  });
```

Run the script in small batches if you have a large dataset, and verify a few documents afterwards to confirm counts are stored as numbers inside a map.

## 📚 API Reference

### FirebaseChatService

#### Core Methods
```dart
// Initialize service
await chatService.initialize();

// Send text message
await chatService.sendMessage(
  chatId: 'chat123',
  text: 'Hello!',
);

// Send image
await chatService.sendImageMessage(
  chatId: 'chat123',
  imageFile: File('path/to/image.jpg'),
);

// Create new chat
final chatId = await chatService.createChat(
  userId: 'user123',
  subject: 'Support Request',
);

// Update chat status
await chatService.updateChatStatus(
  'chat123',
  ChatStatus.closed,
);
```

#### Streams
```dart
// Listen to chats
chatService.chatsStream.listen((chats) {
  // Handle chat updates
});

// Listen to messages
chatService.messagesStream.listen((messages) {
  // Handle message updates
});

// Listen to statistics
chatService.statisticsStream.listen((stats) {
  // Handle statistics updates
});
```

### FirebaseAuthService

#### Authentication
```dart
// Sign in with email/password
final user = await authService.signInWithEmailAndPassword(
  email: 'admin@example.com',
  password: 'password',
);

// Sign in with Google
final user = await authService.signInWithGoogle();

// Create admin user
final admin = await authService.createAdminUser(
  email: 'admin@example.com',
  password: 'password',
  name: 'Admin Name',
);

// Sign out
await authService.signOut();
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is part of the EnergySmart Admin Dashboard system.

## 🆘 Support

For support and questions:
1. Check the [Firebase Setup Guide](FIREBASE_SETUP_GUIDE.md)
2. Review the troubleshooting section
3. Check Firebase Console for errors
4. Review Firestore security rules

## 🔄 Updates

### Version 1.0.0
- Initial release with core chat functionality
- Firebase integration
- Admin-focused UI
- Real-time messaging
- File/image sharing
- Push notifications
- Security rules

### Planned Features
- **Voice messages** support
- **Video calling** integration
- **Chat templates** for common responses
- **Auto-assignment** based on workload
- **Advanced analytics** dashboard
- **Multi-language** support
- **Chat export** functionality
- **Integration** with ticketing systems

---

## 🎯 Key Benefits

✅ **Production Ready**: Comprehensive error handling and security  
✅ **Scalable**: Built on Firebase's robust infrastructure  
✅ **Real-time**: Instant updates across all connected clients  
✅ **Secure**: Role-based access with comprehensive security rules  
✅ **Professional**: Clean UI following EnergySmart design system  
✅ **Mobile First**: Responsive design for all devices  
✅ **Feature Rich**: File sharing, notifications, analytics  
✅ **Admin Focused**: Designed specifically for admin workflows  

This Firebase chat system provides a complete, enterprise-grade solution for customer support within the EnergySmart admin dashboard! 🚀
