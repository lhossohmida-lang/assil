import { useEffect, useMemo, useState } from 'react';
import { watchProducts, watchStoreInfo, submitOrder, STORE_ID } from './firebase.js';
import ProductCard from './components/ProductCard.jsx';
import ProductModal from './components/ProductModal.jsx';
import CartDrawer from './components/CartDrawer.jsx';
import CheckoutForm from './components/CheckoutForm.jsx';
import SocialLinks, { SocialQrCodes } from './components/SocialLinks.jsx';
import LandingPage from './components/LandingPage.jsx';
import { useLang } from './i18n.js';
import CategoryGrid, { FeaturedRow } from './components/CategoryGrid.jsx';

// قيم افتراضية تظهر قبل أن يحفظ صاحب المحل هويّته من الإعدادات،
// أو لو تعذّرت قراءة المرآة العامة. الموقع لا يظهر فارغاً أبداً.
const DEFAULT_NAME = 'الأصيل';
const DEFAULT_TAGLINE = 'قمصان وأقمصة رجالية — لباس محتشم بلمسة أصيلة';
const CART_KEY = 'kmsan.cart.v1';

export default function App() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [info, setInfo] = useState({});
  const [t, lang, setLang] = useLang();

  // صفحة الهبوط أوّلاً، والمتجر بعد الضغط على «ادخل إلى المتجر».
  //
  // القرار محفوظ للجلسة فقط (لا localStorage): الزائر العائد في اليوم
  // نفسه لا يُجبَر على أربعة مشاهد مرّة أخرى، لكن الزيارة الجديدة تبدأ
  // من الواجهة لأنها هي هوية المحل.
  const [view, setView] = useState(() => {
    try {
      return sessionStorage.getItem('asil.view') === 'shop' ? 'shop' : 'landing';
    } catch {
      return 'landing';
    }
  });

  function openShop() {
    try {
      sessionStorage.setItem('asil.view', 'shop');
    } catch {
      // نافذة خاصة — يبقى الاختيار في الذاكرة وحدها.
    }
    setView('shop');
  }

  function openLanding() {
    try {
      sessionStorage.removeItem('asil.view');
    } catch {
      // تجاهُل مقصود.
    }
    setView('landing');
  }

  const [query, setQuery] = useState('');
  const [category, setCategory] = useState('');
  const [selected, setSelected] = useState(null);

  // السلة محلية في المتصفّح — لا حساب ولا تسجيل دخول للزبون.
  const [cart, setCart] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(CART_KEY) || '[]');
    } catch {
      return [];
    }
  });
  const [cartOpen, setCartOpen] = useState(false);
  const [checkout, setCheckout] = useState(false);
  const [placed, setPlaced] = useState(null);

  useEffect(() => {
    const unsubscribe = watchProducts(
      (list) => {
        setProducts(list);
        setLoading(false);
      },
      (e) => {
        setError(e.message);
        setLoading(false);
      },
    );
    return unsubscribe;
  }, []);

  useEffect(() => watchStoreInfo(setInfo), []);

  useEffect(() => {
    localStorage.setItem(CART_KEY, JSON.stringify(cart));
  }, [cart]);

  // أصناف الواجهة تأتي من إعدادات التطبيق (باسمها وصورتها وترتيبها).
  // نُبقي المستنتجة من المنتجات احتياطاً: محل لم يضبط أصنافه بعد يجب أن
  // يعمل متجره لا أن يظهر فارغاً.
  const settingsCategories = useMemo(
    () => (Array.isArray(info.categories) ? info.categories : []),
    [info],
  );

  const categories = useMemo(() => {
    if (settingsCategories.length) {
      return settingsCategories.map((c) => c.name).filter(Boolean);
    }
    const set = new Set(products.map((p) => p.category).filter(Boolean));
    return [...set].sort();
  }, [products, settingsCategories]);

  // بطاقات الأصناف: لا نعرض صنفاً لا منتج منشوراً فيه — بطاقة تُفتح على
  // صفحة فارغة أسوأ من غيابها.
  const categoryCards = useMemo(() => {
    const stocked = new Set(products.map((p) => p.category));
    const source = settingsCategories.length
      ? settingsCategories
      : categories.map((name) => ({ name, image: '' }));
    return source.filter((c) => c.name && stocked.has(c.name));
  }, [settingsCategories, categories, products]);

  const featured = useMemo(() => {
    const ids = Array.isArray(info.featured) ? info.featured : [];
    if (!ids.length) return [];
    const byId = new Map(products.map((p) => [p.id, p]));
    // نحترم ترتيب اختيار صاحب المحل، ونتجاهل معرّفاً لمنتج حُذف أو أُخفي.
    return ids.map((id) => byId.get(id)).filter(Boolean);
  }, [info, products]);

  // الواجهة الأولى: لا بحث ولا صنف مختار ولا طلب أُرسل للتوّ.
  const showHome = !query && !category && !placed;

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return products
      .filter((p) => (category ? p.category === category : true))
      .filter((p) =>
        q
          ? (p.name || '').toLowerCase().includes(q) ||
            (p.description || '').toLowerCase().includes(q)
          : true,
      )
      // المتوفّر أولاً — لا نُحبط الزبون بصفّ من «نفد».
      .sort((a, b) => Number(b.inStock) - Number(a.inStock));
  }, [products, query, category]);

  const storeName = (info.storeName || '').trim() || DEFAULT_NAME;
  const tagline = (info.tagline || '').trim() || DEFAULT_TAGLINE;
  const phone = (info.phone || '').trim();
  const facebookUrl = (info.facebookUrl || '').trim();
  const instagramUrl = (info.instagramUrl || '').trim();

  const cartCount = cart.reduce((sum, i) => sum + i.quantity, 0);

  function addToCart(product, { size = '', color = '', quantity = 1 } = {}) {
    setCart((current) => {
      const key = `${product.id}|${size}|${color}`;
      const index = current.findIndex(
        (i) => `${i.id}|${i.size}|${i.color}` === key,
      );
      if (index >= 0) {
        const next = [...current];
        next[index] = {
          ...next[index],
          quantity: next[index].quantity + quantity,
        };
        return next;
      }
      return [
        ...current,
        {
          id: product.id,
          name: product.name,
          price: product.sellPrice,
          image: product.images?.[0] || '',
          size,
          color,
          quantity,
        },
      ];
    });
    setSelected(null);
    setCartOpen(true);
  }

  function setQuantity(index, quantity) {
    setCart((current) =>
      quantity <= 0
        ? current.filter((_, i) => i !== index)
        : current.map((item, i) =>
            i === index ? { ...item, quantity } : item,
          ),
    );
  }

  async function placeOrder(customer, type) {
    const orderNumber = await submitOrder({
      customer,
      items: cart,
      deliveryFee: 0,
      type,
    });
    setCart([]);
    setCheckout(false);
    setCartOpen(false);
    setPlaced(orderNumber);
    return orderNumber;
  }

  if (view === 'landing' && STORE_ID) {
    return (
      <>
        <LanguageToggle lang={lang} setLang={setLang} floating />
        <LandingPage
          t={t}
          storeName={storeName}
          tagline={tagline}
          phone={phone}
          facebookUrl={facebookUrl}
          instagramUrl={instagramUrl}
          onEnterShop={openShop}
        />
      </>
    );
  }

  if (!STORE_ID) {
    return (
      <div className="min-h-screen grid place-items-center p-6 text-center">
        <div className="max-w-md space-y-3">
          <h1 className="text-2xl font-bold">المتجر غير مهيّأ</h1>
          <p className="text-ink/70">
            اضبط <code className="bg-sand-200 px-1 rounded">VITE_STORE_ID</code>{' '}
            بمعرّف المتجر (uid صاحب المحل) في متغيّرات البيئة، ثم أعد البناء.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col">
      <header className="sticky top-0 z-20 bg-sand-50/95 backdrop-blur border-b border-sand-200">
        <div className="max-w-6xl mx-auto px-4 py-3 flex items-center gap-3">
          <a href="#top" className="flex items-center gap-2 shrink-0">
            <img
              src="/logo.png"
              alt=""
              className="w-10 h-10"
              /* alt فارغ عمداً: الاسم مكتوب بجانبه، فلا يكرّره قارئ الشاشة */
            />
            <span className="text-xl md:text-2xl font-bold text-brand">
              {storeName}
            </span>
          </a>

          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.searchPlaceholder}
            className="flex-1 min-w-0 rounded-lg border border-sand-300 px-3 py-2
                       focus:outline-none focus:ring-2 focus:ring-brand/40"
          />

          <button
            onClick={() => setCartOpen(true)}
            className="relative shrink-0 rounded-lg bg-brand text-sand-50 px-4 py-2
                       font-semibold hover:bg-brand-dark transition"
          >
            {t.cart}
            {cartCount > 0 && (
              <span
                className="absolute -top-2 -left-2 bg-rose-600 text-sand-50 text-xs
                           rounded-full w-6 h-6 grid place-items-center"
              >
                {cartCount}
              </span>
            )}
          </button>

          <LanguageToggle lang={lang} setLang={setLang} />

          <button
            onClick={openLanding}
            className="hidden sm:block shrink-0 text-sm font-semibold
                       text-ink/60 hover:text-ink transition"
          >
            {t.home}
          </button>

          <div className="hidden md:flex">
            <SocialLinks
              facebookUrl={facebookUrl}
              instagramUrl={instagramUrl}
              compact
            />
          </div>
        </div>

        {categories.length > 0 && (
          <div className="max-w-6xl mx-auto px-4 pb-3 flex gap-2 overflow-x-auto">
            <Chip active={!category} onClick={() => setCategory('')}>
              {t.all}
            </Chip>
            {categories.map((c) => (
              <Chip
                key={c}
                active={category === c}
                onClick={() => setCategory(c)}
              >
                {c}
              </Chip>
            ))}
          </div>
        )}
      </header>

      <main id="top" className="flex-1 max-w-6xl mx-auto w-full px-4 py-6">
        {/* الواجهة التعريفية — تختفي فور أن يبحث الزائر أو يفرز، لأنه
            حينها يعرف ما يريد ولا يحتاج تعريفاً بالمحل. */}
        {showHome && (
          <section
            className="mb-6 rounded-2xl overflow-hidden border border-sand-200
                       bg-gradient-to-l from-brand/10 via-sand-50 to-brand-accent/10"
          >
            <div className="px-6 py-8 md:py-10 flex items-center gap-6">
              <img
                src="/logo.png"
                alt=""
                className="hidden sm:block w-24 h-24 md:w-28 md:h-28 opacity-90"
              />
              <div className="min-w-0">
                <h2 className="text-2xl md:text-3xl font-bold text-ink">
                  {storeName}
                </h2>
                <p className="mt-2 text-ink/70 leading-relaxed">
                  {t.lang === 'ar' ? tagline : t.welcomeBody}
                </p>

                <div className="mt-4 flex flex-wrap items-center gap-2 text-sm">
                  <Feature>{t.perkCuts}</Feature>
                  <Feature>{t.perkFabric}</Feature>
                  <Feature>{t.perkDelivery}</Feature>
                  <Feature>{t.perkCod}</Feature>
                </div>

                <div className="mt-5 flex flex-wrap items-center gap-3">
                  <SocialLinks
                    facebookUrl={facebookUrl}
                    instagramUrl={instagramUrl}
                  />
                  {phone && (
                    <a
                      href={`tel:${phone}`}
                      className="rounded-lg border border-brand text-brand px-4 py-2
                                 font-semibold hover:bg-brand hover:text-sand-50 transition"
                      dir="ltr"
                    >
                      {phone}
                    </a>
                  )}
                </div>
              </div>
            </div>
          </section>
        )}

        {placed && (
          <div className="mb-6 rounded-xl bg-emerald-50 border border-emerald-200 p-5 text-center">
            <p className="text-lg font-bold text-emerald-800">
              {t.orderPlaced} {placed}
            </p>
            <p className="text-emerald-700 mt-1">
              {t.orderNote}
            </p>
            <button
              onClick={() => setPlaced(null)}
              className="mt-3 text-sm text-emerald-700 underline"
            >
              {t.keepShopping}
            </button>
          </div>
        )}

        {loading && (
          <p className="text-center py-16 text-ink/55">{t.loading}</p>
        )}

        {error && (
          <p className="text-center py-16 text-rose-600">
            {t.loadFailed} {error}
          </p>
        )}

        {!loading && !error && visible.length === 0 && (
          <p className="text-center py-16 text-ink/55">
            {query || category ? t.noResults : t.noProducts}
          </p>
        )}

        {showHome && (
          <>
            <CategoryGrid categories={categoryCards} onPick={setCategory} />
            <FeaturedRow products={featured} onOpen={setSelected} />
          </>
        )}

        {/* في الواجهة الأولى نعرض «كل المنتجات» تحت المختارات بعنوان
            صريح، فلا يظنّ الزائر أن المعروض هو كل ما في المحل. */}
        {showHome && visible.length > 0 && (
          <h2 className="text-lg font-bold mb-3">كل المنتجات</h2>
        )}

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {visible.map((p) => (
            <ProductCard
              key={p.id}
              product={p}
              outOfStockLabel={t.outOfStock}
              onOpen={() => setSelected(p)}
            />
          ))}
        </div>
      </main>

      <footer className="border-t border-sand-200 bg-sand-50 mt-6">
        <div className="max-w-6xl mx-auto px-4 py-8 space-y-6">
          <SocialQrCodes
            facebookUrl={facebookUrl}
            instagramUrl={instagramUrl}
          />

          <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="text-center sm:text-right">
              <p className="font-bold text-ink">{storeName}</p>
              <p className="text-sm text-ink/55">{t.priceNote}</p>
              {phone && (
                <a
                  href={`tel:${phone}`}
                  dir="ltr"
                  className="text-sm text-brand font-semibold"
                >
                  {phone}
                </a>
              )}
            </div>
            <SocialLinks
              facebookUrl={facebookUrl}
              instagramUrl={instagramUrl}
            />
          </div>
        </div>
      </footer>

      {selected && (
        <ProductModal
          product={selected}
          onClose={() => setSelected(null)}
          onAdd={addToCart}
        />
      )}

      {cartOpen && !checkout && (
        <CartDrawer
          items={cart}
          onClose={() => setCartOpen(false)}
          onQuantity={setQuantity}
          onCheckout={() => setCheckout(true)}
        />
      )}

      {checkout && (
        <CheckoutForm
          items={cart}
          onBack={() => setCheckout(false)}
          onSubmit={placeOrder}
        />
      )}
    </div>
  );
}

function Feature({ children }) {
  return (
    <span className="rounded-full bg-sand-50/80 border border-sand-200 px-3 py-1
                     text-ink/80">
      ✓ {children}
    </span>
  );
}

function Chip({ active, onClick, children }) {
  return (
    <button
      onClick={onClick}
      className={`shrink-0 rounded-full px-4 py-1.5 text-sm font-semibold transition ${
        active
          ? 'bg-brand text-sand-50'
          : 'bg-sand-100 text-ink/80 hover:bg-sand-200'
      }`}
    >
      {children}
    </button>
  );
}


/// مبدّل اللغة — عربية/إنجليزية.
///
/// زرّان ظاهران لا قائمة منسدلة: خياران فقط، والقائمة تخفي أحدهما خلف
/// نقرة بلا داعٍ.
function LanguageToggle({ lang, setLang, floating = false }) {
  return (
    <div
      className={
        floating
          ? 'fixed top-4 start-4 z-40 flex rounded-full bg-sand-50/90 backdrop-blur border border-sand-300 overflow-hidden shadow-sm'
          : 'flex rounded-full border border-sand-300 overflow-hidden shrink-0'
      }
    >
      {['ar', 'en'].map((code) => (
        <button
          key={code}
          onClick={() => setLang(code)}
          aria-label={code === 'ar' ? 'العربية' : 'English'}
          className={`px-3 py-1.5 text-xs font-bold transition ${
            lang === code
              ? 'bg-ink text-sand-50'
              : 'text-ink/60 hover:text-ink'
          }`}
        >
          {code === 'ar' ? 'ع' : 'EN'}
        </button>
      ))}
    </div>
  );
}
