import { useState } from 'react';
import { money } from './ProductCard.jsx';

export default function ProductModal({ product, onClose, onAdd }) {
  const [size, setSize] = useState(product.sizes?.[0] || '');
  const [color, setColor] = useState(product.colors?.[0] || '');
  const [quantity, setQuantity] = useState(1);
  const [imageIndex, setImageIndex] = useState(0);

  const images = product.images?.length ? product.images : [null];
  const out = !product.inStock;

  return (
    <div
      className="fixed inset-0 z-40 bg-black/50 grid place-items-center p-4"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl max-w-3xl w-full max-h-[90vh] overflow-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <div className="aspect-square bg-slate-100">
              {images[imageIndex] ? (
                <img
                  src={images[imageIndex]}
                  alt={product.name}
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full grid place-items-center text-6xl text-slate-400">
                  👔
                </div>
              )}
            </div>
            {images.length > 1 && (
              <div className="flex gap-2 p-2 overflow-x-auto">
                {images.map((src, i) => (
                  <button
                    key={i}
                    onClick={() => setImageIndex(i)}
                    className={`w-16 h-16 shrink-0 rounded-lg overflow-hidden border-2 ${
                      i === imageIndex ? 'border-brand' : 'border-transparent'
                    }`}
                  >
                    <img src={src} alt="" className="w-full h-full object-cover" />
                  </button>
                ))}
              </div>
            )}
          </div>

          <div className="p-5 space-y-4">
            <div className="flex items-start gap-2">
              <h2 className="text-xl font-bold flex-1">{product.name}</h2>
              <button
                onClick={onClose}
                className="text-slate-400 hover:text-slate-700 text-2xl leading-none"
              >
                ×
              </button>
            </div>

            <p className="text-2xl font-bold text-brand">
              {money(product.sellPrice)}
            </p>

            {product.description && (
              <p className="text-slate-600 whitespace-pre-line">
                {product.description}
              </p>
            )}

            {product.sizes?.length > 0 && (
              <Options
                label="المقاس"
                values={product.sizes}
                selected={size}
                onSelect={setSize}
              />
            )}
            {product.colors?.length > 0 && (
              <Options
                label="اللون"
                values={product.colors}
                selected={color}
                onSelect={setColor}
              />
            )}

            <div className="flex items-center gap-3">
              <span className="font-semibold">الكمية</span>
              <div className="flex items-center gap-2">
                <RoundButton onClick={() => setQuantity((q) => Math.max(1, q - 1))}>
                  −
                </RoundButton>
                <span className="w-8 text-center font-bold text-lg">{quantity}</span>
                <RoundButton onClick={() => setQuantity((q) => q + 1)}>+</RoundButton>
              </div>
            </div>

            <button
              disabled={out}
              onClick={() => onAdd(product, { size, color, quantity })}
              className="w-full rounded-xl bg-brand text-white py-3 font-bold
                         hover:bg-brand-dark transition disabled:bg-slate-300"
            >
              {out ? 'غير متوفّر حالياً' : 'أضف إلى السلة'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function Options({ label, values, selected, onSelect }) {
  return (
    <div>
      <p className="font-semibold mb-2">{label}</p>
      <div className="flex flex-wrap gap-2">
        {values.map((v) => (
          <button
            key={v}
            onClick={() => onSelect(v)}
            className={`rounded-lg px-3 py-1.5 border-2 text-sm font-semibold transition ${
              selected === v
                ? 'border-brand bg-brand/10 text-brand'
                : 'border-slate-200 hover:border-slate-400'
            }`}
          >
            {v}
          </button>
        ))}
      </div>
    </div>
  );
}

function RoundButton({ onClick, children }) {
  return (
    <button
      onClick={onClick}
      className="w-9 h-9 rounded-full bg-slate-100 hover:bg-slate-200
                 text-xl font-bold leading-none"
    >
      {children}
    </button>
  );
}
