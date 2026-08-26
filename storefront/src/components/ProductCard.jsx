export function money(value) {
  return `${Number(value || 0).toFixed(2)} د.ج`;
}

export default function ProductCard({ product, onOpen, outOfStockLabel = 'نفد' }) {
  const image = product.images?.[0];
  const out = !product.inStock;

  return (
    <button
      onClick={onOpen}
      className="text-right bg-sand-50 rounded-xl border border-sand-200 overflow-hidden
                 hover:shadow-lg hover:-translate-y-0.5 transition group"
    >
      <div className="aspect-square bg-sand-100 relative overflow-hidden">
        {image ? (
          <img
            src={image}
            alt={product.name}
            loading="lazy"
            className="w-full h-full object-cover group-hover:scale-105 transition"
          />
        ) : (
          <div className="w-full h-full grid place-items-center text-ink/40 text-4xl">
            👔
          </div>
        )}
        {out && (
          <span className="absolute top-2 right-2 bg-rose-600 text-sand-50 text-xs
                           px-2 py-1 rounded-full">
            {outOfStockLabel}
          </span>
        )}
      </div>
      <div className="p-3">
        <p className="font-semibold line-clamp-2 min-h-[3rem]">{product.name}</p>
        <p className="text-brand font-bold mt-1">{money(product.sellPrice)}</p>
      </div>
    </button>
  );
}
