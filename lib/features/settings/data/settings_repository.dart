import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants/app_constants.dart';
import '../domain/models/store_settings.dart';

/// تجزئة الرقم السرّي — SHA-256. لا نخزّن الرقم نفسه أبداً.
String hashPin(String pin) =>
    sha256.convert(utf8.encode(pin.trim())).toString();

class SettingsRepository {
  SettingsRepository(this._db, this.storeId);

  final FirebaseFirestore _db;
  final String storeId;

  DocumentReference<Map<String, dynamic>> get _ref => _db
      .collection(FirestorePaths.stores)
      .doc(storeId)
      .collection(FirestorePaths.settings)
      .doc(FirestorePaths.storeSettingsDoc);

  Stream<StoreSettings> watch() =>
      _ref.snapshots().map((s) => StoreSettings.fromMap(s.data()));

  Future<StoreSettings> read() async =>
      StoreSettings.fromMap((await _ref.get()).data());

  Future<void> setPin(String pin) =>
      _ref.set({'pinHash': hashPin(pin)}, SetOptions(merge: true));

  Future<void> setVipDiscount(double percent) =>
      _ref.set({'vipDiscountPercent': percent}, SetOptions(merge: true));

  /// يسجّل لحظة إغلاق الصندوق = بداية اليوم المحاسبي التالي.
  Future<void> setLastDayClose(DateTime at) =>
      _ref.set({'lastDayClose': Timestamp.fromDate(at)}, SetOptions(merge: true));

  // ─────────── القوائم التي يديرها صاحب المحل من الإعدادات ───────────

  Future<void> setCategories(List<String> categories) =>
      _ref.set({'categories': categories}, SetOptions(merge: true));

  Future<void> setSizes(List<String> sizes) =>
      _ref.set({'sizes': sizes}, SetOptions(merge: true));

  Future<void> setColors(List<ColorOption> colors) => _ref.set(
        {'colors': colors.map((c) => c.toMap()).toList()},
        SetOptions(merge: true),
      );

  // ─────────── شعار المحل ───────────

  /// أقصى طول ضلع للشعار المحفوظ.
  ///
  /// ليس رقماً اعتباطياً: الشعار يُرسم علامةً مائية بنحو 62٪ من الشاشة
  /// وبشفافية 5٪، وشعاراً صغيراً في القائمة والدخول — 512 بكسل تكفي
  /// جميعها بفارق كبير. والمقابل أن المستند يبقى عشرات الكيلوبايتات لا
  /// مئاتها، وهو مستند **تراقبه كل شاشة** في التطبيق.
  static const int logoMaxSide = 512;

  /// يصغّر الشعار ويرمّزه base64 جاهزاً للتخزين.
  ///
  /// PNG لا JPEG: الشعار خطوط حادّة على خلفية بيضاء، وضغط JPEG يُحيط
  /// الخطوط بهالات رمادية تظهر بوضوح عند تكبيرها علامةً مائية.
  static String encodeLogo(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('تعذّرت قراءة الصورة — اختر ملف PNG أو JPG.');
    }

    var out = decoded;
    final longest =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest > logoMaxSide) {
      out = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: logoMaxSide)
          : img.copyResize(decoded, height: logoMaxSide);
    }
    return base64Encode(img.encodePng(out, level: 9));
  }

  /// يحفظ الشعار. يُصغَّر أوّلاً ثم يُرفض إن بقي أكبر من الحدّ الآمن.
  ///
  /// نفشل بصراحة بدل أن نكتب مستنداً يرفضه Firestore برسالة غامضة، أو
  /// أسوأ: يُقبل ويُبطئ كل شاشة في التطبيق بعد ذلك.
  Future<void> setLogo(Uint8List bytes) async {
    final encoded = encodeLogo(bytes);
    if (encoded.length > 700 * 1024) {
      throw const FormatException(
        'الصورة كبيرة جداً حتى بعد التصغير — جرّب صورة أبسط.',
      );
    }
    await _ref.set({'logoBase64': encoded}, SetOptions(merge: true));
  }

  /// يعيد الشعار المضمَّن.
  Future<void> clearLogo() =>
      _ref.set({'logoBase64': ''}, SetOptions(merge: true));

  // ─────────── هوية المتجر الإلكتروني ───────────

  DocumentReference<Map<String, dynamic>> get _publicRef => _db
      .collection(FirestorePaths.publicCatalog)
      .doc(storeId)
      .collection(FirestorePaths.meta)
      .doc(FirestorePaths.storefrontInfoDoc);

  /// يحفظ بيانات المتجر الإلكتروني **ويحدّث المرآة العامة في الدفعة نفسها**.
  ///
  /// لماذا دفعة واحدة؟ لأن الموقع يقرأ المرآة فقط. لو حُدّث المستند الخاص
  /// ونُسي العام لبقي الموقع يعرض رابط فيسبوك القديم إلى الأبد بلا أي
  /// رسالة خطأ — أسوأ نوع من الأعطال: صامت.
  ///
  /// ما يُنشر محصور في [StoreSettings.toStorefrontMap] — قائمة بيضاء.
  Future<void> saveStorefront({
    String? facebook,
    String? instagram,
    String? storeName,
    String? tagline,
    String? phone,
    String? storefrontUrl,
  }) async {
    final current = await read();
    final next = current.copyWith(
      facebookUrl: facebook?.trim(),
      instagramUrl: instagram?.trim(),
      storeName: storeName?.trim(),
      storeTagline: tagline?.trim(),
      storePhone: phone?.trim(),
      storefrontUrl: storefrontUrl?.trim(),
    );

    final batch = _db.batch();
    batch.set(_ref, {
      'facebookUrl': next.facebookUrl,
      'instagramUrl': next.instagramUrl,
      'storeName': next.storeName,
      'storeTagline': next.storeTagline,
      'storePhone': next.storePhone,
      'storefrontUrl': next.storefrontUrl,
    }, SetOptions(merge: true));
    batch.set(_publicRef, next.toStorefrontMap());
    await batch.commit();
  }
}
