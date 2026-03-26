/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./**/*.html'],
  theme: {
    extend: {
      colors: {
        background: { DEFAULT: '#0F1219', secondary: '#161B26' },
        foreground: { DEFAULT: '#f5f5f7', muted: 'rgba(255,255,255,0.45)', subtle: 'rgba(255,255,255,0.25)' },
        clear: { DEFAULT: '#4DAD80', end: '#21C45E', text: '#17A348' },
        moderate: { DEFAULT: '#FDC021', end: '#F59F0A', text: '#D97605' },
        heavy: { DEFAULT: '#F77070', end: '#F04545', text: '#DB2626' },
        slate: { DEFAULT: '#94A3B8', text: '#647390' },
        border: { DEFAULT: 'rgba(255,255,255,0.08)', hover: 'rgba(255,255,255,0.12)', strong: 'rgba(255,255,255,0.15)' },
        card: { DEFAULT: 'rgba(255,255,255,0.02)', hover: 'rgba(255,255,255,0.04)' },
      },
      borderRadius: {
        card: '12px',
        badge: '20px',
        button: '10px',
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'system-ui', 'sans-serif'],
      },
      letterSpacing: {
        heading: '-0.03em',
        tight: '-0.04em',
      },
      maxWidth: {
        site: '1200px',
      },
    },
  },
  plugins: [],
}
