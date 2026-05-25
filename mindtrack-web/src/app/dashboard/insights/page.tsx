"use client";

import React, { useState, useEffect, useCallback } from "react";
import { useSession } from "next-auth/react";
import { motion, AnimatePresence } from "framer-motion";
import axios from "axios";
import {
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
  Legend
} from "recharts";
import {
  Sparkles,
  Download,
  Brain,
  Activity,
  Clock,
  RefreshCw,
  AlertCircle,
  FileText,
  CheckCircle2,
  Calendar
} from "lucide-react";
import CosmicErrorCard from "@/components/CosmicErrorCard";

interface MoodDistributionItem {
  name: string;
  value: number;
  score: number;
  color: string;
}

interface TimeOfDayItem {
  hourLabel: string;
  hour: number;
  avgScore: number;
}

interface WeeklyInsightsResponse {
  insight: string;
  moodDistribution: MoodDistributionItem[];
  timeOfDay: TimeOfDayItem[];
}

interface MoodAnomalyResponse {
  riskLevel: "LOW" | "MEDIUM" | "HIGH";
  detectedPatterns: string[];
  suggestedAction: string;
  supportiveInsight: string;
  confidence: number;
  insufficientData: boolean;
}

type ToastState = {
  message: string;
  type: "success" | "error";
} | null;

const sanitizePdfText = (value: string) =>
  value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\x20-\x7E]/g, "")
    .replace(/\s+/g, " ")
    .trim();

const escapePdfText = (value: string) =>
  sanitizePdfText(value).replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");

const wrapPdfText = (text: string, maxLength = 92) => {
  const words = sanitizePdfText(text).split(" ").filter(Boolean);
  const lines: string[] = [];
  let currentLine = "";

  words.forEach((word) => {
    const nextLine = currentLine ? `${currentLine} ${word}` : word;
    if (nextLine.length > maxLength) {
      if (currentLine) lines.push(currentLine);
      currentLine = word;
    } else {
      currentLine = nextLine;
    }
  });

  if (currentLine) lines.push(currentLine);
  return lines;
};

const createWeeklyReportPdf = (insights: WeeklyInsightsResponse, userEmail?: string | null) => {
  const createdAt = new Date();
  const lines = [
    { text: "MindTrack Weekly Insights Report", size: 20, gap: 28 },
    { text: `Generated: ${createdAt.toLocaleString()}`, size: 10, gap: 16 },
    { text: `Account: ${userEmail || "MindTrack user"}`, size: 10, gap: 26 },
    { text: "Cognitive Analysis Insight", size: 14, gap: 20 },
    ...wrapPdfText(insights.insight || "No AI insight is available yet.").map((text) => ({ text, size: 11, gap: 14 })),
    { text: " ", size: 4, gap: 10 },
    { text: "Mood Distribution", size: 14, gap: 20 },
    ...(insights.moodDistribution.length
      ? insights.moodDistribution.map((item) => ({
          text: `${item.name}: ${item.value}% of logs, score ${item.score}/5`,
          size: 11,
          gap: 15,
        }))
      : [{ text: "No mood distribution data is available yet.", size: 11, gap: 15 }]),
    { text: " ", size: 4, gap: 10 },
    { text: "Mood Patterns by Hour", size: 14, gap: 20 },
    ...(insights.timeOfDay.length
      ? insights.timeOfDay.map((item) => ({
          text: `${item.hourLabel}: average mood ${item.avgScore}/5`,
          size: 11,
          gap: 15,
        }))
      : [{ text: "No hourly pattern data is available yet.", size: 11, gap: 15 }]),
  ];

  let y = 760;
  const stream = lines
    .map((line) => {
      if (y < 48) return null;
      const command = `BT /F1 ${line.size} Tf 48 ${y} Td (${escapePdfText(line.text)}) Tj ET`;
      y -= line.gap;
      return command;
    })
    .filter(Boolean)
    .join("\n");

  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`,
  ];

  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(pdf.length);
    pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xrefOffset = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  offsets.slice(1).forEach((offset) => {
    pdf += `${offset.toString().padStart(10, "0")} 00000 n \n`;
  });
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`;

  return new Blob([pdf], { type: "application/pdf" });
};

export default function InsightsPage() {
  const { data: session, status } = useSession();
  const [mounted, setMounted] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Data States
  const [insights, setInsights] = useState<WeeklyInsightsResponse | null>(null);
  const [anomaly, setAnomaly] = useState<MoodAnomalyResponse | null>(null);
  const [isAnomalyLoading, setIsAnomalyLoading] = useState(true);

  // Interaction States
  const [isDownloading, setIsDownloading] = useState(false);
  const [toast, setToast] = useState<ToastState>(null);

  useEffect(() => {
    setMounted(true);
  }, []);

  const fetchInsights = useCallback(async () => {
    if (!session?.user?.accessToken) return;
    setIsLoading(true);
    setIsAnomalyLoading(true);
    
    // Fetch weekly insights
    try {
      const res = await axios.get("/api/insights/weekly", {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });
      setInsights(res.data);
      setError(null);
    } catch (err: unknown) {
      console.error("Error loading weekly insights:", err);
      setError("Failed to secure connection with the cognitive engine. Please verify the API is online.");
    } finally {
      setIsLoading(false);
    }

    // Fetch weekly anomalies
    try {
      const res = await axios.get("/api/ai/anomaly/weekly", {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });
      setAnomaly(res.data);
    } catch (err: unknown) {
      console.error("Error loading weekly anomalies:", err);
    } finally {
      setIsAnomalyLoading(false);
    }
  }, [session]);

  useEffect(() => {
    if (status === "authenticated") {
      fetchInsights();
    } else if (status === "unauthenticated") {
      setIsLoading(false);
    }
  }, [status, fetchInsights]);

  const handleDownload = async () => {
    if (isDownloading) return;

    if (!insights) {
      setToast({ message: "Weekly insights are still loading. Please try again in a moment.", type: "error" });
      setTimeout(() => setToast(null), 4000);
      return;
    }

    setIsDownloading(true);

    try {
      const blob = createWeeklyReportPdf(insights, session?.user?.email);
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.setAttribute("download", `mindtrack-weekly-report-${new Date().toISOString().split("T")[0]}.pdf`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      setToast({ message: "Weekly PDF report compiled and downloaded successfully!", type: "success" });
    } catch (err: unknown) {
      console.error("Weekly report download failure:", err);
      setToast({ message: "Failed to compile and download the weekly PDF. Please try again.", type: "error" });
    } finally {
      setIsDownloading(false);
      setTimeout(() => setToast(null), 4000);
    }
  };

  // Recharts Custom Tooltip for PieChart
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const CustomPieTooltip = ({ active, payload }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload as MoodDistributionItem;
      return (
        <div className="bg-[#12122A] border border-[#1C1C3A] p-3 rounded-xl shadow-xl text-xs space-y-1">
          <p className="font-bold text-white flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: data.color }} />
            {data.name}
          </p>
          <p className="text-muted">
            Share of Month: <span className="text-accent-teal font-semibold font-display">{data.value}%</span>
          </p>
        </div>
      );
    }
    return null;
  };

  // Recharts Custom Tooltip for BarChart
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const CustomBarTooltip = ({ active, payload }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload as TimeOfDayItem;
      return (
        <div className="bg-[#12122A] border border-[#1C1C3A] p-3 rounded-xl shadow-xl text-xs space-y-1">
          <p className="font-bold text-white flex items-center gap-1.5">
            <Clock className="w-3.5 h-3.5 text-accent-teal" />
            {data.hourLabel}
          </p>
          <p className="text-muted">
            Average Mood: <span className="text-accent-teal font-semibold font-display">{data.avgScore} / 5.0</span>
          </p>
        </div>
      );
    }
    return null;
  };

  // Framer Motion staggered transition variants
  const containerVariants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
      },
    },
  };

  const itemVariants = {
    hidden: { y: 20, opacity: 0 },
    show: {
      y: 0,
      opacity: 1,
      transition: { type: "spring" as const, stiffness: 100, damping: 16 }
    },
  };

  if (!mounted || status === "loading") {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-4">
        <RefreshCw className="w-8 h-8 text-accent-teal animate-spin" />
        <p className="text-xs text-muted tracking-wider uppercase">Decoding weekly neuro-trends...</p>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-10 subtle-mesh">
      {/* Dynamic encrypted download toast */}
      <AnimatePresence>
        {toast && (
          <motion.div
            initial={{ opacity: 0, y: 50, x: "-50%" }}
            animate={{ opacity: 1, y: 0, x: "-50%" }}
            exit={{ opacity: 0, y: 20, x: "-50%" }}
            className={`fixed bottom-6 left-1/2 z-50 flex items-center gap-3 px-5 py-3 rounded-2xl bg-surface text-white shadow-xl text-xs font-semibold ${
              toast.type === "success"
                ? "border border-accent-teal/30 shadow-accent-teal/5"
                : "border border-accent-coral/30 shadow-accent-coral/5"
            }`}
          >
            {toast.type === "success" ? (
              <CheckCircle2 className="w-4 h-4 text-accent-teal animate-pulse" />
            ) : (
              <AlertCircle className="w-4 h-4 text-accent-coral animate-pulse" />
            )}
            <span>{toast.message}</span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* 1. Header with download report button */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="space-y-1">
          <h2 className="text-3xl font-bold tracking-tight text-white leading-tight">
            AI Analytics & Insights
          </h2>
          <p className="text-xs text-muted">
            Cognitive pattern recognition & monthly emotional distributions.
          </p>
        </div>
        
        <div className="flex items-center gap-3">
          <button
            onClick={fetchInsights}
            disabled={isLoading}
            className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-[#12122A] hover:bg-[#1C1C3A] border border-[#1C1C3A] text-xs text-white transition-all disabled:opacity-50"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? "animate-spin" : ""}`} />
            Refresh
          </button>

          <button
            onClick={handleDownload}
            disabled={isLoading || isDownloading}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-accent-teal hover:opacity-90 active:scale-95 text-background font-bold text-xs uppercase tracking-wider transition-all disabled:opacity-50"
          >
            {isDownloading ? (
              <>
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                Encrypting...
              </>
            ) : (
              <>
                <Download className="w-3.5 h-3.5" />
                Download Weekly Report
              </>
            )}
          </button>
        </div>
      </div>

      {error && (
        <CosmicErrorCard
          title="Cognitive Engine Connection Failed"
          message={error}
          onRetry={fetchInsights}
          isLoading={isLoading}
        />
      )}

      {isLoading ? (
        /* Shimmer Loading Skeleton */
        <div className="space-y-6">
          <div className="h-44 w-full bg-[#12122A]/40 border border-white/[0.03] animate-pulse rounded-3xl" />
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div className="h-96 bg-[#12122A]/40 border border-white/[0.03] animate-pulse rounded-3xl" />
            <div className="h-96 bg-[#12122A]/40 border border-white/[0.03] animate-pulse rounded-3xl" />
          </div>
        </div>
      ) : (
        insights && (
          <motion.div
            variants={containerVariants}
            initial="hidden"
            animate="show"
            className="space-y-6"
          >
            {/* 2. Insight & Anomaly Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              
              {/* Left 2 columns: AI Insight Card */}
              <motion.div
                variants={itemVariants}
                className="lg:col-span-2 relative overflow-hidden p-8 rounded-3xl bg-[#12122A]/70 border-l-4 border-accent-teal glass-card shadow-glow shadow-accent-teal/5 group transition-all duration-300 flex flex-col justify-between"
              >
                {/* Decorative background grid glows */}
                <div className="absolute top-0 right-0 w-64 h-64 bg-gradient-to-bl from-accent-teal/10 to-transparent blur-3xl rounded-full opacity-70 pointer-events-none" />
                
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 rounded-2xl bg-accent-teal/10 border border-accent-teal/20 flex items-center justify-center text-accent-teal shrink-0">
                    <Sparkles className="w-6 h-6 animate-pulse" />
                  </div>
                  
                  <div className="space-y-2 flex-1">
                    <div className="flex items-center gap-2">
                      <h3 className="text-lg font-bold text-white font-display">Cognitive Analysis Insight</h3>
                      <span className="px-2 py-0.5 rounded-md bg-accent-teal/10 border border-accent-teal/20 text-accent-teal text-[8px] font-bold uppercase tracking-wider">
                        Neural Model v1.4
                      </span>
                    </div>
                    <p className="text-sm text-gray-200 leading-relaxed font-sans max-w-4xl">
                      {insights.insight}
                    </p>
                  </div>
                </div>
              </motion.div>

              {/* Right 1 column: Anomaly Radar Card */}
              <motion.div
                variants={itemVariants}
                className="relative overflow-hidden p-8 rounded-3xl bg-[#12122A]/70 border border-[#1C1C3A] glass-card flex flex-col justify-between group transition-all duration-300"
              >
                {/* Inline CSS Animations for absolute zero lag responsive sweep */}
                <style dangerouslySetInnerHTML={{ __html: `
                  @keyframes radar-spin {
                    from { transform: rotate(0deg); }
                    to { transform: rotate(360deg); }
                  }
                  .radar-sweep {
                    transform-origin: 60px 60px;
                    animation: radar-spin 6s linear infinite;
                  }
                  @keyframes pulse-dot {
                    0% { r: 3px; opacity: 0.4; }
                    50% { r: 5px; opacity: 1; }
                    100% { r: 3px; opacity: 0.4; }
                  }
                  .radar-dot-pulse {
                    animation: pulse-dot 2s infinite ease-in-out;
                  }
                `}} />

                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-bold text-white font-display">Burnout Anomaly Radar</h3>
                    <span className="px-1.5 py-0.5 rounded bg-accent-coral/10 border border-accent-coral/20 text-[#FF6B6B] text-[8px] font-bold uppercase tracking-wider">
                      Biometric scan
                    </span>
                  </div>

                  {isAnomalyLoading ? (
                    <div className="flex flex-col items-center justify-center py-8 space-y-3">
                      <div className="w-20 h-20 rounded-full border-2 border-dashed border-accent-teal/30 animate-spin flex items-center justify-center">
                        <div className="w-10 h-10 rounded-full bg-[#1C1C3A] animate-pulse" />
                      </div>
                      <p className="text-[10px] text-muted uppercase tracking-widest animate-pulse">Running diagnostic check...</p>
                    </div>
                  ) : anomaly?.insufficientData ? (
                    /* Calibration State */
                    <div className="flex flex-col items-center text-center py-4 space-y-3">
                      <div className="w-24 h-24 relative flex items-center justify-center">
                        <svg className="w-full h-full transform -rotate-90">
                          <circle cx="48" cy="48" r="40" stroke="rgba(255,255,255,0.03)" strokeWidth="4" fill="transparent" />
                          <circle cx="48" cy="48" r="40" stroke="#00D2C8" strokeWidth="4" fill="transparent" strokeDasharray="251.2" strokeDashoffset="180" className="transition-all duration-1000" />
                        </svg>
                        <div className="absolute text-center">
                          <Brain className="w-5 h-5 text-accent-teal mx-auto mb-0.5 animate-pulse" />
                          <span className="text-[9px] font-bold text-accent-teal uppercase">Calibrating</span>
                        </div>
                      </div>
                      <div className="space-y-1">
                        <p className="text-xs font-bold text-white">Radar Calibrating</p>
                        <p className="text-[10px] text-muted leading-relaxed">
                          We require at least 5 mood check-ins in the last 30 days to calculate baseline deviations and identify burnout patterns.
                        </p>
                      </div>
                    </div>
                  ) : (
                    /* Active Radar Visualizer */
                    <div className="flex flex-col space-y-4">
                      {/* Interactive circular radar SVG */}
                      <div className="flex justify-center py-2 relative">
                        <svg width="120" height="120" viewBox="0 0 120 120" className="relative z-10">
                          {/* Radial Background */}
                          <circle cx="60" cy="60" r="50" fill="rgba(10, 10, 20, 0.6)" stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
                          {/* Orbits */}
                          <circle cx="60" cy="60" r="40" fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="1" strokeDasharray="3 3" />
                          <circle cx="60" cy="60" r="25" fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="1" />
                          <circle cx="60" cy="60" r="10" fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="1" />
                          
                          {/* Radar Scan sweeping line */}
                          <line x1="60" y1="60" x2="60" y2="10" stroke="url(#radarSweepGrad)" strokeWidth="2" className="radar-sweep" />

                          {/* Pulsing Core */}
                          <circle cx="60" cy="60" r="4" fill={anomaly?.riskLevel === "HIGH" ? "#FF6B6B" : anomaly?.riskLevel === "MEDIUM" ? "#F59E0B" : "#00D2C8"} className="radar-dot-pulse" />

                          {/* Glowing indicators representing detected patterns */}
                          {anomaly?.detectedPatterns?.map((pat, idx) => {
                            // Lay them out nicely on concentric circular trajectories
                            const angle = (idx * 135 + 45) * (Math.PI / 180);
                            const radius = idx % 2 === 0 ? 40 : 25;
                            const cx = 60 + radius * Math.cos(angle);
                            const cy = 60 + radius * Math.sin(angle);
                            const dotColor = anomaly.riskLevel === "HIGH" ? "#FF6B6B" : "#F59E0B";

                            return (
                              <g key={pat}>
                                <circle cx={cx} cy={cy} r="4" fill={dotColor} className="radar-dot-pulse" />
                                <circle cx={cx} cy={cy} r="8" fill="none" stroke={dotColor} strokeWidth="1" className="animate-ping opacity-60" />
                              </g>
                            );
                          })}

                          <defs>
                            <linearGradient id="radarSweepGrad" x1="0" y1="0" x2="1" y2="0">
                              <stop offset="0%" stopColor={anomaly?.riskLevel === "HIGH" ? "#FF6B6B" : anomaly?.riskLevel === "MEDIUM" ? "#F59E0B" : "#00D2C8"} stopOpacity="1" />
                              <stop offset="100%" stopColor="#12122A" stopOpacity="0" />
                            </linearGradient>
                          </defs>
                        </svg>

                        {/* Scan sweeping visual overlay */}
                        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[100px] h-[100px] rounded-full border border-white/[0.02] pointer-events-none" />
                      </div>

                      {/* Diagnostic details & Gemini phrase */}
                      <div className="space-y-3">
                        <div className="flex items-center justify-between">
                          <span className="text-[10px] text-muted font-bold uppercase tracking-wider">Burnout Risk</span>
                          <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                            anomaly?.riskLevel === "HIGH" 
                              ? "bg-accent-coral/10 text-accent-coral border border-accent-coral/20" 
                              : anomaly?.riskLevel === "MEDIUM"
                                ? "bg-amber-500/10 text-amber-400 border border-amber-500/20"
                                : "bg-accent-teal/10 text-accent-teal border border-accent-teal/20"
                          }`}>
                            {anomaly?.riskLevel === "HIGH" ? "HIGH RISK" : anomaly?.riskLevel === "MEDIUM" ? "MODERATE" : "STABLE BASELINE"}
                          </span>
                        </div>

                        <div className="p-3.5 rounded-2xl bg-[#0A0A14]/50 border border-white/[0.02] space-y-2">
                          <p className="text-[11px] text-gray-200 leading-relaxed font-sans">
                            {anomaly?.supportiveInsight}
                          </p>
                          {anomaly?.suggestedAction && (
                            <p className="text-[10px] text-accent-teal font-medium border-t border-white/[0.04] pt-2 flex items-start gap-1">
                              <span className="text-[11px] animate-pulse">🌱</span>
                              <span>{anomaly.suggestedAction}</span>
                            </p>
                          )}
                        </div>

                        {/* Crisis resource support block for High Risk profiles */}
                        {anomaly?.riskLevel === "HIGH" && (
                          <motion.div 
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            className="p-3 rounded-2xl bg-[#FF6B6B]/5 border border-[#FF6B6B]/20 space-y-2"
                          >
                            <p className="text-[10px] font-bold text-accent-coral uppercase tracking-wider flex items-center gap-1">
                              <AlertCircle className="w-3.5 h-3.5 animate-pulse" />
                              Crisis Helplines Available
                            </p>
                            <p className="text-[9px] text-gray-300 leading-relaxed">
                              Your health is precious. Connect instantly with local professional lifelines or chat with crisis support:
                            </p>
                            <div className="flex gap-2">
                              <a 
                                href="tel:988"
                                className="flex-1 text-center py-1.5 rounded-lg bg-[#FF6B6B] hover:opacity-90 active:scale-95 text-white text-[9px] font-bold transition-all"
                              >
                                Call 988 Lifeline
                              </a>
                              <button 
                                onClick={() => {
                                  setToast({ message: "Crisis Chat context configured. Navigating to Chat screen...", type: "success" });
                                  setTimeout(() => setToast(null), 4000);
                                }}
                                className="flex-1 text-center py-1.5 rounded-lg bg-surface border border-white/[0.04] hover:bg-[#1C1C3A] text-gray-200 text-[9px] font-bold transition-all"
                              >
                                Crisis Chat
                              </button>
                            </div>
                          </motion.div>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              </motion.div>

            </div>

            {/* 3. Charts Row */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              
              {/* Left Chart: Mood Distribution (Pie Chart) */}
              <motion.div
                variants={itemVariants}
                className="p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] flex flex-col justify-between"
              >
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <Activity className="w-5 h-5 text-accent-teal" />
                    <div>
                      <h3 className="text-md font-bold text-white font-display">Mood Distribution</h3>
                      <p className="text-[10px] text-muted">Percentage of each logged mood score this month</p>
                    </div>
                  </div>
                  <span className="text-[9px] font-semibold text-muted bg-[#0A0A14]/40 px-2.5 py-1 rounded-lg border border-[#1C1C3A]">
                    Last 30 Days
                  </span>
                </div>

                <div className="relative w-full min-w-0 h-[280px] min-h-[280px] flex items-center justify-center">
                  {insights.moodDistribution.length > 0 ? (
                    <>
                      <ResponsiveContainer width="100%" height="100%" minWidth={0} minHeight={0}>
                        <PieChart>
                          <RechartsTooltip content={<CustomPieTooltip />} />
                          <Pie
                            data={insights.moodDistribution}
                            cx="50%"
                            cy="50%"
                            innerRadius={70}
                            outerRadius={95}
                            paddingAngle={5}
                            dataKey="value"
                          >
                            {insights.moodDistribution.map((entry, index) => (
                              <Cell 
                                key={`cell-${index}`} 
                                fill={entry.color} 
                                stroke="#12122A"
                                strokeWidth={2}
                                className="focus:outline-none hover:opacity-90 transition-opacity"
                              />
                            ))}
                          </Pie>
                          <Legend 
                            verticalAlign="bottom" 
                            height={36}
                            iconType="circle"
                            iconSize={8}
                            formatter={(value) => <span className="text-[10px] font-medium text-muted hover:text-white transition-colors">{value}</span>}
                          />
                        </PieChart>
                      </ResponsiveContainer>
                      
                      {/* Donut Center Label */}
                      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none select-none mt-[-36px]">
                        <Brain className="w-6 h-6 text-accent-teal animate-pulse" />
                        <span className="text-[10px] font-bold text-muted uppercase tracking-widest mt-1">Clarity</span>
                        <span className="text-md font-bold text-white font-display">Index</span>
                      </div>
                    </>
                  ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center text-muted gap-2 border border-white/[0.02] rounded-2xl bg-[#0A0A14]/30">
                      <FileText className="w-8 h-8 opacity-40 text-muted" />
                      <span className="text-xs font-semibold text-gray-400">Distribution Record Empty</span>
                      <span className="text-[10px] opacity-60">Complete daily logs to map distribution levels.</span>
                    </div>
                  )}
                </div>
              </motion.div>

              {/* Right Chart: Time of Day (Bar Chart) */}
              <motion.div
                variants={itemVariants}
                className="p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] flex flex-col justify-between"
              >
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <Clock className="w-5 h-5 text-accent-coral" />
                    <div>
                      <h3 className="text-md font-bold text-white font-display">Mood Patterns by Hour</h3>
                      <p className="text-[10px] text-muted">Average stability score grouped by hour bucket</p>
                    </div>
                  </div>
                  <span className="text-[9px] font-semibold text-muted bg-[#0A0A14]/40 px-2.5 py-1 rounded-lg border border-[#1C1C3A]">
                    Circadian Telemetry
                  </span>
                </div>

                <div className="w-full min-w-0 h-[280px] min-h-[280px]">
                  {insights.timeOfDay.length > 0 ? (
                    <ResponsiveContainer width="100%" height="100%" minWidth={0} minHeight={0}>
                      <BarChart data={insights.timeOfDay} margin={{ top: 15, right: 10, left: -25, bottom: 0 }}>
                        <defs>
                          <linearGradient id="barGradient" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="0%" stopColor="#00D2C8" stopOpacity={0.9} />
                            <stop offset="100%" stopColor="#00D2C8" stopOpacity={0.2} />
                          </linearGradient>
                        </defs>
                        
                        <XAxis
                          dataKey="hourLabel"
                          stroke="rgba(255,255,255,0.2)"
                          fontSize={9}
                          tickLine={false}
                          axisLine={false}
                          dy={8}
                        />
                        <YAxis
                          domain={[1, 5]}
                          ticks={[1, 2, 3, 4, 5]}
                          stroke="rgba(255,255,255,0.2)"
                          fontSize={9}
                          tickLine={false}
                          axisLine={false}
                          dx={-8}
                        />
                        <RechartsTooltip content={<CustomBarTooltip />} />
                        <Bar
                          dataKey="avgScore"
                          fill="url(#barGradient)"
                          radius={[6, 6, 0, 0]}
                          maxBarSize={30}
                        >
                          {insights.timeOfDay.map((entry, index) => {
                            // If mood is exceptionally high, let's highlight it with a slight accent glow
                            const isHigh = entry.avgScore >= 4.0;
                            const isLow = entry.avgScore < 3.2;
                            let barColor = "url(#barGradient)";
                            if (isHigh) barColor = "url(#barGradient)";
                            else if (isLow) barColor = "rgba(255, 107, 107, 0.7)"; // low energy gets a subtle coral red tint

                            return (
                              <Cell
                                key={`bar-cell-${index}`}
                                fill={barColor}
                                className="cursor-pointer hover:opacity-90 transition-opacity"
                              />
                            );
                          })}
                        </Bar>
                      </BarChart>
                    </ResponsiveContainer>
                  ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center text-muted gap-2 border border-white/[0.02] rounded-2xl bg-[#0A0A14]/30">
                      <Clock className="w-8 h-8 opacity-40 text-muted" />
                      <span className="text-xs font-semibold text-gray-400">Circadian Telemetry Empty</span>
                      <span className="text-[10px] opacity-60">Awaiting sufficient logs to group by hour.</span>
                    </div>
                  )}
                </div>
              </motion.div>

            </div>

            {/* 4. Insights Explanation Panel */}
            <motion.div
              variants={itemVariants}
              className="p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] flex flex-col md:flex-row items-center gap-6 justify-between"
            >
              <div className="space-y-1.5 max-w-2xl">
                <p className="text-[10px] font-bold uppercase tracking-wider text-accent-teal flex items-center gap-1.5">
                  <Brain className="w-3.5 h-3.5" />
                  Understanding Your Cognitive Dashboard
                </p>
                <h4 className="text-sm font-semibold text-white">How to leverage circadian correlation insights</h4>
                <p className="text-xs text-muted leading-relaxed">
                  Your mood reports map entries chronologically to spot circadian rhythms and consistency levels. 
                  Identify clusters where scores fluctuate. Tag matches (e.g. mindfulness, work, sleep) help isolate trigger points, 
                  allowing you to fine-tune your calendar for optimal mental energy.
                </p>
              </div>

              <div className="flex items-center gap-2 text-xs text-muted border border-white/[0.03] bg-[#0A0A14]/30 p-4 rounded-2xl shrink-0">
                <Calendar className="w-4 h-4 text-accent-teal" />
                <span>Next analysis compile scheduled in <strong>3 days</strong></span>
              </div>
            </motion.div>
          </motion.div>
        )
      )}
    </div>
  );
}
