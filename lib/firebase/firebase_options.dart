import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA4M54igk8VeQQf4RSns1R8op9Jxu_mAiU',
    appId: '1:995276352471:web:0991869708722a6f467992',
    messagingSenderId: '995276352471',
    projectId: 'bluetoothcommapp',
    authDomain: 'bluetoothcommapp.firebaseapp.com',
    storageBucket: 'bluetoothcommapp.firebasestorage.app',
    measurementId: 'G-MES4J74L3X',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA4M54igk8VeQQf4RSns1R8op9Jxu_mAiU',
    appId: '1:995276352471:android:0991869708722a6f467992',
    messagingSenderId: '995276352471',
    projectId: 'bluetoothcommapp',
    authDomain: 'bluetoothcommapp.firebaseapp.com',
    storageBucket: 'bluetoothcommapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA4M54igk8VeQQf4RSns1R8op9Jxu_mAiU',
    appId: '1:995276352471:ios:0991869708722a6f467992',
    messagingSenderId: '995276352471',
    projectId: 'bluetoothcommapp',
    authDomain: 'bluetoothcommapp.firebaseapp.com',
    storageBucket: 'bluetoothcommapp.firebasestorage.app',
    iosClientId: '995276352471-CLIENT_ID.apps.googleusercontent.com',
    iosBundleId: 'com.example.bluetoothCommApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA4M54igk8VeQQf4RSns1R8op9Jxu_mAiU',
    appId: '1:995276352471:ios:0991869708722a6f467992',
    messagingSenderId: '995276352471',
    projectId: 'bluetoothcommapp',
    authDomain: 'bluetoothcommapp.firebaseapp.com',
    storageBucket: 'bluetoothcommapp.firebasestorage.app',
    iosClientId: '995276352471-CLIENT_ID.apps.googleusercontent.com',
    iosBundleId: 'com.example.bluetoothCommApp',
  );
}