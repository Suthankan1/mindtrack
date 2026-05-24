import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "var(--background)",
        foreground: "var(--foreground)",
        surface: "var(--surface)",
        elevated: "var(--elevated)",
        "accent-coral": "var(--accent-coral)",
        "accent-teal": "var(--accent-teal)",
      },
      fontFamily: {
        display: ["var(--font-display)", "sans-serif"],
        sans: ["var(--font-dm-sans)", "sans-serif"],
      },
      boxShadow: {
        glow: "0 0 20px rgba(0, 210, 200, 0.15)",
        "glow-coral": "0 0 20px rgba(255, 107, 107, 0.15)",
      },
    },
  },
  plugins: [],
};
export default config;
