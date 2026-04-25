# Atlas

> Atlas is a modern cross-platform social media app built with Flutter and Firebase. It is designed for fast onboarding, polished user profiles, and a rich content-sharing experience across mobile, web, and desktop.

## 🚀 What Atlas Does

Atlas helps users create a personalized social presence and interact with a community using:

- Google authentication and secure account handling
- Profile creation and completion enforcement for new sign-ins
- Firestore-based user and content storage
- Photo and video uploads via camera or gallery
- Feed browsing, groups, and social interactions
- Responsive Flutter UI for Android, iOS, web, and desktop

## 🧭 A New Kind of Social Media

Atlas is built around the idea that a social app can be meaningful without relying on opaque recommendation engines, advertising algorithms, or AI-driven engagement loops.

- The app is designed to keep the experience transparent, honest, and user-driven.
- It aims to prove that social media can be built without sacrificing usability or quality.
- Instead of optimizing for attention, Atlas focuses on simple, direct connections and clean content discovery.

## ✨ Key Features

- **Google Sign-In** using Firebase Authentication
- **Registration Flow** requiring username and bio completion
- **Firebase Firestore** for storing user profiles, posts, and activity
- **Firebase Storage** for media uploads
- **Provider** for app state management and user session handling
- **Cross-platform support** including Android, iOS, web, Linux, macOS, and Windows
- **Integrated asset pipeline** with icons, backgrounds, and preview images

## 🧠 Why This Project Stands Out

Atlas is not just a demo app — it demonstrates a complete social onboarding and account lifecycle:

- New users are automatically created in Firestore on Google sign-in
- Incomplete profiles are routed to registration before entering the app
- Profile updates are persisted atomically with timestamps and metadata
- Auth and UI state remain synchronized across navigation

## 📁 Project Structure

- `lib/` — main application source
  - `Pages/` — screens and page layout logic
  - `Services/` — Firebase and authentication services
  - `Widgets/` — reusable UI components
  - `Map_And_Bubbles/` — custom map and bubble visualization logic
  - `Content_Feed/` — feed and post handling
- `assets/` — images, icons, and UI branding assets
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` — platform-specific configurations
- `test/`, `integration_test/` — unit and integration test suites
- `pubspec.yaml` — package dependencies and Flutter configuration

## 🛠️ Technology Stack

- Flutter SDK
- Firebase Core
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Google Sign-In
- Provider
- Camera & video playback
- Cached network image handling

## ✅ Setup Instructions

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Clone the repository:
   ```bash
   git clone <your-repo-url>
   cd atlas
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Configure Firebase:
   - Place `google-services.json` in `android/app/`
   - Place `GoogleService-Info.plist` in `ios/Runner`
   - Enable Firebase Authentication, Firestore, and Storage
5. Run the app:
   ```bash
   flutter run
   ```

### Platform-specific commands

- Web: `flutter run -d chrome`
- Android APK: `flutter build apk`
- iOS: `flutter build ios`

## 🔍 Testing and Validation

- Run unit/widget tests:
  ```bash
  flutter test
  ```
- Run integration tests:
  ```bash
  flutter test integration_test
  ```
- Review verification and analysis guides in:
  - `REGISTRATION_ANALYSIS.md`
  - `TESTING_GUIDE.md`
  - `IOS_PUBLISHING_CHECKLIST.md`

## 📌 Notes for Contributors

- Follow the existing project conventions in `lib/`
- Keep authentication and Firestore logic centralized in `Services/`
- Use `Provider` for reactive UI state updates
- Add new assets under `assets/` and update `pubspec.yaml` when needed

## 📄 Additional Documentation

- `REGISTRATION_ANALYSIS.md` — detailed registration and account creation flow
- `VERIFICATION_REPORT.md` — verification and correctness report
- `CHANGES_SUMMARY.md` — change log and progress summary
- `README_VERIFICATION.md` — repository verification checklist

---

## 💡 Quick Summary

Atlas is a polished Flutter social app prototype built to showcase a complete user onboarding workflow, Firebase-backed social features, and cross-platform compatibility. It is ready to be tested, extended, and used as a base for a production-quality social experience.