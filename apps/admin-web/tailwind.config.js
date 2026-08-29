/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Neutral palette — matches Figma #0f172a → #f8fafc
        ink: {
          50:  '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          900: '#0f172a',
        },
        // Brand — from Figma: primary #1e6b9a, accent #3b9ec2
        brand: {
          50:  '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#3b9ec2',   // Figma accent / lighter brand
          500: '#1e6b9a',   // Figma primary button fill
          600: '#1a5f89',
          700: '#1e3a5f',   // Figma dark navy text
          800: '#172d4a',
          900: '#0f2034',
        },
        // Semantic states
        success: {
          100: '#dcfce7',
          500: '#22c55e',
          600: '#16a34a',
          700: '#15803d',
        },
        warning: {
          100: '#fef3c7',
          500: '#f59e0b',
          600: '#d97706',
          700: '#92400e',
        },
        danger: {
          100: '#fee2e2',
          500: '#ef4444',
          600: '#dc2626',
          700: '#991b1b',
        },
        // Figma sky accent used in chart lines
        sky: { 400: '#0ea5e9' },
      },
      spacing: {
        sidebar: '260px',   // Figma: 260px sidebar width
        topbar:  '64px',
      },
      fontFamily: {
        // Figma uses Figtree — load from Google Fonts in index.css
        sans: ['Figtree', 'ui-sans-serif', 'system-ui', '-apple-system', 'sans-serif'],
      },
      borderRadius: {
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
      boxShadow: {
        card: '0 1px 3px 0 rgb(0 0 0 / 0.06), 0 1px 2px -1px rgb(0 0 0 / 0.04)',
        panel: '0 4px 24px -4px rgb(0 0 0 / 0.08)',
      },
    },
  },
  plugins: [],
};
