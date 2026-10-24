#!/usr/bin/env bash
set -e
flutter create --project-name ironorbit --org com.ironorbit .
flutter pub get
echo "Done. Run: flutter run"
