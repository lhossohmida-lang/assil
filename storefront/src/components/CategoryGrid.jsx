/**
 * واجهة المتجر: بطاقات الأصناف بصورها، ثم المنتجات المختارة تحتها.
 *
 * تظهر فقط في الحالة «الأولى»: لا بحث ولا صنف مختار. أول ما يفتح الزائر
 * الموقع يرى أصنافاً بصور لا قائمة منتجات طويلة، فيختار ما يريد ثم يتصفّح.
 */
export default function CategoryGrid({ categories, onPick }) {
  // صنف بلا صورة يظهر ببطاقة نصّية — أهون من إخفائه، فصاحب المحل قد
  // يضيف صنفاً اليوم وصورته غداً ولا يجوز أن يختفي من متجره حتى ذلك.
  if (!categories?.length) return null;

  return (
    <section className="mb-8">
      <h2 className="text-lg font-bold mb-3">تسوّق حسب الصنف</h2>
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
        {categories.map((category) => (
          <button
            key={category.name}
            onClick={() => onPick(category.name)}
            className="group relative overflow-hidden rounded-2xl border
                       border-slate-200 bg-white aspect-[4/3]
                       hover:shadow-lg hover:-translate-y-0.5 transition"
          >
            {category.image ? (
              <img
                src={category.image}
                alt=""
                loading="lazy"
                className="absolute inset-0 w-full h-full object-cover
                           group-hover:scale-105 transition"
              />
            ) : (
              <div
                className="absolute inset-0 grid place-items-center
                           bg-gradient-to-tr from-brand/15 to-brand-accent/15
                           text-5xl"
              >
                👔
              </div>
            )}

            {/* تدرّج داكن خلف الاسم: صورة فاتحة تبتلع نصّاً أبيض بلا هذا. */}
            <span className="absolute inset-x-0 bottom-0 bg-gradient-to-t
                             from-black/70 to-transparent px-3 py-2
                             text-white font-bold text-sm text-right">
              {category.name}
            </span>
          </button>
        ))}
      </div>
    </section>
  );
}

/// شريط المنتجات المختارة — يختارها صاحب المحل من إعدادات التطبيق.
export function FeaturedRow({ products, onOpen }) {
  if (!products?.length) return null;

  return (
    <section className="mb-8">
      <h2 className="text-lg font-bold mb-3">مختارات المحل</h2>
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {products.map((product) => (
          <button
            key={product.id}
            onClick={() => onOpen(product)}
            className="text-right bg-white rounded-xl border border-brand/30
                       overflow-hidden hover:shadow-lg hover:-translate-y-0.5
                       transition group relative"
          >
            <span className="absolute top-2 left-2 z-10 bg-brand text-white
                             text-[10px] px-2 py-0.5 rounded-full">
              مختار
            </span>
            <div className="aspect-square bg-slate-100 overflow-hidden">
              {product.images?.[0] ? (
                <img
                  src={product.images[0]}
                  alt={product.name}
                  loading="lazy"
                  className="w-full h-full object-cover group-hover:scale-105 transition"
                />
              ) : (
                <div className="w-full h-full grid place-items-center text-slate-400 text-4xl">
                  👔
                </div>
              )}
            </div>
            <div className="p-3">
              <p className="font-semibold line-clamp-2 min-h-[3rem]">
                {product.name}
              </p>
              <p className="text-brand font-bold mt-1">
                {Number(product.sellPrice || 0).toFixed(2)} د.ج
              </p>
            </div>
          </button>
        ))}
      </div>
    </section>
  );
}
