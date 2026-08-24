/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      fontFamily: { sans: ['Cairo', 'system-ui', 'sans-serif'] },
      colors: {
        // أخضر عميق + ذهبي هادئ: لهجة لباس رجالي محتشم، لا أزرق تقني.
        brand: { DEFAULT: '#1F4E3D', dark: '#143528', accent: '#B4884A' },
      },
    },
  },
  plugins: [],
};
