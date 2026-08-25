/// ولايات الجزائر الـ58 بترتيبها الرسمي.
///
/// الفهرس + 1 = رقم الولاية (`wilayas[0]` = أدرار = ولاية 01)، وهو
/// الترتيب نفسه المستعمل في المتجر الإلكتروني (`storefront/src/wilayas.js`)
/// حتى تتطابق الأسماء الواردة في الطلبات مع أسماء جدول الأسعار حرفياً.
///
/// ⚠️ المطابقة **بالاسم لا بالرقم**: الطلب القادم من الموقع يحمل اسم
/// الولاية نصّاً، فتغيير حرف واحد هنا يجعل سعر التوصيل يعود إلى
/// الافتراضي بصمت.
const List<String> algeriaWilayas = [
  'أدرار', 'الشلف', 'الأغواط', 'أم البواقي', 'باتنة', 'بجاية', 'بسكرة',
  'بشار', 'البليدة', 'البويرة', 'تمنراست', 'تبسة', 'تلمسان', 'تيارت',
  'تيزي وزو', 'الجزائر', 'الجلفة', 'جيجل', 'سطيف', 'سعيدة', 'سكيكدة',
  'سيدي بلعباس', 'عنابة', 'قالمة', 'قسنطينة', 'المدية', 'مستغانم',
  'المسيلة', 'معسكر', 'ورقلة', 'وهران', 'البيض', 'إليزي', 'برج بوعريريج',
  'بومرداس', 'الطارف', 'تندوف', 'تيسمسيلت', 'الوادي', 'خنشلة',
  'سوق أهراس', 'تيبازة', 'ميلة', 'عين الدفلى', 'النعامة', 'عين تموشنت',
  'غرداية', 'غليزان', 'تيميمون', 'برج باجي مختار', 'أولاد جلال',
  'بني عباس', 'عين صالح', 'عين قزام', 'تقرت', 'جانت', 'المغير', 'المنيعة',
];

/// رقم الولاية بصيغتها الرسمية ذات الخانتين: «01»، «16»، «58».
String wilayaNumber(String name) {
  final index = algeriaWilayas.indexOf(name.trim());
  if (index < 0) return '';
  return (index + 1).toString().padLeft(2, '0');
}

/// جدول أسعار التوصيل: اسم الولاية ⇒ السعر بالدينار.
///
/// الغائب من الجدول يأخذ [DeliveryPricing.defaultFee]، فلا يُضطر صاحب
/// المحل لملء 58 خانة ليبدأ العمل — يملأ ما يخالف السعر الموحّد فقط.
class DeliveryPricing {
  const DeliveryPricing({this.defaultFee = 0, this.byWilaya = const {}});

  /// السعر المستعمل لأي ولاية بلا سعر خاص.
  final double defaultFee;

  final Map<String, double> byWilaya;

  /// سعر التوصيل إلى ولاية بعينها.
  double feeFor(String wilaya) => byWilaya[wilaya.trim()] ?? defaultFee;

  /// عدد الولايات التي ضُبط لها سعر خاص.
  int get customCount => byWilaya.length;

  /// سعر التوصيل الفعّال لطلب.
  ///
  /// الطلب القادم من الموقع يصل بسعر **صفر** — الموقع لا يعرف جدول
  /// الأسعار ولا يجوز أن يعرفه (سيراه أي زائر). فالسعر يُحسب هنا من
  /// ولاية الزبون. وإن جاء الطلب بسعر موجب (طلب هاتفي أُدخل يدوياً مثلاً)
  /// فهو أولى: من كتبه رآه واتفق عليه مع الزبون.
  double effectiveFee({required String wilaya, required double orderFee}) =>
      orderFee > 0 ? orderFee : feeFor(wilaya);

  factory DeliveryPricing.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const DeliveryPricing();
    final raw = (m['byWilaya'] ?? const <String, dynamic>{}) as Map;
    return DeliveryPricing(
      defaultFee: (m['defaultFee'] as num?)?.toDouble() ?? 0,
      byWilaya: {
        for (final e in raw.entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
      },
    );
  }

  Map<String, dynamic> toMap() => {
        'defaultFee': defaultFee,
        'byWilaya': byWilaya,
      };

  DeliveryPricing copyWith({double? defaultFee, Map<String, double>? byWilaya}) =>
      DeliveryPricing(
        defaultFee: defaultFee ?? this.defaultFee,
        byWilaya: byWilaya ?? this.byWilaya,
      );

  /// يضبط سعر ولاية. السعر السالب يُهمَل، والصفر يعني «مجاني» لا «احذف»
  /// — الحذف يكون بـ [clearWilaya].
  DeliveryPricing withWilaya(String wilaya, double fee) {
    if (fee < 0) return this;
    return copyWith(byWilaya: {...byWilaya, wilaya.trim(): fee});
  }

  DeliveryPricing clearWilaya(String wilaya) =>
      copyWith(byWilaya: {...byWilaya}..remove(wilaya.trim()));
}
