import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/wilayas.dart';

import '../../../../shared/utils/formatters.dart';

/// لون معرَّف من الإعدادات: اسم عربي + قيمة دقيقة اختارها صاحب المحل
/// من دائرة الألوان.
class ColorOption {
  const ColorOption({required this.name, required this.value});

  final String name;

  /// قيمة ARGB كاملة (0xFFRRGGBB).
  final int value;

  String get hex =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  factory ColorOption.fromMap(Map<String, dynamic> m) => ColorOption(
        name: (m['name'] ?? '') as String,
        value: m['value'] == null ? 0xFF000000 : toInt(m['value']),
      );

  Map<String, dynamic> toMap() => {'name': name, 'value': value};

  @override
  bool operator ==(Object other) =>
      other is ColorOption && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// إعدادات المتجر المشتركة بين كل الأجهزة (`stores/{id}/settings/store`).
///
/// ملاحظة: إعدادات الطباعة والمظهر واللغة **ليست هنا** — هي محلية لكل
/// جهاز (SharedPreferences)، لأن لكل حاسوب طابعته ومعايرته، ولكل مستخدم
/// لغته.
class StoreSettings {
  /// تجزئة SHA-256 للرقم السرّي. `null` = لا رقم سرّي بعد.
  final String? pinHash;

  /// نسبة خصم زبونة VIP (٪).
  final double vipDiscountPercent;

  /// لحظة آخر «إغلاق صندوق» — بداية اليوم المحاسبي الحالي.
  final DateTime? lastDayClose;

  /// أنواع المنتجات — تُدار من الإعدادات وتُستعمل في بطاقة المنتج
  /// وفي فرز نقطة البيع.
  final List<String> categories;

  /// المقاسات المتاحة — تُكتب يدوياً في الإعدادات.
  final List<String> sizes;

  /// الألوان المتاحة — تُختار من دائرة الألوان في الإعدادات.
  final List<ColorOption> colors;

  final String facebookUrl;
  final String instagramUrl;

  /// اسم الصفحة كما يُكتب تحت رمز QR على الوصل والملصق («الأصيل»،
  /// «@alasil.dz»). فارغ ⇒ تُكتب «Facebook» / «Instagram».
  ///
  /// منفصل عن الرابط لأن الرابط طويل ولا يتّسع تحت رمز 20مم، والزبون
  /// يمسح الرمز ولا يقرأ العنوان.
  final String facebookName;
  final String instagramName;

  /// أسعار التوصيل حسب الولاية.
  ///
  /// مشتركة لا محلّية: من يؤكّد الطلب قد يكون على الهاتف ومن يطبع الملصق
  /// على الحاسوب، ولا يجوز أن يختلف السعر بينهما.
  final DeliveryPricing delivery;

  /// اسم المحل كما يظهر في **المتجر الإلكتروني**. فارغ = يُستعمل الاسم
  /// الافتراضي. (اسم الوصل شيء آخر: هو محلّي لكل جهاز في إعدادات الطباعة.)
  final String storeName;

  /// جملة تعريفية قصيرة تحت الاسم في المتجر.
  final String storeTagline;

  /// هاتف يظهر للزبون في المتجر ليتّصل مباشرةً.
  final String storePhone;

  /// عنوان المتجر الإلكتروني بعد نشره (Vercel مثلاً).
  ///
  /// لا يُنشر في المرآة العامة: الموقع يعرف عنوان نفسه. فائدته في
  /// التطبيق وحده — زرّ يفتح المتجر من شاشة الطلبات.
  final String storefrontUrl;

  /// شعار المحل صورةً (PNG مصغَّر، base64) يختاره صاحب المحل من داخل
  /// التطبيق. فارغ ⇒ يُستعمل الشعار المضمَّن `assets/images/logo_mark.png`.
  ///
  /// مُخزَّن مع الإعدادات **المشتركة** لا المحلّية: الشعار هوية المحل، فلو
  /// غيّره صاحبه على الحاسوب وجب أن يتغيّر على هاتف عامله أيضاً بلا أن
  /// يُطلب منه شيء. ولهذا يُصغَّر قبل الحفظ (انظر `SettingsRepository.setLogo`)
  /// — مستند Firestore سقفه ميغابايت واحد، وهذا المستند تراقبه كل شاشة.
  final String logoBase64;

  bool get hasCustomLogo => logoBase64.isNotEmpty;

  const StoreSettings({
    this.pinHash,
    this.vipDiscountPercent = 10,
    this.lastDayClose,
    this.categories = const [],
    this.sizes = const [],
    this.colors = const [],
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.storeName = '',
    this.storeTagline = '',
    this.storePhone = '',
    this.logoBase64 = '',
    this.storefrontUrl = '',
    this.facebookName = '',
    this.instagramName = '',
    this.delivery = const DeliveryPricing(),
  });

  bool get hasPin => (pinHash ?? '').isNotEmpty;
  bool get hasSocial => facebookUrl.isNotEmpty || instagramUrl.isNotEmpty;

  /// 🚫 المرآة العامة لبيانات المحل — يقرأها **أي زائر على الإنترنت**.
  ///
  /// القاعدة نفسها التي تحكم [Product.toPublicMap]: قائمة بيضاء صريحة، لا
  /// نسخة من `toMap()` منقوصة. لو أضفنا يوماً حقلاً حسّاساً إلى الإعدادات
  /// (تجزئة الرقم السرّي، رأس المال، نسبة الخصم…) فلن يتسرّب تلقائياً،
  /// لأنه ببساطة ليس مذكوراً هنا.
  Map<String, dynamic> toStorefrontMap() => {
        'storeName': storeName,
        'tagline': storeTagline,
        'phone': storePhone,
        'facebookUrl': facebookUrl,
        'instagramUrl': instagramUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory StoreSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const StoreSettings();
    return StoreSettings(
      pinHash: m['pinHash'] as String?,
      vipDiscountPercent: m['vipDiscountPercent'] == null
          ? 10
          : toDouble(m['vipDiscountPercent']),
      lastDayClose: (m['lastDayClose'] as Timestamp?)?.toDate(),
      categories: ((m['categories'] ?? const []) as List).cast<String>(),
      sizes: ((m['sizes'] ?? const []) as List).cast<String>(),
      colors: ((m['colors'] ?? const []) as List)
          .map((e) => ColorOption.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      facebookUrl: (m['facebookUrl'] ?? '') as String,
      instagramUrl: (m['instagramUrl'] ?? '') as String,
      storeName: (m['storeName'] ?? '') as String,
      storeTagline: (m['storeTagline'] ?? '') as String,
      storePhone: (m['storePhone'] ?? '') as String,
      logoBase64: (m['logoBase64'] ?? '') as String,
      storefrontUrl: (m['storefrontUrl'] ?? '') as String,
      facebookName: (m['facebookName'] ?? '') as String,
      instagramName: (m['instagramName'] ?? '') as String,
      delivery: DeliveryPricing.fromMap(
        m['delivery'] == null
            ? null
            : Map<String, dynamic>.from(m['delivery'] as Map),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        if (pinHash != null) 'pinHash': pinHash,
        'vipDiscountPercent': vipDiscountPercent,
        if (lastDayClose != null)
          'lastDayClose': Timestamp.fromDate(lastDayClose!),
        'categories': categories,
        'sizes': sizes,
        'colors': colors.map((c) => c.toMap()).toList(),
        'facebookUrl': facebookUrl,
        'instagramUrl': instagramUrl,
        'storeName': storeName,
        'storeTagline': storeTagline,
        'storePhone': storePhone,
        'logoBase64': logoBase64,
        'storefrontUrl': storefrontUrl,
        'facebookName': facebookName,
        'instagramName': instagramName,
        'delivery': delivery.toMap(),
      };

  StoreSettings copyWith({
    String? pinHash,
    double? vipDiscountPercent,
    DateTime? lastDayClose,
    List<String>? categories,
    List<String>? sizes,
    List<ColorOption>? colors,
    String? facebookUrl,
    String? instagramUrl,
    String? storeName,
    String? storeTagline,
    String? storePhone,
    String? logoBase64,
    String? storefrontUrl,
    String? facebookName,
    String? instagramName,
    DeliveryPricing? delivery,
  }) =>
      StoreSettings(
        pinHash: pinHash ?? this.pinHash,
        vipDiscountPercent: vipDiscountPercent ?? this.vipDiscountPercent,
        lastDayClose: lastDayClose ?? this.lastDayClose,
        categories: categories ?? this.categories,
        sizes: sizes ?? this.sizes,
        colors: colors ?? this.colors,
        facebookUrl: facebookUrl ?? this.facebookUrl,
        instagramUrl: instagramUrl ?? this.instagramUrl,
        storeName: storeName ?? this.storeName,
        storeTagline: storeTagline ?? this.storeTagline,
        storePhone: storePhone ?? this.storePhone,
        logoBase64: logoBase64 ?? this.logoBase64,
        storefrontUrl: storefrontUrl ?? this.storefrontUrl,
        facebookName: facebookName ?? this.facebookName,
        instagramName: instagramName ?? this.instagramName,
        delivery: delivery ?? this.delivery,
      );
}
