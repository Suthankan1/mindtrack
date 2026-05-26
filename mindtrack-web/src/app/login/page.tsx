"use client";

import React, { useState, useEffect } from "react";
import { signIn, useSession } from "next-auth/react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { motion } from "framer-motion";
import { Mail, Lock, AlertTriangle, ArrowRight, BrainCircuit } from "lucide-react";

const normalizeEmail = (value: string) => value.trim().toLowerCase();

export default function LoginPage() {
  const router = useRouter();
  const { status } = useSession();
  
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  // If already authenticated, redirect straight to dashboard
  useEffect(() => {
    if (status === "authenticated") {
      router.replace("/dashboard");
    }
  }, [status, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setError("Please fill in all fields.");
      return;
    }

    setIsLoading(true);
    setError(null);
    const normalizedEmail = normalizeEmail(email);

    try {
      const result = await signIn("credentials", {
        email: normalizedEmail,
        password,
        redirect: false,
      });

      if (result?.error) {
        // Parse error message
        setError(result.error || "Authentication failed. Please verify your credentials.");
        setIsLoading(false);
      } else {
        router.push("/dashboard");
      }
    } catch {
      setError("An unexpected network error occurred.");
      setIsLoading(false);
    }
  };

  return (
    <div className="relative min-h-screen flex items-center justify-center p-4 bg-background overflow-hidden">
      
      {/* Background Decorative Mesh Blurs */}
      <div className="absolute top-1/4 left-1/4 -translate-x-1/2 -translate-y-1/2 w-96 h-96 rounded-full bg-accent-teal/10 blur-[120px] pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/4 translate-x-1/2 translate-y-1/2 w-96 h-96 rounded-full bg-accent-coral/10 blur-[120px] pointer-events-none" />

      {/* Main Container */}
      <div className="relative w-full max-w-md z-10">
        
        {/* Logo/Branding */}
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
            Mind<span className="text-accent-coral">Track</span>
          </motion.h1>
          <motion.p 
            initial={{ y: 10, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="text-xs text-muted mt-2 max-w-[280px]"
          >
            Sign in with your registered email and password to access your personal dashboard.
          </motion.p>
        </div>

        {/* Glassmorphic Login Card */}
        <motion.div 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="glass-elevated p-8 rounded-3xl shadow-2xl relative overflow-hidden"
        >
          {/* Subtle top light reflection strip */}
          <div className="absolute top-0 inset-x-0 h-[1px] bg-gradient-to-r from-transparent via-white/10 to-transparent" />

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-5">
            {error && (
              <div className="flex items-start gap-3 p-3.5 rounded-xl bg-accent-coral/10 border border-accent-coral/20 text-accent-coral text-xs animate-shake">
                <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{error}</span>
              </div>
            )}

            {/* Email Field */}
            <div className="space-y-2">
              <label className="text-xs font-semibold text-gray-300 ml-1">Email Address</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value.toLowerCase())}
                  placeholder="name@example.com"
                  required
                  className="auth-input w-full pl-11 pr-4 py-3 border border-white/20 focus:border-accent-teal rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-accent-teal/30 transition-all duration-300 shadow-sm"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-2">
              <div className="flex justify-between items-center px-1">
                <label className="text-xs font-semibold text-gray-300">Password</label>
                <button
                  type="button"
                  onClick={() => setError('Password recovery is not available in this version. Please contact support.')}
                  className="text-[10px] text-accent-teal hover:underline font-medium"
                >
                  Forgot?
                </button>
              </div>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="auth-input w-full pl-11 pr-4 py-3 border border-white/20 focus:border-accent-teal rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-accent-teal/30 transition-all duration-300 shadow-sm"
                />
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={isLoading}
              className="relative w-full py-3.5 rounded-xl bg-gradient-to-r from-accent-teal to-accent-coral text-background font-bold text-sm tracking-wide shadow-lg hover:shadow-glow hover:opacity-95 active:scale-[0.98] transition-all duration-300 flex items-center justify-center gap-2 disabled:opacity-50 disabled:pointer-events-none mt-2"
            >
              {isLoading ? (
                <div className="w-5 h-5 border-2 border-background border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <span>Log In to Dashboard</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

        </motion.div>

        {/* Footer text */}
        <p className="text-center text-xs text-muted mt-8">
          Don&apos;t have an account?{" "}
          <Link href="/register" className="text-accent-teal hover:underline font-semibold">Sign up</Link>
        </p>
      </div>
    </div>
  );
}
