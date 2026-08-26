import { money } from './ProductCard.jsx';

export default function CartDrawer({ items, onClose, onQuantity, onCheckout }) {
  const total = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

  return (
    <div className="fixed inset-0 z-40 bg-black/50" onClick={onClose}>
      <aside
        className="absolute left-0 top-0 h-full w-full max-w-md bg-sand-50
                   flex flex-col shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <header className="flex items-center gap-2 p-4 border-b border-sand-200">
          <h2 className="text-lg font-bold flex-1">السلة</h2>
          <button
            onClick={onClose}
            className="text-ink/40 hover:text-ink/80 text-2xl leading-none"
          >
            ×
          </button>
        </header>

        <div className="flex-1 overflow-auto p-4 space-y-3">
          {items.length === 0 && (
            <p className="text-center text-ink/55 py-16">السلة فارغة</p>
          )}

          {items.map((item, index) => (
            <div
              key={`${item.id}|${item.size}|${item.color}`}
              className="flex gap-3 items-center border border-sand-200 rounded-xl p-3"
            >
              <div className="w-16 h-16 rounded-lg bg-sand-100 overflow-hidden shrink-0">
                {item.image ? (
                  <img
                    src={item.image}
                    alt=""
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full grid place-items-center text-2xl">
                    👔
                  </div>
                )}
              </div>

              <div className="flex-1 min-w-0">
                <p className="font-semibold truncate">{item.name}</p>
                <p className="text-xs text-ink/55">
                  {[item.size, item.color].filter(Boolean).join(' · ') || '—'}
                </p>
                <p className="text-brand font-bold">{money(item.price)}</p>
              </div>

              <div className="flex items-center gap-1 shrink-0">
                <button
                  onClick={() => onQuantity(index, item.quantity - 1)}
                  className="w-8 h-8 rounded-full bg-sand-100 hover:bg-sand-200 font-bold"
                >
                  −
                </button>
                <span className="w-7 text-center font-bold">{item.quantity}</span>
                <button
                  onClick={() => onQuantity(index, item.quantity + 1)}
                  className="w-8 h-8 rounded-full bg-sand-100 hover:bg-sand-200 font-bold"
                >
                  +
                </button>
              </div>
            </div>
          ))}
        </div>

        <footer className="p-4 border-t border-sand-200 space-y-3">
          <div className="flex justify-between text-lg">
            <span className="font-semibold">المجموع</span>
            <span className="font-bold text-brand">{money(total)}</span>
          </div>
          <p className="text-xs text-ink/55">
            سعر التوصيل يُحدَّد عند تأكيد الطلب بالهاتف.
          </p>
          <button
            disabled={items.length === 0}
            onClick={onCheckout}
            className="w-full rounded-xl bg-brand text-sand-50 py-3 font-bold
                       hover:bg-brand-dark transition disabled:bg-sand-300"
          >
            متابعة الطلب
          </button>
        </footer>
      </aside>
    </div>
  );
}
