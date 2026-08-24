import { useState } from 'react';
import { WILAYAS } from '../wilayas.js';
import { money } from './ProductCard.jsx';

export default function CheckoutForm({ items, onBack, onSubmit }) {
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [wilaya, setWilaya] = useState('');
  const [address, setAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [type, setType] = useState('purchase');

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const total = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

  /**
   * التحقّق هنا يطابق دالة `isValidOrder` في قواعد Firestore حرفياً.
   * لو تساهلنا هنا لرفض الخادم الطلب برسالة غامضة بعد ملء كل الحقول.
   */
  function validate() {
    if (fullName.trim().length < 2) return 'اكتب اسمك الكامل';
    if (fullName.trim().length > 120) return 'الاسم طويل جداً';
    const digits = phone.replace(/\D/g, '');
    if (digits.length < 9) return 'رقم الهاتف غير صحيح';
    if (phone.trim().length > 20) return 'رقم الهاتف طويل جداً';
    if (!wilaya) return 'اختر الولاية';
    if (address.trim().length > 300) return 'العنوان طويل جداً';
    if (notes.trim().length > 500) return 'الملاحظة طويلة جداً';
    if (items.length === 0) return 'السلة فارغة';
    if (items.length > 50) return 'عدد المنتجات كبير جداً — اطلب على دفعات';
    return null;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const problem = validate();
    if (problem) {
      setError(problem);
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await onSubmit({ fullName, phone, wilaya, address, notes }, type);
    } catch (e) {
      setError(
        e?.code === 'permission-denied'
          ? 'تعذّر إرسال الطلب — تحقّق من البيانات وأعد المحاولة.'
          : `تعذّر إرسال الطلب: ${e.message}`,
      );
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/50 overflow-auto p-4">
      <form
        onSubmit={handleSubmit}
        className="bg-white rounded-2xl max-w-lg mx-auto my-8 p-5 space-y-4"
      >
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={onBack}
            className="text-slate-500 hover:text-slate-800"
          >
            ← رجوع
          </button>
          <h2 className="text-xl font-bold flex-1 text-center">إتمام الطلب</h2>
        </div>

        <div className="rounded-xl bg-slate-50 p-3 space-y-1 text-sm">
          {items.map((item) => (
            <div
              key={`${item.id}|${item.size}|${item.color}`}
              className="flex justify-between gap-2"
            >
              <span className="truncate">
                {item.name}
                {item.size ? ` · ${item.size}` : ''} × {item.quantity}
              </span>
              <span className="shrink-0">{money(item.price * item.quantity)}</span>
            </div>
          ))}
          <div className="flex justify-between font-bold pt-2 border-t border-slate-200">
            <span>المجموع</span>
            <span className="text-brand">{money(total)}</span>
          </div>
        </div>

        <Field label="الاسم الكامل *">
          <input
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            maxLength={120}
            className={inputClass}
            autoComplete="name"
          />
        </Field>

        <Field label="رقم الهاتف *">
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            maxLength={20}
            inputMode="tel"
            placeholder="0555 12 34 56"
            className={inputClass}
            autoComplete="tel"
          />
        </Field>

        <Field label="الولاية *">
          <select
            value={wilaya}
            onChange={(e) => setWilaya(e.target.value)}
            className={inputClass}
          >
            <option value="">اختر الولاية</option>
            {WILAYAS.map((w) => (
              <option key={w} value={w}>
                {w}
              </option>
            ))}
          </select>
        </Field>

        <Field label="العنوان">
          <input
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            maxLength={300}
            className={inputClass}
            placeholder="البلدية، الحي، نقطة دالّة"
          />
        </Field>

        <Field label="ملاحظة">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            maxLength={500}
            rows={2}
            className={inputClass}
          />
        </Field>

        <div className="flex gap-2">
          {[
            ['purchase', 'طلب شراء'],
            ['inquiry', 'استفسار فقط'],
          ].map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setType(value)}
              className={`flex-1 rounded-lg py-2 text-sm font-semibold border-2 transition ${
                type === value
                  ? 'border-brand bg-brand/10 text-brand'
                  : 'border-slate-200'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {error && (
          <p className="rounded-lg bg-rose-50 border border-rose-200 p-3 text-rose-700 text-sm">
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-xl bg-brand text-white py-3 font-bold
                     hover:bg-brand-dark transition disabled:bg-slate-300"
        >
          {busy ? 'جارٍ الإرسال...' : 'إرسال الطلب'}
        </button>

        <p className="text-xs text-slate-500 text-center">
          سنتصل بك لتأكيد الطلب وسعر التوصيل. لا حاجة للدفع الآن.
        </p>
      </form>
    </div>
  );
}

const inputClass =
  'w-full rounded-lg border border-slate-300 px-3 py-2 ' +
  'focus:outline-none focus:ring-2 focus:ring-brand/40';

function Field({ label, children }) {
  return (
    <label className="block">
      <span className="block text-sm font-semibold mb-1">{label}</span>
      {children}
    </label>
  );
}
