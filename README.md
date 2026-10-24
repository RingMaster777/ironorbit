# IronOrbit

Rotation-based workout tracker built with Flutter. Upload your own plan and it cycles through your days (Shoulder > Chest > Bicep > Leg > repeat), tracking weight, reps, hold time, duration and streaks.

## Setup (one time)

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. In this folder run:

       flutter create --project-name ironorbit --org com.ironorbit .
       flutter pub get
       flutter run

   (`flutter create .` adds the android/ios/web folders around the existing lib/ and pubspec.yaml. It will not overwrite them.)
   Or just run `bash setup.sh`.

## Plan format

A day name on its own line, then one exercise per line:

    Shoulder
    Overhead Press 4x8
    Plank 3x45s      <- trailing "s" = timed hold (seconds)

Upload a .txt/.csv/.json file from the Roster tab, or edit the text box and tap Save plan.
JSON also works: [{"name":"Chest","ex":[{"n":"Bench","sets":4,"reps":8,"hold":false}]}]

## Build an APK

    flutter build apk --release
