/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      fontFamily: { sans: ['Cairo', 'system-ui', 'sans-serif'] },
      colors: {
        // لوحة بيج دافئة: لباس رجالي محتشم لا واجهة تقنية.
        // الأرقام تتدرّج من أفتح رمل إلى أعمقه، والحبر بنّي داكن لا أسود
        // خالص — الأسود فوق البيج يبدو قاسياً ويُتعب العين.
        sand: {
          50: '#FBF7F0',
          100: '#F5EDE1',
          200: '#EADDC8',
          300: '#DCC9AC',
          400: '#C9B08B',
        },
        ink: '#3A3129',
        accent: '#8C6D46',
        // يبقى `brand` للتوافق مع المكوّنات التي تستعمله.
        brand: { DEFAULT: '#8C6D46', dark: '#6E5334', accent: '#B4884A' },
      },
    },
  },
  plugins: [],
};
