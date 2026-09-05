import { useEffect, useRef, useState } from 'react';
import SocialLinks from './SocialLinks.jsx';

/// أقسام صفحة الهبوط الأربعة.
///
/// كل قسم له فيديوان: واحد للهاتف وآخر للحاسوب.
const SECTIONS = [
  {
    id: 'welcome',
    videoMobile: '/videos/1-mobile.mp4',
    videoDesktop: '/videos/1-desktop.mp4',
    title: 'welcomeTitle',
    body: 'welcomeBody',
  },
  {
    id: 'kinds',
    videoMobile: '/videos/2-mobile.mp4',
    videoDesktop: '/videos/2-desktop.mp4',
    title: 'categoriesTitle',
    body: 'categoriesBody',
  },
  {
    id: 'fabric',
    videoMobile: '/videos/3-mobile.mp4',
    videoDesktop: '/videos/3-desktop.mp4',
    title: 'fabricTitle',
    body: 'fabricBody',
  },
  {
    id: 'contact',
    videoMobile: '/videos/4-mobile.mp4',
    videoDesktop: '/videos/4-desktop.mp4',
    title: 'contactTitle',
    body: 'contactBody',
  },
];

/// نقرأ حجم الشاشة مرة واحدة لتحديد أي فيديو نحمّل.
/// useMediaQuery المدمجة — بدون مكتبة خارجية.
function useIsDesktop() {
  const [isDesktop, setIsDesktop] = useState(
    () => window.matchMedia('(min-width: 768px)').matches,
  );
  useEffect(() => {
    const mq = window.matchMedia('(min-width: 768px)');
    const handler = (e) => setIsDesktop(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);
  return isDesktop;
}

/// خلفية القسم: فيديو يُختار بـ JavaScript حسب حجم الشاشة.
///
/// ⚠️ لا نستخدم <source media> داخل <video> لأن Chrome يتجاهل
/// خاصية media في <source> ويأخذ أول مصدر دائماً بغض النظر.
/// الحل الموثوق: تعيين src مباشرة على عنصر الفيديو.
function SectionBackground({ videoMobile, videoDesktop, active, index }) {
  const ref = useRef(null);
  const [failed, setFailed] = useState(false);
  const isDesktop = useIsDesktop();

  // عند تغيير حجم الشاشة أو تحديد الفيديو المناسب: نحمّل المصدر الصحيح
  useEffect(() => {
    const el = ref.current;
    if (!el || failed) return;
    const src = isDesktop ? videoDesktop : videoMobile;
    // لا نعيد التحميل إذا كان المصدر نفسه (يتجنب وميض الشاشة)
    if (!el.src.endsWith(src.replace('/videos/', ''))) {
      el.src = src;
      el.load();
    }
  }, [isDesktop, videoMobile, videoDesktop, failed]);

  // تشغيل/إيقاف حسب القسم الظاهر
  useEffect(() => {
    const el = ref.current;
    if (!el || failed) return;
    if (active) {
      el.play().catch(() => {
        // التشغيل التلقائي مرفوض — الخلفية تبقى ساكنة على أول إطار
      });
    } else {
      el.pause();
    }
  }, [active, failed]);

  // تدرّجات بيج احتياطية لكل قسم
  const fallbacks = [
    'from-sand-100 via-sand-50 to-sand-200',
    'from-sand-200 via-sand-100 to-sand-50',
    'from-sand-50 via-sand-200 to-sand-100',
    'from-sand-200 via-sand-50 to-sand-300',
  ];

  return (
    <>
      {/* طبقة التدرّج: تظهر أثناء التحميل وعند فشل الفيديو */}
      <div
        className={`absolute inset-0 bg-gradient-to-br ${fallbacks[index % 4]}`}
      />

      {/* الفيديو — يُخفى عند الفشل ويُترك التدرّج وحده */}
      {!failed && (
        <video
          ref={ref}
          muted
          loop
          playsInline
          preload="metadata"
          onError={() => setFailed(true)}
          src={isDesktop ? videoDesktop : videoMobile}
          className="absolute inset-0 w-full h-full object-cover"
        />
      )}
    </>
  );
}

/// صفحة الهبوط: أربعة مشاهد بيج، كل لمسة تنقل إلى التالي.
export default function LandingPage({
  t,
  storeName,
  tagline,
  phone,
  facebookUrl,
  instagramUrl,
  onEnterShop,
}) {
  const [active, setActive] = useState(0);
  const containerRef = useRef(null);
  const sectionRefs = useRef([]);

  // نعرف القسم الظاهر بمراقب التقاطع لا بحساب مواضع التمرير يدوياً:
  // الحساب اليدوي يخطئ مع اختلاف ارتفاع شريط المتصفّح على الهاتف.
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const index = Number(entry.target.dataset.index);
            if (!Number.isNaN(index)) setActive(index);
          }
        });
      },
      { threshold: 0.55 },
    );
    sectionRefs.current.forEach((el) => el && observer.observe(el));
    return () => observer.disconnect();
  }, []);

  function goTo(index) {
    const el = sectionRefs.current[index];
    if (el) el.scrollIntoView({ behavior: 'smooth' });
  }

  return (
    <div
      ref={containerRef}
      className="h-screen overflow-y-auto snap-y snap-mandatory bg-sand-50"
    >
      {/* مؤشّر المشاهد — يبيّن للزائر أنه في صفحة من أربع */}
      <div className="fixed z-30 top-1/2 -translate-y-1/2 end-4 flex flex-col gap-3">
        {SECTIONS.map((s, i) => (
          <button
            key={s.id}
            onClick={() => goTo(i)}
            aria-label={t[s.title]}
            className={`w-2.5 rounded-full transition-all ${
              i === active ? 'h-8 bg-ink' : 'h-2.5 bg-ink/30 hover:bg-ink/50'
            }`}
          />
        ))}
      </div>

      {SECTIONS.map((section, index) => (
        <section
          key={section.id}
          data-index={index}
          ref={(el) => (sectionRefs.current[index] = el)}
          className="relative h-screen snap-start snap-always overflow-hidden
                     flex items-center justify-center"
        >
          <SectionBackground
            videoMobile={section.videoMobile}
            videoDesktop={section.videoDesktop}
            active={index === active}
            index={index}
          />


          <div className="relative z-10 px-6 max-w-2xl text-center">
            {index === 0 && (
              <img
                src="/logo.png"
                alt=""
                className="w-24 h-24 mx-auto mb-6 opacity-90"
              />
            )}

            <h2 className="text-3xl md:text-5xl font-bold text-ink leading-tight">
              {index === 0 ? `${t.welcomeTitle}` : t[section.title]}
            </h2>

            {/* جملة صاحب المحل تظهر في المشهد الأول **بالعربية وحدها** */}
            <p className="mt-4 text-base md:text-lg text-ink/70 leading-relaxed">
              {index === 0 && tagline && t.lang === 'ar'
                ? tagline
                : t[section.body]}
            </p>

            {/* المشهد الأخير: التواصل ودخول المتجر */}
            {index === SECTIONS.length - 1 && (
              <div className="mt-8 flex flex-col items-center gap-5">
                <SocialLinks
                  facebookUrl={facebookUrl}
                  instagramUrl={instagramUrl}
                />
                {phone && (
                  <a
                    href={`tel:${phone}`}
                    dir="ltr"
                    className="text-lg font-bold text-accent tracking-wide"
                  >
                    {phone}
                  </a>
                )}
                <button
                  onClick={onEnterShop}
                  className="rounded-full bg-ink text-sand-50 px-10 py-3.5
                             text-lg font-bold hover:bg-ink/85 transition
                             shadow-lg shadow-ink/20"
                >
                  {t.enterShop}
                </button>
              </div>
            )}

            {/* تلميح التمرير — يختفي في المشهد الأخير */}
            {index < SECTIONS.length - 1 && (
              <button
                onClick={() => goTo(index + 1)}
                className="mt-10 inline-flex flex-col items-center gap-1
                           text-ink/50 hover:text-ink transition"
              >
                <span className="text-xs">{t.scrollHint}</span>
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  className="w-6 h-6 animate-bounce"
                >
                  <path d="M6 9l6 6 6-6" strokeLinecap="round" />
                </svg>
              </button>
            )}
          </div>

          {/* اسم المحل ثابت أعلى كل مشهد */}
          <div className="absolute top-6 inset-x-0 text-center z-10">
            <span className="text-sm font-bold tracking-[0.3em] text-ink/50 uppercase">
              {storeName}
            </span>
          </div>
        </section>
      ))}
    </div>
  );
}
