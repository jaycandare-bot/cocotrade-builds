import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyBXdp9bZ9yeXe-BEtYHcz7GxBKq0gaX7W4",
    appId: "1:668896823878:web:f15e19992a49b081a69847",
    messagingSenderId: "1011382913553",
    projectId: "cocotrade-erp-acc57",
    storageBucket: "cocotrade-erp-acc57.appspot.com",
    iosBundleId: "com.parekhdesign.cocotradeerp",
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBXdp9bZ9yeXe-BEtYHcz7GxBKq0gaX7W4",
    appId: "1:668896823878:web:f15e19992a49b081a69847",
    messagingSenderId: "1011382913553",
    projectId: "cocotrade-erp-acc57",
    storageBucket: "cocotrade-erp-acc57.appspot.com",
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "AIzaSyBXdp9bZ9yeXe-BEtYHcz7GxBKq0gaX7W4",
    appId: "1:668896823878:web:f15e19992a49b081a69847",
    messagingSenderId: "1011382913553",
    projectId: "cocotrade-erp-acc57",
    storageBucket: "cocotrade-erp-acc57.appspot.com",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyBXdp9bZ9yeXe-BEtYHcz7GxBKq0gaX7W4",
    appId: "1:668896823878:web:f15e19992a49b081a69847",
    messagingSenderId: "1011382913553",
    projectId: "cocotrade-erp-acc57",
    storageBucket: "cocotrade-erp-acc57.appspot.com",
  );
}