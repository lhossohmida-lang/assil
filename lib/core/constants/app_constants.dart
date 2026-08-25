/// ثوابت التطبيق العامة.
///
/// كل قيمة هنا مكتوبة **مرة واحدة فقط** في المشروع كله — لا تكرّرها في الشاشات.
class AppConstants {
  AppConstants._();

  /// اسم التطبيق الظاهر في النوافذ.
  static const String appName = 'KMSAN';

  /// ⚠️ اسم المحل المطبوع على الوصولات وتيكتات الباركود وملصقات الشحن.
  /// غيّر هذا السطر وحده — لا يوجد اسم محل مكتوب في أي ملف آخر.
  static const String storeDisplayName = 'الأصيل';

  /// رمز العملة الموحّد. كل المبالغ تُعرض بصيغة `X.XX د.ج`.
  static const String currencySymbol = 'د.ج';

  // ───────────────────────── Cloudinary ─────────────────────────
  // الصور تُرفع إلى Cloudinary برفع «غير موقّع» (unsigned upload) لأن
  // Firebase Storage يتطلب بطاقة بنكية. لا يوجد أي سرّ هنا: الـ preset
  // غير الموقّع مصمَّم أصلاً ليكون في تطبيق العميل.
  //
  // ⚠️ املأ القيمتين من لوحة Cloudinary → Settings → Upload → Upload presets
  //    (أنشئ preset بوضع Unsigned). ما دامتا فارغتين يعمل التطبيق كاملاً
  //    لكن رفع الصور يُعطّل مع رسالة واضحة بدل أن يفشل بصمت.
  static const String cloudinaryCloudName = 'vw1jzuvi';
  static const String cloudinaryUploadPreset = '9msane';

  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static String get cloudinaryUploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

  // ───────────────────────── حدود وأرقام ─────────────────────────

  /// أقصى عدد عمليات في WriteBatch واحد. الحدّ الحقيقي لـ Firestore 500،
  /// ونترك هامشاً لأن بعض العمليات تُضاعَف (منتج + مرآته في المتجر).
  static const int batchLimit = 400;

  /// طول الباركود المولَّد تلقائياً.
  /// **8 وليس 13**: انظر `TicketService` — 13 رقماً يجعل عرض الوحدة في
  /// طابعة 203dpi نقطتين فقط فلا تقرؤه الكاميرا. 8 أرقام ⇒ 3 نقاط ⇒ يُقرأ.
  static const int generatedBarcodeLength = 8;

}

/// مسارات مجموعات Firestore — مكتوبة مرة واحدة حتى لا يُخطئ أحد في اسم مجموعة.
class FirestorePaths {
  FirestorePaths._();

  static const String stores = 'stores';
  static const String userStoreMap = 'user_store_map';
  static const String publicCatalog = 'publicCatalog';
  static const String publicOrders = 'publicOrders';

  static const String users = 'users';
  static const String products = 'products';
  static const String sales = 'sales';
  static const String cashboxTransactions = 'cashbox_transactions';
  static const String expenseAccounts = 'expense_accounts';
  static const String suppliers = 'suppliers';
  static const String purchases = 'purchases';
  static const String customers = 'customers';
  static const String creditAccounts = 'credit_accounts';
  static const String reservations = 'reservations';
  static const String heldCarts = 'held_carts';
  static const String posSync = 'pos_sync';
  static const String printJobs = 'print_jobs';
  static const String settings = 'settings';
  static const String orphanImages = 'orphanImages';

  static const String meta = 'meta';

  static const String sharedCartDoc = 'shared_cart';
  static const String storeSettingsDoc = 'store';

  /// هوية المتجر الإلكتروني في المرآة العامة:
  /// `publicCatalog/{storeId}/meta/storefront`.
  static const String storefrontInfoDoc = 'storefront';
}

/// مسارات الشاشات — تُستعمل في التوجيه **وفي صلاحيات العامل** (allowedScreens).
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String pos = '/pos';
  static const String inventory = '/inventory';
  static const String noAccess = '/no-access';
  static const String sessionError = '/session-error';

  static const String importProducts = '/import-products';
  static const String importSuppliers = '/import-suppliers';
  static const String importCredits = '/import-credits';
  static const String reports = '/reports';
  static const String ledgerSearch = '/ledger-search';
  static const String capital = '/capital';
  static const String credits = '/credits';
  static const String reservations = '/reservations';
  static const String customers = '/customers';
  static const String expenses = '/expenses';
  static const String employees = '/employees';
  static const String suppliers = '/suppliers';
  static const String purchases = '/purchases';
  static const String orders = '/orders';
  static const String settings = '/settings';
}
