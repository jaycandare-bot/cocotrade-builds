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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBXdp9bZ9yeXe-BEtYHcz7GxBKq0gaX7W4",
    appId: "1:668896823878:web:f15e19992a49b081a69847",
    messagingSenderId: "1011382913553",
    projectId: "cocotrade-erp-acc57",
    authDomain: "cocotrade-erp-acc57.firebaseapp.com",
    storageBucket: "cocotrade-erp-acc57.appspot.com",
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "AIzaSyBXdp9bZ9yeXe-BEtYHcz7GxBKq0gaX7W4",
    appId: "1:668896823878:web:f15e19992a49b081a69847",
    messagingSenderId: "1011382913553",
    projectId: "cocotrade-erp-acc57",
    storageBucket: "cocotrade-erp-acc57.appspot.com",
  );
}