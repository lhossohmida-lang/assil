import { useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';

/** أيقونة فيسبوك — مضمَّنة كـ SVG لا كصورة خارجية، فلا طلب شبكة إضافي. */
function FacebookIcon(props) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" {...props}>
      <path d="M22 12.06C22 6.5 17.52 2 12 2S2 6.5 2 12.06c0 5.02 3.66 9.18 8.44 9.94v-7.03H7.9v-2.91h2.54V9.85c0-2.52 1.5-3.91 3.77-3.91 1.09 0 2.24.2 2.24.2v2.46h-1.26c-1.24 0-1.63.78-1.63 1.57v1.89h2.78l-.45 2.91h-2.33V22c4.78-.76 8.44-4.92 8.44-9.94z" />
    </svg>
  );
}

/** أيقونة إنستغرام. */
function InstagramIcon(props) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" {...props}>
      <path d="M12 2.16c3.2 0 3.58.01 4.85.07 1.17.05 1.8.25 2.23.41.56.22.96.48 1.38.9.42.42.68.82.9 1.38.16.42.36 1.06.41 2.23.06 1.27.07 1.65.07 4.85s-.01 3.58-.07 4.85c-.05 1.17-.25 1.8-.41 2.23-.22.56-.48.96-.9 1.38-.42.42-.82.68-1.38.9-.42.16-1.06.36-2.23.41-1.27.06-1.65.07-4.85.07s-3.58-.01-4.85-.07c-1.17-.05-1.8-.25-2.23-.41a3.8 3.8 0 01-1.38-.9 3.8 3.8 0 01-.9-1.38c-.16-.42-.36-1.06-.41-2.23C2.17 15.58 2.16 15.2 2.16 12s.01-3.58.07-4.85c.05-1.17.25-1.8.41-2.23.22-.56.48-.96.9-1.38.42-.42.82-.68 1.38-.9.42-.16 1.06-.36 2.23-.41C8.42 2.17 8.8 2.16 12 2.16zm0 3.68a6.16 6.16 0 100 12.32 6.16 6.16 0 000-12.32zm0 10.16a4 4 0 110-8 4 4 0 010 8zm7.85-10.4a1.44 1.44 0 11-2.88 0 1.44 1.44 0 012.88 0z" />
    </svg>
  );
}

/**
 * أزرار التواصل — تظهر فقط إن ضبط صاحب المحل روابطها من الإعدادات.
 *
 * `rel="noopener noreferrer"` ليس تجميلاً: بدون noopener تستطيع الصفحة
 * المفتوحة التحكّم في تبويبنا عبر window.opener وتحويله إلى صفحة مزيّفة.
 */
export default function SocialLinks({ facebookUrl, instagramUrl, compact = false }) {
  if (!facebookUrl && !instagramUrl) return null;

  const size = compact ? 'w-9 h-9' : 'w-11 h-11';
  const icon = compact ? 'w-5 h-5' : 'w-6 h-6';

  return (
    <div className="flex items-center gap-2">
      {facebookUrl && (
        <a
          href={facebookUrl}
          target="_blank"
          rel="noopener noreferrer"
          aria-label="فيسبوك"
          title="فيسبوك"
          className={`${size} grid place-items-center rounded-full bg-[#1877F2] text-white
                      hover:opacity-90 transition shrink-0`}
        >
          <FacebookIcon className={icon} />
        </a>
      )}
      {instagramUrl && (
        <a
          href={instagramUrl}
          target="_blank"
          rel="noopener noreferrer"
          aria-label="إنستغرام"
          title="إنستغرام"
          className={`${size} grid place-items-center rounded-full text-white shrink-0
                      bg-gradient-to-tr from-[#F58529] via-[#DD2A7B] to-[#8134AF]
                      hover:opacity-90 transition`}
        >
          <InstagramIcon className={icon} />
        </a>
      )}
    </div>
  );
}

/**
 * رموز QR للروابط — للزائر على الحاسوب يفتح الصفحة بهاتفه فيتابعنا.
 *
 * مخفيّة على الهاتف (`hidden sm:block`): من يتصفّح بهاتفه لا يستطيع مسح
 * رمز معروض على الهاتف نفسه، والزرّ فوقه يكفيه.
 */
export function SocialQrCodes({ facebookUrl, instagramUrl }) {
  if (!facebookUrl && !instagramUrl) return null;

  return (
    <div className="hidden sm:flex items-start justify-center gap-8 flex-wrap">
      {facebookUrl && <QrTile url={facebookUrl} label="فيسبوك" />}
      {instagramUrl && <QrTile url={instagramUrl} label="إنستغرام" />}
    </div>
  );
}

function QrTile({ url, label }) {
  const [failed, setFailed] = useState(false);
  if (failed) return null;

  // qrcode.react يرمي استثناءً لو تجاوز الرابط سعة الرمز؛ نلتقطه هنا
  // فيختفي المربّع بدل أن تنهار الصفحة كلّها.
  let qr;
  try {
    qr = (
      <QRCodeSVG
        value={url}
        size={112}
        level="M"
        marginSize={2}
        bgColor="#ffffff"
        fgColor="#0f172a"
      />
    );
  } catch {
    if (!failed) setFailed(true);
    return null;
  }

  return (
    <div className="text-center">
      <div className="inline-block bg-white p-2 rounded-xl border border-slate-200">
        {qr}
      </div>
      <p className="mt-2 text-sm text-slate-600">{label}</p>
    </div>
  );
}
