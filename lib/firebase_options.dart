// مكتوب يدوياً (لا flutterfire configure) — مشروع mesan-869c2.
// مفاتيح Firebase الخاصة بالعميل ليست أسراراً: الحماية الحقيقية في
// قواعد Firestore (firestore.rules) لا في إخفاء الـ apiKey.
import 'package:firebase_core/firebase_core.dart'
    show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        // ويندوز يستعمل نفس تهيئة الويب (Firebase C++/Web SDK).
        return web;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBfWhBUgGlxIsE1_-6QzNpHm1guWkMlOw4',
    authDomain: 'mesan-869c2.firebaseapp.com',
    projectId: 'mesan-869c2',
    storageBucket: 'mesan-869c2.firebasestorage.app',
    messagingSenderId: '475319923088',
    appId: '1:475319923088:web:9d037b05f31d36b2e64315',
    measurementId: 'G-3ZQN59TS1P',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDDHjZeRP0Zlqcj7MECeP7y6M6rqYh54TI',
    appId: '1:475319923088:android:2bca5d4a873abec1e64315',
    messagingSenderId: '475319923088',
    projectId: 'mesan-869c2',
    storageBucket: 'mesan-869c2.firebasestorage.app',
  );
}
