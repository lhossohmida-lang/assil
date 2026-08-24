import { useEffect, useMemo, useState } from 'react';
import { watchProducts, watchStoreInfo, submitOrder, STORE_ID } from './firebase.js';
import ProductCard from './components/ProductCard.jsx';
import ProductModal from './components/ProductModal.jsx';
import CartDrawer from './components/CartDrawer.jsx';
import CheckoutForm from './components/CheckoutForm.jsx';
import SocialLinks, { SocialQrCodes } from './components/SocialLinks.jsx';

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

  const categories = useMemo(() => {
    const set = new Set(products.map((p) => p.category).filter(Boolean));
    return [...set].sort();
  }, [products]);

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

  if (!STORE_ID) {
    return (
      <div className="min-h-screen grid place-items-center p-6 text-center">
        <div className="max-w-md space-y-3">
          <h1 className="text-2xl font-bold">المتجر غير مهيّأ</h1>
          <p className="text-slate-600">
            اضبط <code className="bg-slate-200 px-1 rounded">VITE_STORE_ID</code>{' '}
            بمعرّف المتجر (uid صاحب المحل) في متغيّرات البيئة، ثم أعد البناء.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col">
      <header className="sticky top-0 z-20 bg-white/95 backdrop-blur border-b border-slate-200">
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
            placeholder="ابحث عن منتج..."
            className="flex-1 min-w-0 rounded-lg border border-slate-300 px-3 py-2
                       focus:outline-none focus:ring-2 focus:ring-brand/40"
          />

          <button
            onClick={() => setCartOpen(true)}
            className="relative shrink-0 rounded-lg bg-brand text-white px-4 py-2
                       font-semibold hover:bg-brand-dark transition"
          >
            السلة
            {cartCount > 0 && (
              <span
                className="absolute -top-2 -left-2 bg-rose-600 text-white text-xs
                           rounded-full w-6 h-6 grid place-items-center"
              >
                {cartCount}
              </span>
            )}
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
              الكل
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
        {!query && !category && !placed && (
          <section
            className="mb-6 rounded-2xl overflow-hidden border border-slate-200
                       bg-gradient-to-l from-brand/10 via-white to-brand-accent/10"
          >
            <div className="px-6 py-8 md:py-10 flex items-center gap-6">
              <img
                src="/logo.png"
                alt=""
                className="hidden sm:block w-24 h-24 md:w-28 md:h-28 opacity-90"
              />
              <div className="min-w-0">
                <h2 className="text-2xl md:text-3xl font-bold text-slate-900">
                  {storeName}
                </h2>
                <p className="mt-2 text-slate-600 leading-relaxed">{tagline}</p>

                <div className="mt-4 flex flex-wrap items-center gap-2 text-sm">
                  <Feature>قصّات محتشمة</Feature>
                  <Feature>أقمشة مختارة</Feature>
                  <Feature>توصيل لكل الولايات</Feature>
                  <Feature>الدفع عند الاستلام</Feature>
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
                                 font-semibold hover:bg-brand hover:text-white transition"
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
              وصلنا طلبك — رقمه {placed}
            </p>
            <p className="text-emerald-700 mt-1">
              سنتصل بك لتأكيد الطلب والتوصيل.
            </p>
            <button
              onClick={() => setPlaced(null)}
              className="mt-3 text-sm text-emerald-700 underline"
            >
              متابعة التسوّق
            </button>
          </div>
        )}

        {loading && <p className="text-center py-16 text-slate-500">جارٍ التحميل...</p>}

        {error && (
          <p className="text-center py-16 text-rose-600">
            تعذّر تحميل المنتجات: {error}
          </p>
        )}

        {!loading && !error && visible.length === 0 && (
          <p className="text-center py-16 text-slate-500">
            {query || category ? 'لا نتائج لبحثك' : 'لا منتجات معروضة حالياً'}
          </p>
        )}

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {visible.map((p) => (
            <ProductCard key={p.id} product={p} onOpen={() => setSelected(p)} />
          ))}
        </div>
      </main>

      <footer className="border-t border-slate-200 bg-white mt-6">
        <div className="max-w-6xl mx-auto px-4 py-8 space-y-6">
          <SocialQrCodes
            facebookUrl={facebookUrl}
            instagramUrl={instagramUrl}
          />

          <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="text-center sm:text-right">
              <p className="font-bold text-slate-800">{storeName}</p>
              <p className="text-sm text-slate-500">
                الأسعار بالدينار الجزائري
              </p>
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
    <span className="rounded-full bg-white/80 border border-slate-200 px-3 py-1
                     text-slate-700">
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
          ? 'bg-brand text-white'
          : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
      }`}
    >
      {children}
    </button>
  );
}
