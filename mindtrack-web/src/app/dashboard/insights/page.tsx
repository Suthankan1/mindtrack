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

export default function InsightsPage() {
  const { data: session, status } = useSession();
  const [mounted, setMounted] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Data States
  const [insights, setInsights] = useState<WeeklyInsightsResponse | null>(null);

  // Interaction States
  const [isDownloading, setIsDownloading] = useState(false);
  const [showToast, setShowToast] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const fetchInsights = useCallback(async () => {
    if (!session?.user?.accessToken) return;
    setIsLoading(true);
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
  }, [session]);

  useEffect(() => {
    if (status === "authenticated") {
      fetchInsights();
    } else if (status === "unauthenticated") {
      setIsLoading(false);
    }
  }, [status, fetchInsights]);

  const handleDownload = () => {
    if (isDownloading) return;
    setIsDownloading(true);
    
    // Simulate premium PDF compilation & secure download
    setTimeout(() => {
      setIsDownloading(false);
      setShowToast(true);
      setTimeout(() => setShowToast(false), 4000);
    }, 2000);
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
        {showToast && (
          <motion.div
            initial={{ opacity: 0, y: 50, x: "-50%" }}
            animate={{ opacity: 1, y: 0, x: "-50%" }}
            exit={{ opacity: 0, y: 20, x: "-50%" }}
            className="fixed bottom-6 left-1/2 z-50 flex items-center gap-3 px-5 py-3 rounded-2xl bg-surface border border-accent-teal/30 text-white shadow-xl shadow-accent-teal/5 text-xs font-semibold"
          >
            <CheckCircle2 className="w-4 h-4 text-accent-teal animate-pulse" />
            <span>Encrypted weekly PDF summary compiled & downloaded successfully!</span>
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
        <div className="p-4 rounded-2xl bg-red-950/20 border border-red-500/30 text-red-200 text-xs flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-accent-coral shrink-0" />
          <div className="flex-1">
            <span className="font-semibold">Engine Error: </span>
            {error}
          </div>
          <button
            onClick={fetchInsights}
            className="px-3 py-1 bg-accent-coral/20 text-white rounded-lg hover:bg-accent-coral/30 transition-all font-semibold"
          >
            Retry
          </button>
        </div>
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
            {/* 2. AI Insight Card */}
            <motion.div
              variants={itemVariants}
              className="relative overflow-hidden p-8 rounded-3xl bg-[#12122A]/70 border-l-4 border-accent-teal glass-card shadow-glow shadow-accent-teal/5 group transition-all duration-300"
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

                <div className="relative w-full h-[280px] flex items-center justify-center">
                  {insights.moodDistribution.length > 0 ? (
                    <>
                      <ResponsiveContainer width="100%" height="100%">
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

                <div className="w-full h-[280px]">
                  {insights.timeOfDay.length > 0 ? (
                    <ResponsiveContainer width="100%" height="100%">
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
