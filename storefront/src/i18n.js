import { useEffect, useState } from 'react';

/// نصوص المتجر بلغتين.
///
/// المفتاح رمزي هنا (لا النصّ العربي كما في التطبيق) لأن الإنجليزية
/// ليست ترجمة للعربية بل نصّ أصيل مقابل لها؛ ولأن الموقع صغير فجدول
/// المفاتيح فيه أوضح من جدول نصوص.
export const STRINGS = {
  ar: {
    dir: 'rtl',
    lang: 'ar',
    // ── صفحة الهبوط ──
    welcomeTitle: 'مرحباً بكم في متجر الأصيل',
    welcomeBody:
      'لباس رجالي محتشم بلمسة أصيلة — قصّات مدروسة وخامات تدوم.',
    categoriesTitle: 'أنواع المنتجات',
    categoriesBody:
      'قمصان، أقمصة، وجلابيات — لكل مناسبة قطعة تليق بها.',
    fabricTitle: 'قماش ممتاز',
    fabricBody:
      'نختار القماش بأيدينا: قطن يتنفّس، خياطة متينة، ولون لا يبهت مع الغسل.',
    contactTitle: 'تواصل معنا',
    contactBody: 'تابعنا أو اتصل بنا مباشرةً — ونحن في خدمتك.',
    enterShop: 'ادخل إلى المتجر',
    scrollHint: 'اسحب للأسفل',
    // ── المتجر ──
    searchPlaceholder: 'ابحث عن منتج...',
    cart: 'السلة',
    all: 'الكل',
    loading: 'جارٍ التحميل...',
    noProducts: 'لا منتجات معروضة حالياً',
    noResults: 'لا نتائج لبحثك',
    outOfStock: 'نفد',
    featured: 'منتجات مختارة',
    backToCategories: 'كل الأصناف',
    priceNote: 'الأسعار بالدينار الجزائري',
    orderPlaced: 'وصلنا طلبك — رقمه',
    orderNote: 'سنتصل بك لتأكيد الطلب والتوصيل.',
    keepShopping: 'متابعة التسوّق',
    loadFailed: 'تعذّر تحميل المنتجات:',
    notConfigured: 'المتجر غير مهيّأ',
    home: 'الواجهة',
    perkCuts: 'قصّات محتشمة',
    perkFabric: 'أقمشة مختارة',
    perkDelivery: 'توصيل لكل الولايات',
    perkCod: 'الدفع عند الاستلام',
  },
  en: {
    dir: 'ltr',
    lang: 'en',
    welcomeTitle: 'Welcome to Al-Asil',
    welcomeBody:
      'Modest menswear with an authentic touch — considered cuts, lasting fabrics.',
    categoriesTitle: 'Our Collections',
    categoriesBody:
      'Shirts, thobes and jalabiyas — a piece for every occasion.',
    fabricTitle: 'Exceptional Fabric',
    fabricBody:
      'We pick the cloth by hand: breathable cotton, solid stitching, colour that holds through every wash.',
    contactTitle: 'Get in Touch',
    contactBody: 'Follow us or call directly — we are at your service.',
    enterShop: 'Enter the shop',
    scrollHint: 'Scroll down',
    searchPlaceholder: 'Search products…',
    cart: 'Cart',
    all: 'All',
    loading: 'Loading…',
    noProducts: 'No products on display yet',
    noResults: 'Nothing matches your search',
    outOfStock: 'Sold out',
    featured: 'Featured pieces',
    backToCategories: 'All categories',
    priceNote: 'Prices in Algerian dinar',
    orderPlaced: 'We got your order — number',
    orderNote: 'We will call you to confirm the order and delivery.',
    keepShopping: 'Keep shopping',
    loadFailed: 'Could not load products:',
    notConfigured: 'Shop not configured',
    home: 'Home',
    perkCuts: 'Modest cuts',
    perkFabric: 'Selected fabrics',
    perkDelivery: 'Delivery to all wilayas',
    perkCod: 'Cash on delivery',
  },
};

const KEY = 'asil.lang.v1';

/// اللغة المختارة، محفوظة في المتصفّح.
///
/// العربية هي الافتراضية: الزبون الجزائري يفتح الموقع بها، والإنجليزية
/// خيار لمن يحتاجه لا العكس.
export function useLang() {
  const [lang, setLang] = useState(() => {
    try {
      const saved = localStorage.getItem(KEY);
      return saved === 'en' || saved === 'ar' ? saved : 'ar';
    } catch {
      return 'ar';
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem(KEY, lang);
    } catch {
      // متصفّح يمنع التخزين (نافذة خاصة) — اللغة تبقى لهذه الجلسة فقط.
    }
    // اتجاه الصفحة ولغتها للقارئات الآلية ولمحرّكات البحث.
    document.documentElement.lang = lang;
    document.documentElement.dir = STRINGS[lang].dir;
  }, [lang]);

  return [STRINGS[lang], lang, setLang];
}
