# Firebase Google Authentication Setup - Atlas App

## ✅ Completed Setup

### 1. **Dependencies Added**
The following packages have been added to `pubspec.yaml`:
- `google_sign_in: ^6.2.1` - Google Sign-In integration
- `provider: ^6.2.0` - State management

### 2. **Firebase Configuration Files**
Both configuration files have been copied to the correct locations:
- **iOS**: `ios/Runner/GoogleService-Info.plist` ✓
- **Android**: `android/app/google-services.json` ✓

### 3. **Core Authentication Files Created**

#### `lib/Services/auth_service.dart`
Main authentication service handling:
- Google Sign-In
- Firebase Auth integration
- Firestore user document creation/updates
- Username availability checking
- Profile completion checking

#### `lib/Services/auth_provider.dart`
Provider class for state management with getters for:
- `isAuthenticated` - Check if user is logged in
- `userId` - Get current user's UID
- `user` - Get Firebase User object
- `isLoading` - Loading state
- `errorMessage` - Error handling

#### `lib/Pages/login_page.dart`
Login screen featuring:
- Google Sign-In button
- Error message display
- Loading state handling
- Automatic redirect to registration if profile incomplete

#### `lib/Pages/registration_page.dart`
User onboarding screen with:
- Username input with real-time availability checking
- Bio/description field (optional)
- Form validation
- Success/error feedback

### 4. **Updated Files**

#### `lib/main.dart`
- Replaced hardcoded `userId` with `AuthProvider`
- Wrapped app with `ChangeNotifierProvider`
- Added authentication state check
- Shows `LoginScreen` when not authenticated

#### `lib/Services/theme_service.dart`
- Updated to use `FirebaseAuth.instance.currentUser`
- Removed hardcoded userId

#### `lib/Tabs/groups_tab.dart`
- Added Firebase Auth import
- Updated to use authenticated user's UID
- Fallback handling if user is null

---

## 🚀 Next Steps

### 1. **Run Flutter Dependencies**
```bash
cd /home/cillian/atlas
flutter pub get
```

### 2. **Enable Google Sign-In in Firebase Console**

**For iOS:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your "atlas-f3082" project
3. Go to Authentication > Sign-in method
4. Enable Google
5. In Xcode, ensure Bundle ID matches `com.example.atlas`

**For Android:**
1. In Firebase Console, go to Authentication > Sign-in method
2. Enable Google
3. Run this command to get your Android SHA-1:
```bash
cd /home/cillian/atlas/android
./gradlew signingReport
```
4. Add the SHA-1 fingerprint to Firebase Android app settings

### 3. **iOS Additional Configuration**
In `ios/Runner/Info.plist`, ensure you have:
```xml
<key>GIDClientID</key>
<string>1010878433274-v3iru1e94cj2com42siclbiv7fr4r761.apps.googleusercontent.com</string>
```

### 4. **Test the Implementation**
```bash
# Clean build
flutter clean

# Run on your device/emulator
flutter run
```

---

## 📋 User Flow

1. **Launch App** → User sees `LoginScreen`
2. **Tap "Sign in with Google"** → Google authentication
3. **User redirected to `RegistrationScreen`** → Enter username & bio
4. **Profile created in Firestore** → Main app loads
5. **User data persists** → Subsequent launches go directly to main app

---

## 🔧 How to Use in Your Widgets

### Access Current User ID
```dart
import 'package:provider/provider.dart';
import 'package:atlas/Services/auth_provider.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    // Use userId to fetch data from Firestore
  }
}
```

### Listen to Auth State Changes
```dart
Consumer<AuthProvider>(
  builder: (context, authProvider, _) {
    if (authProvider.isAuthenticated) {
      // Show main app
    } else {
      // Show login screen
    }
  },
)
```

### Sign Out User
```dart
context.read<AuthProvider>().signOut();
```

---

## 📊 Firestore User Document Structure

When a user signs in, the following document is created:

```
users/[user-uid]/
  ├── uid: "firebase-auth-uid"
  ├── email: "user@example.com"
  ├── username: "john_doe"
  ├── bio: "User's biography"
  ├── photoURL: "https://..."
  ├── darkMode: false
  ├── followers: []
  ├── following: []
  ├── groups: []
  ├── createdAt: Timestamp
  └── updatedAt: Timestamp
```

---

## ⚠️ Important Notes

1. **Replace hardcoded userId everywhere** - Search your codebase for any remaining hardcoded "I8PwtNA3QTEt44rxH8jN" references and replace with `context.read<AuthProvider>().userId`

2. **Firestore Security Rules** - Update your Firestore rules to:
```firebase-rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

3. **Google OAuth Credentials** - The GoogleService files already contain your OAuth credentials, keep them secure and don't commit to public repositories.

---

## 🐛 Troubleshooting

**"Sign in was cancelled"** → User tapped cancel on Google sign-in dialog

**"Username not available"** → Username already taken or invalid format (must be 3-20 alphanumeric + underscore)

**"Failed to update profile"** → Check Firestore permissions and ensure user document was created

**Black screen on startup** → Ensure `flutter pub get` completed successfully

---

## 📚 Files Modified/Created

**New Files:**
- `lib/Services/auth_service.dart`
- `lib/Services/auth_provider.dart`
- `lib/Pages/login_page.dart`
- `lib/Pages/registration_page.dart`

**Modified Files:**
- `pubspec.yaml` - Added dependencies
- `lib/main.dart` - Authentication integration
- `lib/Services/theme_service.dart` - Use auth user
- `lib/Tabs/groups_tab.dart` - Use auth user
- `ios/Runner/GoogleService-Info.plist` - Copied
- `android/app/google-services.json` - Copied
