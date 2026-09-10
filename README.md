# FAST Carpool

FAST Carpool is an Expo SDK 57 app for verified FAST students to coordinate rides.

## Local development

1. Copy `.env.example` to `.env` and set `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`, and `EXPO_PUBLIC_ADMIN_USER_ID`.
2. Run the Supabase migrations in `supabase/migrations/` and deploy `supabase/functions/review-verification`.
3. Install dependencies with `npm install`, then run `npx expo start`.

## Android APK / Play preparation

- Install EAS CLI: `npm i -g eas-cli`, then run `eas login`.
- Set your Expo project owner and `extra.eas.projectId` using `eas init`.
- Build a test APK with `eas build --platform android --profile preview`.
- Build the Play Store artifact with `eas build --platform android --profile production` (AAB is the recommended Play format).
- Submit after reviewing the generated privacy/data-safety declarations: `eas submit --platform android --profile production`.

The app requests location, camera/photo access, notifications, and stores a private phone number. ID-card images are deleted after review; only the verification result remains.
