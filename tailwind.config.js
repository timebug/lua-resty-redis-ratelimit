/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        'neon-green': '#39ff14',
        'neon-pink': '#ff00ff',
        'neon-blue': '#00ffff',
        'dark-bg': '#0a0a0a',
        'grid-line': '#1a1a1a',
      },
      fontFamily: {
        'retro': ['"Press Start 2P"', 'cursive'],
        'cyber': ['"Orbitron"', 'sans-serif'],
      },
      animation: {
        'pulse-fast': 'pulse 1s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      }
    },
  },
  plugins: [],
};
