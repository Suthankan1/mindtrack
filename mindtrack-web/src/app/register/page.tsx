"use client";

import React, { useState, useEffect } from "react";
import { signIn, useSession } from "next-auth/react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import axios from "axios";
import { motion } from "framer-motion";
import {
  Mail,
  Lock,
  AlertTriangle,
  CheckCircle2,
  ArrowRight,
  BrainCircuit,
  User,
  Eye,
  EyeOff,
} from "lucide-react";

export default function RegisterPage() {
  const router = useRouter();
  const { status } = useSession();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [anonymousMode, setAnonymousMode] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  // If already authenticated, redirect to dashboard
  useEffect(() => {
    if (status === "authenticated") {
      router.replace("/dashboard");
    }
  }, [status, router]);

  const validateForm = (): boolean => {
    if (!email || !password || !confirmPassword) {
      setError("Please fill in all fields.");
      return false;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError("Please enter a valid email address.");
      return false;
    }
    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      return false;
    }
    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return false;
    }
    return true;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (!validateForm()) return;

    setIsLoading(true);

    try {
      // Register with the backend
      await axios.post("/api/register", { email, password, anonymousMode });

      setSuccess("Account created! Signing you in…");

      // Auto sign-in after successful registration
      const result = await signIn("credentials", {
        email,
        password,
        redirect: false,
      });

      if (result?.error) {
        // Registration worked but auto-login failed — send to login page
        setSuccess(null);
        setError("Account created. Please log in.");
        setTimeout(() => router.push("/login"), 1500);
      } else {
        router.push("/dashboard");
      }
    } catch (err) {
      if (axios.isAxiosError(err)) {
        const msg =
          err.response?.data?.message ||
          err.response?.data ||
          "Registration failed. Please try again.";
        setError(typeof msg === "string" ? msg : JSON.stringify(msg));
      } else {
        setError("An unexpected error occurred.");
      }
      setIsLoading(false);
    }
  };

  const passwordStrength = () => {
    if (!password) return 0;
    let score = 0;
    if (password.length >= 8) score++;
    if (/[A-Z]/.test(password)) score++;
    if (/[0-9]/.test(password)) score++;
    if (/[^A-Za-z0-9]/.test(password)) score++;
    return score;
  };

  const strengthColor = () => {
    const s = passwordStrength();
    if (s <= 1) return "bg-accent-coral";
    if (s === 2) return "bg-yellow-400";
    if (s === 3) return "bg-blue-400";
    return "bg-accent-teal";
  };

  const strengthLabel = () => {
    const s = passwordStrength();
    if (!password) return "";
    if (s <= 1) return "Weak";
    if (s === 2) return "Fair";
    if (s === 3) return "Good";
    return "Strong";
  };

  return (
    <div className="relative min-h-screen flex items-center justify-center p-4 bg-background overflow-hidden">

      {/* Background blurs */}
      <div className="absolute top-1/4 right-1/4 translate-x-1/2 -translate-y-1/2 w-96 h-96 rounded-full bg-accent-teal/10 blur-[120px] pointer-events-none" />
      <div className="absolute bottom-1/4 left-1/4 -translate-x-1/2 translate-y-1/2 w-96 h-96 rounded-full bg-accent-coral/10 blur-[120px] pointer-events-none" />

      <div className="relative w-full max-w-md z-10">

        {/* Branding */}
        <div className="flex flex-col items-center mb-8 text-center">
          <motion.div
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ duration: 0.5, ease: "easeOut" }}
            className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-accent-teal to-accent-coral p-[1.5px] mb-4 shadow-glow"
          >
            <div className="w-full h-full rounded-[14px] bg-[#0A0A14] flex items-center justify-center">
              <BrainCircuit className="w-7 h-7 text-accent-teal" />
            </div>
          </motion.div>

          <motion.h1
            initial={{ y: 10, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="text-3xl font-bold tracking-tight font-display bg-gradient-to-b from-white to-gray-400 bg-clip-text text-transparent"
          >
            Create Account
          </motion.h1>
          <motion.p
            initial={{ y: 10, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="text-xs text-muted mt-2 max-w-[280px]"
          >
            Join Mind<span className="text-accent-coral">Track</span> and start your mental wellness journey today.
          </motion.p>
        </div>

        {/* Registration Card */}
        <motion.div
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="glass-elevated p-8 rounded-3xl shadow-2xl relative overflow-hidden"
        >
          <div className="absolute top-0 inset-x-0 h-[1px] bg-gradient-to-r from-transparent via-white/10 to-transparent" />

          <form onSubmit={handleSubmit} className="space-y-5">

            {/* Error Message */}
            {error && (
              <div className="flex items-start gap-3 p-3.5 rounded-xl bg-accent-coral/10 border border-accent-coral/20 text-accent-coral text-xs">
                <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{error}</span>
              </div>
            )}

            {/* Success Message */}
            {success && (
              <div className="flex items-start gap-3 p-3.5 rounded-xl bg-accent-teal/10 border border-accent-teal/20 text-accent-teal text-xs">
                <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{success}</span>
              </div>
            )}

            {/* Email */}
            <div className="space-y-2">
              <label htmlFor="reg-email" className="text-xs font-semibold text-gray-300 ml-1">
                Email Address
              </label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  id="reg-email"
                  type="email"
                  value={email}
                  onChange={(e) => { setEmail(e.target.value); setError(null); }}
                  placeholder="name@example.com"
                  required
                  autoComplete="email"
                  className="auth-input w-full pl-11 pr-4 py-3 border border-white/20 focus:border-accent-teal rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-accent-teal/30 transition-all duration-300 shadow-sm"
                />
              </div>
            </div>

            {/* Password */}
            <div className="space-y-2">
              <label htmlFor="reg-password" className="text-xs font-semibold text-gray-300 ml-1">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  id="reg-password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => { setPassword(e.target.value); setError(null); }}
                  placeholder="Min. 6 characters"
                  required
                  autoComplete="new-password"
                  className="auth-input w-full pl-11 pr-11 py-3 border border-white/20 focus:border-accent-teal rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-accent-teal/30 transition-all duration-300 shadow-sm"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((p) => !p)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-muted hover:text-foreground transition-colors"
                  aria-label="Toggle password visibility"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {/* Password strength bar */}
              {password && (
                <div className="px-1">
                  <div className="flex gap-1 mt-1.5">
                    {[1, 2, 3, 4].map((i) => (
                      <div
                        key={i}
                        className={`h-0.5 flex-1 rounded-full transition-all duration-300 ${
                          i <= passwordStrength() ? strengthColor() : "bg-white/10"
                        }`}
                      />
                    ))}
                  </div>
                  <p className={`text-[10px] mt-1 ${
                    passwordStrength() <= 1 ? "text-accent-coral" :
                    passwordStrength() === 2 ? "text-yellow-400" :
                    passwordStrength() === 3 ? "text-blue-400" : "text-accent-teal"
                  }`}>
                    {strengthLabel()}
                  </p>
                </div>
              )}
            </div>

            {/* Confirm Password */}
            <div className="space-y-2">
              <label htmlFor="reg-confirm" className="text-xs font-semibold text-gray-300 ml-1">
                Confirm Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  id="reg-confirm"
                  type={showConfirm ? "text" : "password"}
                  value={confirmPassword}
                  onChange={(e) => { setConfirmPassword(e.target.value); setError(null); }}
                  placeholder="Re-enter password"
                  required
                  autoComplete="new-password"
                  className={`auth-input w-full pl-11 pr-11 py-3 border rounded-xl text-sm focus:outline-none focus:ring-2 transition-all duration-300 shadow-sm ${
                    confirmPassword && confirmPassword !== password
                      ? "border-accent-coral focus:ring-accent-coral/30 focus:border-accent-coral"
                      : confirmPassword && confirmPassword === password
                      ? "border-accent-teal focus:ring-accent-teal/30 focus:border-accent-teal"
                      : "border-white/20 focus:ring-accent-teal/30 focus:border-accent-teal"
                  }`}
                />
                <button
                  type="button"
                  onClick={() => setShowConfirm((p) => !p)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-muted hover:text-foreground transition-colors"
                  aria-label="Toggle confirm password visibility"
                >
                  {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Anonymous Mode Toggle */}
            <div className="flex items-center justify-between px-1 py-2 rounded-xl bg-white/[0.02] border border-white/5">
              <div className="flex items-center gap-2.5">
                <User className="w-4 h-4 text-muted" />
                <div>
                  <p className="text-xs font-medium text-gray-300">Anonymous Mode</p>
                  <p className="text-[10px] text-muted">Hide your identity in shared features</p>
                </div>
              </div>
              <button
                type="button"
                role="switch"
                aria-checked={anonymousMode}
                onClick={() => setAnonymousMode((v) => !v)}
                className={`relative w-10 h-5 rounded-full transition-colors duration-300 focus:outline-none focus:ring-2 focus:ring-accent-teal/30 ${
                  anonymousMode ? "bg-accent-teal" : "bg-white/10"
                }`}
              >
                <span
                  className={`absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform duration-300 ${
                    anonymousMode ? "translate-x-5" : "translate-x-0"
                  }`}
                />
              </button>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              id="register-submit"
              disabled={isLoading}
              className="relative w-full py-3.5 rounded-xl bg-gradient-to-r from-accent-teal to-accent-coral text-background font-bold text-sm tracking-wide shadow-lg hover:shadow-glow hover:opacity-95 active:scale-[0.98] transition-all duration-300 flex items-center justify-center gap-2 disabled:opacity-50 disabled:pointer-events-none mt-2"
            >
              {isLoading ? (
                <div className="w-5 h-5 border-2 border-background border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <span>Create Account</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          {/* Divider */}
          <div className="mt-8 pt-6 border-t border-white/5 text-center">
            <p className="text-xs text-muted">
              Already have an account?{" "}
              <Link href="/login" className="text-accent-teal hover:underline font-semibold">
                Log in
              </Link>
            </p>
          </div>
        </motion.div>

        {/* Terms note */}
        <p className="text-center text-[10px] text-muted/50 mt-6 px-4">
          By creating an account, you agree to our{" "}
          <span className="text-muted/80">Terms of Service</span> and{" "}
          <span className="text-muted/80">Privacy Policy</span>.
        </p>
      </div>
    </div>
  );
}
