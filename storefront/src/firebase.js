import { initializeApp } from 'firebase/app';
import {
  getFirestore,
  collection,
  doc,
  onSnapshot,
  query,
  where,
  runTransaction,
  serverTimestamp,
} from 'firebase/firestore';

// مفاتيح العميل ليست أسراراً — الحماية الحقيقية في قواعد Firestore.
const firebaseConfig = {
  apiKey: 'AIzaSyBfWhBUgGlxIsE1_-6QzNpHm1guWkMlOw4',
  authDomain: 'mesan-869c2.firebaseapp.com',
  projectId: 'mesan-869c2',
  storageBucket: 'mesan-869c2.firebasestorage.app',
  messagingSenderId: '475319923088',
  appId: '1:475319923088:web:9d037b05f31d36b2e64315',
};

// ⚠️ ضع هنا معرّف المتجر = uid صاحب المحل (تجده في لوحة Firebase →
// Authentication، أو في مستند user_store_map).
export const STORE_ID = import.meta.env.VITE_STORE_ID || '';

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);

/**
 * يستمع لمنتجات المتجر العام.
 *
 * نقرأ `publicCatalog` لا `stores/**` — المرآة العامة الوحيدة التي تسمح
 * القواعد بقراءتها بلا مصادقة، وهي **لا تحوي سعر الشراء ولا المورّد ولا
 * الباركود**.
 */
export function watchProducts(onData, onError) {
  if (!STORE_ID) {
    onError?.(new Error('لم يُضبط VITE_STORE_ID'));
    return () => {};
  }
  const ref = collection(db, 'publicCatalog', STORE_ID, 'products');
  return onSnapshot(
    query(ref, where('publishedToStore', '==', true)),
    (snap) => {
      onData(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
    },
    onError,
  );
}

/**
 * يستمع لهوية المحل: الاسم، الجملة التعريفية، الهاتف، روابط التواصل.
 *
 * مصدرها مستند واحد ينشره التطبيق من شاشة الإعدادات، فيغيّر صاحب المحل
 * رابط فيسبوك من هاتفه ويظهر في الموقع فوراً بلا إعادة بناء ولا نشر.
 *
 * غيابه ليس خطأ: المتجر يعمل بالقيم الافتراضية حتى يُحفظ أوّل مرة.
 */
export function watchStoreInfo(onData) {
  if (!STORE_ID) return () => {};
  const ref = doc(db, 'publicCatalog', STORE_ID, 'meta', 'storefront');
  return onSnapshot(
    ref,
    (snap) => onData(snap.exists() ? snap.data() : {}),
    () => onData({}),
  );
}

/**
 * يحجز رقم الطلب التالي بمعاملة ذرّية.
 *
 * قواعد Firestore تسمح للزائر بزيادة العدّاد بواحد فقط (`value <=
 * resource.value + 1`)، فلا يستطيع أحد القفز به إلى رقم كبير أو تخريبه.
 * وعند تبدّل السنة يعود إلى 1 (وهو أصغر من القديم+1 فتقبله القاعدة).
 */
async function nextOrderNumber() {
  const counterRef = doc(db, 'publicOrders', STORE_ID, 'meta', 'counter');
  const year = new Date().getFullYear();

  const value = await runTransaction(db, async (tx) => {
    const snap = await tx.get(counterRef);
    if (!snap.exists()) {
      tx.set(counterRef, { year, value: 1 });
      return 1;
    }
    const data = snap.data();
    const next = data.year === year ? (data.value || 0) + 1 : 1;
    tx.update(counterRef, { year, value: next });
    return next;
  });

  return `KM-${year}-${String(value).padStart(3, '0')}`;
}

/**
 * يرسل الطلب.
 *
 * بنية المستند مقيَّدة بدالة `isValidOrder` في القواعد: مفاتيح محدّدة،
 * حالة `pending` إجبارياً، وحدود على الأطوال والمبالغ. أي حقل زائد
 * يُرفض الطلب كاملاً.
 */
export async function submitOrder({ customer, items, deliveryFee, type }) {
  if (!STORE_ID) throw new Error('لم يُضبط معرّف المتجر');

  const subtotal = items.reduce((sum, i) => sum + i.price * i.quantity, 0);
  const fee = Number(deliveryFee) || 0;
  const orderNumber = await nextOrderNumber();

  const payload = {
    orderNumber,
    type: type === 'inquiry' ? 'inquiry' : 'purchase',
    customer: {
      fullName: customer.fullName.trim(),
      phone: customer.phone.trim(),
      wilaya: customer.wilaya.trim(),
      ...(customer.address?.trim() ? { address: customer.address.trim() } : {}),
      ...(customer.notes?.trim() ? { notes: customer.notes.trim() } : {}),
    },
    items: items.map((i) => ({
      productId: i.id,
      name: i.name,
      quantity: i.quantity,
      price: i.price,
      size: i.size || '',
      color: i.color || '',
    })),
    subtotal,
    deliveryFee: fee,
    total: subtotal + fee,
    deposit: 0,
    status: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const ordersRef = collection(db, 'publicOrders', STORE_ID, 'orders');
  const orderRef = doc(ordersRef);
  await runTransaction(db, async (tx) => {
    tx.set(orderRef, payload);
  });

  return orderNumber;
}
