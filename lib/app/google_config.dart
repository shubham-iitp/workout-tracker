/// Google Cloud project "workout-tracker" (spec §6.4).
///
/// The *Web* OAuth client id, passed to `google_sign_in` as `serverClientId`.
/// A client id is public (it ships inside every APK); the client secret is not
/// needed by the app and must never be committed.
///
/// Sign-in on Android also needs an *Android* OAuth client in the same project
/// with package `com.shubham.workout_tracker` + the SHA-1 of the signing key.
const googleWebClientId =
    '390358905079-amfgtfdhq5hb1v36roj19is6bbp0kta9.apps.googleusercontent.com';
