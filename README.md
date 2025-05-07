# Verdant

*Smart budget tracking that helps you grow your wealth, one cent at a time.*

## Overview

Verdant is a sleek budget tracker built with Flutter and Firebase that helps you manage finances effortlessly. Set monthly or custom budgets, categorize expenses with a tap, and gain insights through intuitive visualizations.

## Features

- **Smart Budget Management**: Set monthly or custom budget goals
- **Quick Expense Entry**: Add transactions in seconds with categorization
- **Insightful Reports**: Visualize spending patterns to make better decisions
- **Offline Capability**: Use the app anytime with automatic syncing when back online
- **Dark/Light Mode**: Choose your preferred theme
- **Secure Firebase Backend**: Your data is safely stored and synced across devices

## Getting Started

### Prerequisites

- Flutter (latest stable version)
- Firebase account
- Android Studio or VS Code

### Installation

1. Clone the repository
```bash
git clone https://github.com/t1mato/verdant-app.git
cd verdant-app
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Firebase
- Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
- Add Android and iOS apps to your Firebase project
- Download and add the configuration files:
  - `google-services.json` (Android)
  - `GoogleService-Info.plist` (iOS)
- Enable Firestore Database and Authentication

4. Run the app
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models.dart            # Data models
├── pages/                 # App screens
│   ├── dashboard_page.dart
│   ├── login_page.dart
│   ├── report_page.dart
│   └── summary_page.dart
├── providers/             # State management
│   └── theme_provider.dart
└── services/              # Backend services
    └── database_service.dart
```

## Firebase Setup

### Authentication

The app uses Firebase Email/Password authentication. You'll need to enable this in your Firebase console.

## Offline Support

Verdant implements Firebase offline persistence, allowing users to:
- View their data when offline
- Create new transactions while offline
- Automatically sync when back online

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add some amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Flutter](https://flutter.dev)
- [Firebase](https://firebase.google.com)
- [Provider](https://pub.dev/packages/provider)
- [Connectivity Plus](https://pub.dev/packages/connectivity_plus)
- [Percent Indicator](https://pub.dev/packages/percent_indicator)
