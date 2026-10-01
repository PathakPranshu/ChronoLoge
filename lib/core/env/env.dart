import 'package:envied/envied.dart';

part 'env.g.dart';

/// Environment Variables

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: "FIREBASE_ANDROID_API_KEY", obfuscate: true)
  static final String firebaseAndroidKey = _Env.firebaseAndroidKey;

  @EnviedField(varName: "FIREBASE_IOS_API_KEY", obfuscate: true)
  static final String firebaseIosKey = _Env.firebaseIosKey;

  @EnviedField(varName: "FIREBASE_ANDROID_APP_ID", obfuscate: true)
  static final String firebaseAndroidAppId = _Env.firebaseAndroidAppId;

  @EnviedField(varName: "FIREBASE_IOS_APP_ID", obfuscate: true)
  static final String firebaseIosAppId = _Env.firebaseIosAppId;

  @EnviedField(varName: "FIREBASE_MESSAGING_ID", obfuscate: true)
  static final String firebaseMessagingSenderId =
      _Env.firebaseMessagingSenderId;

  @EnviedField(varName: "FIREBASE_PROJECT_ID", obfuscate: true)
  static final String firebaseProjectId = _Env.firebaseProjectId;

  @EnviedField(varName: "FIREBASE_STORAGE_BUCKET", obfuscate: true)
  static final String firebaseStorageBucket = _Env.firebaseStorageBucket;
}
