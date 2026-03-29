samples, guidance on mobile development, and a full API reference.

# Atlas

Atlas is a modern social media app for humans, built with Flutter and Firebase. It provides a seamless experience for sharing content, connecting with others, and managing your profile across platforms (iOS, Android, Web, Desktop).

## Features

- **Google Sign-In**: Secure authentication using Google accounts.
- **Profile Creation & Completion**: New users must complete their profile (username, bio) after signing in.
- **Firestore Integration**: User data, posts, and media are stored and managed in Firebase Firestore.
- **Media Uploads**: Capture and upload photos/videos from your device camera or gallery to Firebase Storage.
- **Feed & Groups**: View content feeds, join groups, and interact with posts.
- **State Management**: Uses Provider for robust state updates and navigation.
- **Logout & Account Handling**: Secure logout with confirmation and proper state clearing.

## How It Works

1. **Sign In**: Users authenticate via Google. If new, a Firestore user document is created.
2. **Profile Completion**: If the profile is incomplete (no username), the user is prompted to finish registration.
3. **Main App Navigation**: Once registration is complete, users access the main app (feed, groups, etc.).
4. **Media & Posts**: Users can post photos/videos, which are uploaded to Firebase Storage and linked in Firestore.
5. **State Updates**: All navigation and state changes are managed via callbacks and Provider, ensuring UI stays in sync with authentication and profile status.

## Project Structure

- `lib/`: Main Dart source code (pages, services, widgets, etc.)
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`: Platform-specific code and configs
- `assets/`: App icons, images, and other static assets
- `test/`, `integration_test/`: Automated and integration tests
- `pubspec.yaml`: Dependencies and project metadata

## Getting Started

1. **Install Flutter**: [Flutter Setup Guide](https://docs.flutter.dev/get-started/install)
2. **Clone the Repo**:
	```
	git clone <your-repo-url>
	cd atlas
	```
3. **Install Dependencies**:
	```
	flutter pub get
	```
4. **Run the App**:
	```
	flutter run
	```
	- For web: `flutter run -d chrome`
	- For iOS: `flutter build ios` (see iOS publishing checklist)
	- For Android: `flutter build apk`

5. **Firebase Setup**:
	- Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective folders.
	- Ensure Firebase project is configured for Authentication, Firestore, and Storage.

## Testing

- Manual and automated tests are provided in the `test/` and `integration_test/` folders.
- See `TESTING_GUIDE.md` for detailed test procedures.

## Documentation

- `REGISTRATION_ANALYSIS.md`: In-depth analysis of registration and account flow
- `VERIFICATION_REPORT.md`, `CHANGES_SUMMARY.md`: Technical verification and change logs
- `IOS_PUBLISHING_CHECKLIST.md`: Steps for iOS App Store submission

## Contributing

Pull requests are welcome! Please see the documentation and follow the code style used in the project.