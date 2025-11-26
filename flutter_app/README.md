# ChronoWorks

A comprehensive time scheduling, reporting, and clock in/out application with facial recognition, geofencing, intelligent overtime management, break monitoring, and payroll processing.

## Version
1.1.0

## Platform Support
- Web
- iOS
- Android

## Features
- Facial Recognition (Google Cloud Vision API)
- GPS Geofencing (100m radius)
- Clock In/Out with verification
- Manager-created schedules
- Intelligent overtime prediction & prevention
- Break monitoring & compliance tracking
- Payroll processing & export
- Real-time employee tracking
- Automated email notifications (SendGrid)

## Tech Stack
- **Framework:** Flutter 3.35.2
- **State Management:** Provider
- **Backend:** Firebase (Auth, Firestore, Storage, Functions)
- **Email:** SendGrid
- **Face Recognition:** Google Cloud Vision API

## Setup Instructions

### Prerequisites
- Flutter SDK 3.35.2+
- Firebase account
- Google Cloud account (for Vision API)
- SendGrid account

### Installation

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure Firebase (see Firebase Setup section)
4. Run: `flutter run -d chrome` (for web)

## Project Structure
```
lib/
├── main.dart
├── models/
├── screens/
│   ├── auth/
│   ├── admin/
│   ├── manager/
│   └── employee/
├── services/
├── widgets/
│   └── common/
└── utils/
```

## Documentation
See `/docs` folder for:
- Architecture documentation
- Database schema
- API documentation
- User guides

## License
Proprietary

## Contact
[Your contact information]
