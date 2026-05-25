"use client";

import React from "react";
import { AlertCircle, RefreshCw } from "lucide-react";
import { motion } from "framer-motion";

interface CosmicErrorCardProps {
  title?: string;
  message: string;
  onRetry?: () => void;
  isLoading?: boolean;
}

export default function CosmicErrorCard({
  title = "Cognitive Companion Offline",
  message,
  onRetry,
  isLoading = false,
}: CosmicErrorCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.96 }}
      animate={{ opacity: 1, scale: 1 }}
      className="relative overflow-hidden p-8 rounded-3xl bg-gradient-to-br from-[#1C1C3A]/30 to-[#0A0A14]/80 border border-white/10 backdrop-blur-xl shadow-2xl flex flex-col md:flex-row items-center gap-6 justify-between max-w-4xl mx-auto my-6 z-10"
    >
      {/* Background Decorative Blur Blobs */}
      <div className="absolute -top-12 -left-12 w-36 h-36 bg-accent-coral rounded-full blur-[80px] opacity-[0.08] pointer-events-none" />
      <div className="absolute -bottom-12 -right-12 w-36 h-36 bg-purple-500 rounded-full blur-[80px] opacity-[0.08] pointer-events-none" />

      <div className="flex items-start gap-4 flex-1 w-full">
        <div className="w-12 h-12 rounded-2xl bg-accent-coral/10 border border-accent-coral/20 flex items-center justify-center text-accent-coral shrink-0">
          <AlertCircle className="w-6 h-6 animate-pulse" />
        </div>
        
        <div className="space-y-2 flex-1 min-w-0">
          <h3 className="text-md font-bold text-white font-display flex items-center gap-2">
            {title}
            <span className="px-2 py-0.5 rounded-md bg-accent-coral/10 border border-accent-coral/20 text-accent-coral text-[8px] font-bold uppercase tracking-wider">
              Offline
            </span>
          </h3>
          <p className="text-xs text-gray-300 leading-relaxed font-sans">
            {message}
          </p>
        </div>
      </div>

      {onRetry && (
        <button
          onClick={onRetry}
          disabled={isLoading}
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-accent-coral/10 hover:bg-accent-coral/20 border border-accent-coral/20 hover:border-accent-coral/40 text-xs font-bold text-accent-coral uppercase tracking-wider transition-all disabled:opacity-50 hover:shadow-glow-coral shrink-0 active:scale-95 duration-200"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? "animate-spin" : ""}`} />
          Reconnect Engine
        </button>
      )}
    </motion.div>
  );
}
