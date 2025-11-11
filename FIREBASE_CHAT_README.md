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
Create different configurations for:
- Development
- Staging
- Production

### Firebase Projects
Maintain separate projects for each environment with appropriate security settings.

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
