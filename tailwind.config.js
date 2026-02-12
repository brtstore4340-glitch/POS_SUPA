/** @type {import("tailwindcss").Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx,ts,tsx}"],
  darkMode: ["class"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["'Noto Sans Thai'", "sans-serif"],
      },
      colors: {
        primary: {
          DEFAULT: "#4285F4", // Google Blue
          foreground: "#FFFFFF",
        },
        secondary: {
          DEFAULT: "#e8f0fe", // Light Google Blue background
          foreground: "#1967d2", // Darker blue text
        },
        destructive: {
          DEFAULT: "#EA4335", // Google Red
          foreground: "#FFFFFF",
        },
        success: {
          DEFAULT: "#34A853", // Google Green
          foreground: "#FFFFFF",
        },
        warning: {
          DEFAULT: "#FBBC05", // Google Yellow
          foreground: "#FFFFFF",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        border: "hsl(var(--border))",
        ring: "hsl(var(--ring))",
        boots: {
          base: {
            DEFAULT: "hsl(var(--boots))",
            foreground: "hsl(var(--boots-foreground))"
          },
          light: "hsl(var(--boots-light))"
        },
        discount: {
          DEFAULT: "hsl(var(--discount))",
          foreground: "hsl(var(--discount-foreground))"
        }
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      ringColor: {
        "boots-base": "hsl(var(--boots))",
        "boots-light": "hsl(var(--boots-light))",
        "discount": "hsl(var(--discount))"
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};
