import { useEffect, useRef, useState } from "react";
import { Container } from "@/components/ui/grid";
import { httpsCallable } from "firebase/functions";
import { functions } from "@/firebase";

const RECAPTCHA_SITE_KEY = import.meta.env.VITE_RECAPTCHA_SITE_KEY || "6Lc71z4sAAAAAMxG25t_oi47_986McgLXdfbTWh9";

export default function SetupPage() {
  const recaptchaRef = useRef(null);
  const [recaptchaToken, setRecaptchaToken] = useState(null);
  const [isScriptLoaded, setIsScriptLoaded] = useState(false);

  useEffect(() => {
    // Load reCAPTCHA Enterprise script
    const script = document.createElement("script");
    script.src = "https://www.google.com/recaptcha/enterprise.js?render=" + RECAPTCHA_SITE_KEY;
    script.async = true;
    script.defer = true;
    script.onload = () => setIsScriptLoaded(true);
    document.head.appendChild(script);

    return () => {
      document.head.removeChild(script);
    };
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!window.grecaptcha) {
      alert("reCAPTCHA not loaded yet");
      return;
    }

    try {
      // Execute reCAPTCHA
      const token = await window.grecaptcha.enterprise.execute(RECAPTCHA_SITE_KEY, {
        action: "SETUP"
      });
      
      setRecaptchaToken(token);
      console.log("✅ reCAPTCHA token:", token);
      
      // Send token to backend for verification
      const verifyRecaptcha = httpsCallable(functions, "verifyRecaptcha");
      const result = await verifyRecaptcha({ token, action: "SETUP" });
      
      console.log("✅ Verification result:", result.data);
      
      if (result.data.success) {
        alert(`reCAPTCHA verified! Score: ${result.data.score.toFixed(2)}`);
      } else {
        alert(`reCAPTCHA failed: ${result.data.error}`);
      }
      
    } catch (error) {
      console.error("❌ reCAPTCHA error:", error);
      alert(`Error: ${error.message}`);
    }
  };

  return (
    <Container className="py-12">
      <div className="max-w-md mx-auto bg-white dark:bg-slate-900 rounded-xl shadow-lg border border-slate-200 dark:border-slate-700 p-8">
        <h1 className="text-2xl font-bold text-slate-800 dark:text-slate-200 mb-2">
          Setup Page
        </h1>
        <p className="text-slate-600 dark:text-slate-400 mb-6">
          This page is protected by reCAPTCHA Enterprise
        </p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Email
            </label>
            <input
              type="email"
              className="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100"
              placeholder="Enter your email"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Password
            </label>
            <input
              type="password"
              className="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100"
              placeholder="Enter your password"
            />
          </div>

          {/* reCAPTCHA widget container */}
          <div 
            ref={recaptchaRef}
            className="g-recaptcha"
            data-sitekey={RECAPTCHA_SITE_KEY}
            data-action="SETUP"
          />

          <button
            type="submit"
            disabled={!isScriptLoaded}
            className="w-full py-2 px-4 bg-blue-600 hover:bg-blue-700 disabled:bg-slate-400 text-white font-medium rounded-md transition-colors"
          >
            {isScriptLoaded ? "Submit" : "Loading reCAPTCHA..."}
          </button>
        </form>

        {recaptchaToken && (
          <div className="mt-4 p-3 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-md">
            <p className="text-sm text-green-800 dark:text-green-200">
              ✅ reCAPTCHA verified!
            </p>
            <p className="text-xs text-green-600 dark:text-green-400 mt-1 break-all">
              Token: {recaptchaToken.substring(0, 50)}...
            </p>
          </div>
        )}

        <p className="mt-6 text-xs text-slate-500 dark:text-slate-500 text-center">
          Protected by reCAPTCHA Enterprise
        </p>
      </div>
    </Container>
  );
}
