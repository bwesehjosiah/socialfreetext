# SocialfreeText Android app

This is the native Android companion project for the existing SocialfreeText website. It is kept in `/android` so the web app and its Vercel deployment remain intact.

## What is scaffolded

- Native Android shell that opens the existing SocialfreeText web experience.
- Firebase Cloud Messaging service entry point and token callback.
- High-priority incoming-call notification channel using the device's default ringtone, vibration, lock-screen visibility, and a full-screen-intent request.
- Answer and decline notification actions that open the call screen.
- Message notification with Android inline-reply UI.

## Required before a working APK can be built and real calls/messages can be delivered

1. Create an Android app in Firebase Console with package name `com.socialfreetext.app`.
2. Download that app's `google-services.json` and place it at `android/app/google-services.json`. Do not commit Firebase service-account credentials or private server keys.
3. Configure an Android SDK and JDK 17, then build with `gradle :app:assembleDebug` (or open `android/` in Android Studio).
4. Add a secure backend path to associate FCM tokens with the currently authenticated SocialfreeText user. The current web push sender sends Web Push notifications, not FCM data messages.
5. Extend the trusted server-side push function to send FCM HTTP v1 messages using a Firebase service account stored as a server secret. Never place that service-account JSON in the app.
6. Connect the Answer/Decline actions to authenticated WebRTC/call signaling and connect inline reply text to the app's encrypted-message send path. The website's current encryption and call flow are not automatically exposed to Android notification actions.

## Platform limitations

Android can request full-screen call notifications and ringtone behavior, but Android version, notification permission, full-screen-intent access, manufacturer battery restrictions, and Do Not Disturb settings can limit how they appear. A full-screen intent is not guaranteed to display over every app. Calls must be backed by real call signaling; sending a push alone does not prove the other device is ringing.

## Current status

This is an initial native project scaffold, not a signed or device-tested APK. Firebase configuration and the authenticated FCM delivery/signaling bridge are still required for end-to-end use.
