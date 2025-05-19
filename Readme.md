# Voice-Enabled Expense Tracker

A modern expense tracking application built with Flutter that features voice input capabilities and Google Drive synchronization.

## Features

- 📝 Track daily expenses and income
- 🎤 Voice input support for quick expense entry
- 📊 Visual analytics and reports
- ☁️ Google Drive synchronization
- 📱 User-friendly interface with material design
- 📊 Excel export functionality
- 📅 Date-wise expense tracking
- 🗑️ Swipe-to-delete functionality

## Prerequisites

Before running the application, make sure you have the following installed:

- [Flutter](https://flutter.dev/docs/get-started/install) (SDK version >=3.0.0)
- [Dart](https://dart.dev/get-dart)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extensions
- For iOS development: Xcode (Mac only)

## Getting Started

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd expense_tracker
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Google Sign-In:
   - Create a project in the [Google Cloud Console](https://console.cloud.google.com/)
   - Enable Google Drive API
   - Configure OAuth 2.0 credentials
   - Add your OAuth client ID to the appropriate platform configurations

4. Run the app:
   ```bash
   flutter run
   ```

## Configuration

### Android Setup
1. Update your `android/app/build.gradle` to ensure minimum SDK version is set
2. Add Google Sign-In configuration to `android/app/google-services.json`

### iOS Setup
1. Update your `ios/Runner/Info.plist` with required permissions:
   - Microphone access for voice input
   - Google Sign-In configuration

## Permissions

The app requires the following permissions:
- Microphone access (for voice input)
- Internet access (for Google Drive sync)
- Storage access (for local database)

## Dependencies

Key packages used in this project:
- `provider`: State management
- `sqflite`: Local database
- `google_sign_in` & `googleapis`: Google Drive integration
- `speech_to_text`: Voice recognition
- `fl_chart`: Charts and graphs
- `excel`: Excel file handling

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Add your license information here]

## Support

For support, please [create an issue](repository-issues-link) in the repository.