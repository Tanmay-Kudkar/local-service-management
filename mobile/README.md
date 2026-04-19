# Mobile App Setup

This Flutter app is implemented in `lib/` for the MVP flow:

1. Login/Register
2. View services
3. Book service

## Important

Flutter CLI is not available in this environment, so platform folders (`android/`, `ios/`, etc.) were not auto-generated.

On your machine, from the `mobile/` folder run:

```bash
flutter create .
flutter pub get
flutter run
```

Ensure backend is running on `http://10.0.2.2:8080` for Android emulator.