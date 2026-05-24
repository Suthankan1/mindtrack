"use client";

import React, { useState, useEffect, useCallback } from "react";
import { useSession } from "next-auth/react";
import { motion } from "framer-motion";
import axios from "axios";
import { 
  AreaChart, 
  Area, 
  XAxis, 
  YAxis, 
  Tooltip as RechartsTooltip, 
  ResponsiveContainer 
} from "recharts";
import { 
  Flame, 
  TrendingUp, 
  BookOpen, 
  Sparkles, 
  PlusCircle, 
  Activity, 
  CalendarDays,
  RefreshCw,
  AlertCircle,
  Tag
} from "lucide-react";

// Types corresponding to backend DTO response
interface MoodEntryResponse {
  id: string;
  userId: string;
  moodScore: number;
  note: string;
  timestamp: string;
  tags: string[];
}

interface UserStatsResponse {
  totalEntries: number;
  currentStreak: number;
  longestStreak: number;
  avgMoodScore: number;
  avgMoodScoreThisWeek: number;
  joinedDaysAgo: number;
}

export default function DashboardPage() {
  const { data: session, status } = useSession();
  
  // React client-side hydration lock
  const [mounted, setMounted] = useState(false);
  
  // Data State
  const [entries, setEntries] = useState<MoodEntryResponse[]>([]);
  const [stats, setStats] = useState<UserStatsResponse>({
    totalEntries: 0,
    currentStreak: 0,
    longestStreak: 0,
    avgMoodScore: 0,
    avgMoodScoreThisWeek: 0,
    joinedDaysAgo: 0,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Action State
  const [newMood, setNewMood] = useState<number>(4);
  const [newNote, setNewNote] = useState("");
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [logSuccess, setLogSuccess] = useState(false);

  // Available tag selections
  const availableTags = ["Sleep", "Work", "Exercise", "Mindfulness", "Social", "Nutrition"];

  useEffect(() => {
    setMounted(true);
  }, []);

  const fetchUserStats = useCallback(async () => {
    if (!session?.user?.accessToken) return;
    const res = await axios.get("/api/user/stats", {
      headers: {
        Authorization: `Bearer ${session.user.accessToken}`,
      },
    });
    setStats(res.data);
    return res.data;
  }, [session]);

  const fetchHistory = useCallback(async () => {
    if (!session?.user?.accessToken) return;
    setIsLoading(true);
    try {
      const headers = {
        Authorization: `Bearer ${session.user.accessToken}`,
      };
      
      const [historyRes, statsData] = await Promise.all([
        axios.get("/api/mood/history?days=30", { headers }).then(res => res.data),
        fetchUserStats()
      ]);
      
      setEntries(historyRes);
      setError(null);
    } catch (err: unknown) {
      console.error("Error loading mood history:", err);
      const errorMsg = axios.isAxiosError(err) 
        ? err.response?.data?.error || err.message
        : "Failed to establish a secure database hand-shake. Please ensure the backend is running.";
      setError(errorMsg);
    } finally {
      setIsLoading(false);
    }
  }, [session, fetchUserStats]);

  // Re-fetch when authenticated
  useEffect(() => {
    if (status === "authenticated") {
      fetchHistory();
    } else if (status === "unauthenticated") {
      setIsLoading(false);
    }
  }, [status, fetchHistory]);

  const handleAddMood = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newMood < 1 || newMood > 5 || !session?.user?.accessToken) return;
    
    setIsSubmitting(true);
    setLogSuccess(false);

    try {
      await axios.post(
        "/api/mood/log",
        {
          moodScore: newMood,
          note: newNote || "Logged moment of reflection.",
          tags: selectedTags,
        },
        {
          headers: {
            Authorization: `Bearer ${session.user.accessToken}`,
          },
        }
      );

      setNewNote("");
      setSelectedTags([]);
      setLogSuccess(true);
      setTimeout(() => setLogSuccess(false), 3000);
      
      // Instantly refresh all analytical charts & values
      await fetchHistory();
    } catch (err: unknown) {
      console.error("Error saving daily log:", err);
      setError("Failed to save entry. Please verify connection to server.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleTag = (tag: string) => {
    if (selectedTags.includes(tag)) {
      setSelectedTags(selectedTags.filter(t => t !== tag));
    } else {
      setSelectedTags([...selectedTags, tag]);
    }
  };



  // Format Recharts Chronological Data
  const chartData = [...entries]
    .reverse()
    .map((entry) => {
      const date = new Date(entry.timestamp);
      return {
        name: date.toLocaleDateString("en-US", { month: "short", day: "numeric" }),
        score: entry.moodScore,
        note: entry.note,
        tags: entry.tags,
        fullDate: date.toLocaleDateString("en-US", { 
          weekday: "short", 
          month: "short", 
          day: "numeric", 
          hour: "2-digit", 
          minute: "2-digit" 
        }),
      };
    });

  // Heatmap generation
  const generateHeatmapGrid = () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const grid: { date: Date; dateStr: string; score: number | null; dateLabel: string }[] = [];
    const moodMap: Record<string, { total: number; count: number }> = {};
    
    entries.forEach(e => {
      const d = new Date(e.timestamp);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      if (!moodMap[key]) {
        moodMap[key] = { total: e.moodScore, count: 1 };
      } else {
        moodMap[key].total += e.moodScore;
        moodMap[key].count += 1;
      }
    });

    // 7 rows x 5 columns = 35 days total.
    // GitHub contribution layouts use column-major order:
    // col 0..4, row 0..6
    // Cell index = col * 7 + row.
    // Cell at index 34 represents today.
    for (let col = 0; col < 5; col++) {
      for (let row = 0; row < 7; row++) {
        const cellIndex = col * 7 + row;
        const cellDate = new Date(today);
        cellDate.setDate(today.getDate() - (34 - cellIndex));
        
        const key = `${cellDate.getFullYear()}-${String(cellDate.getMonth() + 1).padStart(2, '0')}-${String(cellDate.getDate()).padStart(2, '0')}`;
        
        let score: number | null = null;
        if (moodMap[key]) {
          score = Math.round(moodMap[key].total / moodMap[key].count);
        }
        
        const formattedLabel = cellDate.toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
          year: "numeric"
        });

        grid.push({
          date: cellDate,
          dateStr: key,
          score,
          dateLabel: formattedLabel,
        });
      }
    }
    return grid;
  };

  const heatmapCells = generateHeatmapGrid();

  const getHeatmapColor = (score: number | null) => {
    if (score === null) return "bg-[#181832] border border-white/[0.03]";
    switch (score) {
      case 1: return "bg-[#581C1C] border border-[#7F1D1D]/30 shadow-[inset_0_0_8px_rgba(127,29,29,0.4)]"; // dark red
      case 2: return "bg-[#B91C1C] border border-[#EF4444]/30"; // medium red
      case 3: return "bg-[#4B5563] border border-[#6B7280]/30"; // slate/neutral
      case 4: return "bg-[#00A39C] border border-[#00C2B8]/30"; // light teal
      case 5: return "bg-[#00D2C8] border border-[#00D2C8]/50 shadow-[0_0_8px_rgba(0,210,200,0.3)]"; // bright teal
      default: return "bg-[#181832] border border-white/[0.03]";
    }
  };

  const getMoodEmoji = (val: number) => {
    switch (val) {
      case 5: return "🌟"; // Excellent
      case 4: return "✨"; // Good
      case 3: return "😐"; // Neutral
      case 2: return "😞"; // Down
      case 1: return "🔥"; // Severe
      default: return "😐";
    }
  };

  const getMoodLabel = (val: number) => {
    switch (val) {
      case 5: return "Radiant";
      case 4: return "Stable";
      case 3: return "Neutral";
      case 2: return "Low Energy";
      case 1: return "High Stress";
      default: return "Neutral";
    }
  };

  // Recharts Custom Node Dot
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const CustomDot = (props: any) => {
    const { cx, cy, payload } = props;
    if (!cx || !cy) return null;
    const score = payload.score;
    const dotColor = score >= 4 ? "#00D2C8" : score <= 2 ? "#FF6B6B" : "#F3F4F6";
    return (
      <g>
        <circle cx={cx} cy={cy} r={6} fill="#0A0A14" stroke={dotColor} strokeWidth={2} />
        <circle cx={cx} cy={cy} r={2} fill={dotColor} />
      </g>
    );
  };

  // Framer Motion Animation Settings
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

  // Fallback visual skeletons
  if (status === "loading" || !mounted) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-4">
        <RefreshCw className="w-8 h-8 text-accent-teal animate-spin" />
        <p className="text-xs text-muted tracking-wider uppercase">Aligning mental health records...</p>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-10 subtle-mesh">
      
      {/* 1. Header welcome */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="space-y-1">
          <h2 className="text-3xl font-bold tracking-tight text-white leading-tight">
            Dashboard
          </h2>
          <p className="text-xs text-muted">
            Secure, decrypted insight overview for <span className="text-accent-teal">{session?.user?.name || "Premium User"}</span>.
          </p>
        </div>
        <button
          onClick={fetchHistory}
          disabled={isLoading}
          className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-[#12122A] hover:bg-[#1C1C3A] border border-[#1C1C3A] text-xs text-white transition-all disabled:opacity-50"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? "animate-spin" : ""}`} />
          Force Sync
        </button>
      </div>

      {error && (
        <div className="p-4 rounded-2xl bg-red-950/20 border border-red-500/30 text-red-200 text-xs flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-[#FF6B6B] shrink-0" />
          <div className="flex-1">
            <span className="font-semibold">Diagnostic Connection Issue: </span>
            {error}
          </div>
          <button 
            onClick={fetchHistory}
            className="px-3 py-1 bg-[#FF6B6B]/20 text-white rounded-lg hover:bg-[#FF6B6B]/30 transition-all font-semibold"
          >
            Retry
          </button>
        </div>
      )}

      {/* STAGGERED ENTRANCE LAYOUT */}
      <motion.div 
        variants={containerVariants}
        initial="hidden"
        animate="show"
        className="space-y-8"
      >

        {/* 2. StatsRow (Staggered Animation Component 1) */}
        <motion.div variants={itemVariants} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          
          {/* Metric: Streak */}
          <div className="relative overflow-hidden p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] group hover:border-[#FF6B6B]/30 transition-all duration-300">
            <div className="absolute top-0 right-0 w-24 h-24 bg-gradient-to-bl from-amber-400/5 to-transparent blur-2xl rounded-full opacity-60 pointer-events-none" />
            <div className="flex items-center justify-between">
              <span className="text-[10px] uppercase font-bold tracking-wider text-muted">Current Streak</span>
              <Flame className="w-5 h-5 text-amber-400 animate-pulse" />
            </div>
            <div className="mt-4 flex items-baseline gap-2">
              <span className="text-4xl font-bold text-amber-400 tracking-tight font-display">
                {stats.currentStreak}
              </span>
              <span className="text-xs text-muted">{stats.currentStreak === 1 ? "day" : "days"}</span>
            </div>
            <p className="text-[10px] text-muted mt-2">Consecutive daily journals logged.</p>
          </div>

          {/* Metric: Weekly Average */}
          <div className="relative overflow-hidden p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] group hover:border-accent-teal/30 transition-all duration-300">
            <div className="absolute top-0 right-0 w-24 h-24 bg-gradient-to-bl from-accent-teal/5 to-transparent blur-2xl rounded-full opacity-60 pointer-events-none" />
            <div className="flex items-center justify-between">
              <span className="text-[10px] uppercase font-bold tracking-wider text-muted">Weekly Average</span>
              <TrendingUp className="w-5 h-5 text-accent-teal" />
            </div>
            <div className="mt-4 flex items-baseline gap-2">
              <span className="text-4xl font-bold text-accent-teal tracking-tight font-display">
                {stats.avgMoodScoreThisWeek}
              </span>
              <span className="text-xs text-muted">/ 5.0</span>
            </div>
            <p className="text-[10px] text-muted mt-2">Overall balance over past week.</p>
          </div>

          {/* Metric: Total Entries */}
          <div className="relative overflow-hidden p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] group hover:border-violet-400/30 transition-all duration-300">
            <div className="absolute top-0 right-0 w-24 h-24 bg-gradient-to-bl from-violet-400/5 to-transparent blur-2xl rounded-full opacity-60 pointer-events-none" />
            <div className="flex items-center justify-between">
              <span className="text-[10px] uppercase font-bold tracking-wider text-muted">Total Entries</span>
              <BookOpen className="w-5 h-5 text-violet-400" />
            </div>
            <div className="mt-4 flex items-baseline gap-2">
              <span className="text-4xl font-bold text-violet-400 tracking-tight font-display">
                {stats.totalEntries}
              </span>
              <span className="text-xs text-muted">logs</span>
            </div>
            <p className="text-[10px] text-muted mt-2">All recorded entries in dashboard range.</p>
          </div>

          {/* Metric: Days Active */}
          <div className="relative overflow-hidden p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] group hover:border-emerald-400/30 transition-all duration-300">
            <div className="absolute top-0 right-0 w-24 h-24 bg-gradient-to-bl from-emerald-400/5 to-transparent blur-2xl rounded-full opacity-60 pointer-events-none" />
            <div className="flex items-center justify-between">
              <span className="text-[10px] uppercase font-bold tracking-wider text-muted">Days Active</span>
              <CalendarDays className="w-5 h-5 text-emerald-400" />
            </div>
            <div className="mt-4 flex items-baseline gap-2">
              <span className="text-4xl font-bold text-emerald-400 tracking-tight font-display">
                {stats.joinedDaysAgo}
              </span>
              <span className="text-xs text-muted">{stats.joinedDaysAgo === 1 ? "day" : "days"}</span>
            </div>
            <p className="text-[10px] text-muted mt-2">Days since joining MindTrack.</p>
          </div>

        </motion.div>


        {/* 3. Main Dashboard Charts & Logger (Staggered Animations) */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          
          {/* Column 1: Interactive Mood Logger Form (Staggered Animation Component 2) */}
          <motion.div variants={itemVariants} className="space-y-6 lg:col-span-1">
            <div className="p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] flex flex-col justify-between h-full">
              <div className="space-y-4">
                <div className="flex items-center gap-3">
                  <PlusCircle className="w-5 h-5 text-accent-teal" />
                  <h3 className="text-md font-bold text-white font-display">Record Current Vibe</h3>
                </div>
                <p className="text-xs text-muted">
                  Log your present clarity quotient, select tags and write an organic reflection note.
                </p>

                {logSuccess && (
                  <div className="p-3 rounded-xl bg-accent-teal/10 border border-accent-teal/20 text-accent-teal text-[11px] text-center font-medium animate-pulse">
                    🌱 Mind snapshot secured in cloud repository!
                  </div>
                )}

                <form onSubmit={handleAddMood} className="space-y-5 pt-1">
                  
                  {/* Score selector 1 to 5 */}
                  <div className="space-y-2">
                    <label className="text-xs text-gray-300 font-semibold">Mood Score</label>
                    <div className="grid grid-cols-5 gap-2">
                      {[1, 2, 3, 4, 5].map((val) => (
                        <button
                          key={val}
                          type="button"
                          disabled={isSubmitting}
                          onClick={() => setNewMood(val)}
                          className={`py-3 rounded-xl border flex flex-col items-center gap-1 transition-all duration-300 ${
                            newMood === val
                              ? "bg-accent-teal/10 border-accent-teal text-accent-teal scale-105"
                              : "bg-[#0A0A14]/60 border-white/[0.04] text-muted hover:border-white/10 hover:text-white"
                          }`}
                        >
                          <span className="text-base">{getMoodEmoji(val)}</span>
                          <span className="text-[9px] font-bold">{val}</span>
                        </button>
                      ))}
                    </div>
                    <div className="text-center mt-1.5">
                      <span className="text-[10px] font-bold text-accent-teal uppercase tracking-widest">
                        {getMoodLabel(newMood)}
                      </span>
                    </div>
                  </div>

                  {/* Optional Tags */}
                  <div className="space-y-2">
                    <label className="text-xs text-gray-300 font-semibold flex items-center gap-1.5">
                      <Tag className="w-3.5 h-3.5 text-muted" />
                      Associated Tags
                    </label>
                    <div className="flex flex-wrap gap-1.5">
                      {availableTags.map((tag) => {
                        const isSelected = selectedTags.includes(tag);
                        return (
                          <button
                            key={tag}
                            type="button"
                            onClick={() => handleToggleTag(tag)}
                            className={`px-2.5 py-1 rounded-lg text-[9px] font-medium border transition-all ${
                              isSelected
                                ? "bg-accent-teal/10 border-accent-teal text-accent-teal"
                                : "bg-[#0A0A14]/30 border-white/[0.03] text-muted hover:border-white/10 hover:text-white"
                            }`}
                          >
                            {tag}
                          </button>
                        );
                      })}
                    </div>
                  </div>

                  {/* Journal Reflection Input */}
                  <div className="space-y-2">
                    <label className="text-xs text-gray-300 font-semibold">Reflection Note</label>
                    <textarea
                      value={newNote}
                      onChange={(e) => setNewNote(e.target.value)}
                      placeholder="Sleep quality, mindfulness check-in, recent triggers..."
                      rows={3}
                      disabled={isSubmitting}
                      className="w-full p-3 bg-[#0A0A14]/70 border border-[#1C1C3A] focus:border-accent-teal/50 rounded-xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 resize-none transition-all"
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className="w-full py-3 rounded-xl bg-accent-teal text-background font-bold text-xs uppercase tracking-wider hover:opacity-90 active:scale-[0.98] transition-all disabled:opacity-50"
                  >
                    {isSubmitting ? "Encrypting entry..." : "Commit Log"}
                  </button>

                </form>
              </div>
            </div>
          </motion.div>

          {/* Column 2: WaveChart & Heatmap Section (Staggered Animation Component 3) */}
          <motion.div variants={itemVariants} className="lg:col-span-2 space-y-6 flex flex-col">
            
            {/* WaveChart container */}
            <div className="p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] flex-1 flex flex-col justify-between min-h-[300px]">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <Activity className="w-5 h-5 text-accent-coral" />
                  <h3 className="text-md font-bold text-white font-display">Mood Wave Timeline</h3>
                </div>
                <div className="text-[10px] text-muted flex items-center gap-1.5 bg-[#0A0A14]/40 px-3 py-1.5 rounded-lg border border-[#1C1C3A]">
                  <Sparkles className="w-3 h-3 text-accent-teal" />
                  Last 30 entries
                </div>
              </div>

              <div className="flex-1 w-full h-[220px]">
                {chartData.length > 0 ? (
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                      <defs>
                        {/* Area Fill color gradient: low (#FF6B6B) to high (#00D2C8) */}
                        <linearGradient id="waveFill" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#00D2C8" stopOpacity={0.3} />
                          <stop offset="100%" stopColor="#FF6B6B" stopOpacity={0.01} />
                        </linearGradient>
                        {/* Stroke line color gradient: low (#FF6B6B) to high (#00D2C8) */}
                        <linearGradient id="waveStroke" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#00D2C8" />
                          <stop offset="100%" stopColor="#FF6B6B" />
                        </linearGradient>
                      </defs>
                      
                      {/* No grid lines */}
                      
                      <XAxis 
                        dataKey="name" 
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
                      <RechartsTooltip 
                        contentStyle={{ 
                          background: "#12122A", 
                          border: "1px solid #1C1C3A", 
                          borderRadius: "12px",
                          color: "#F3F4F6",
                          fontSize: "10px"
                        }}
                        labelFormatter={(label, items) => {
                          if (items[0]?.payload) {
                            return items[0].payload.fullDate;
                          }
                          return label;
                        }}
                        formatter={(value, name, props) => {
                          const score = value as number;
                          const note = props.payload.note;
                          const tags = props.payload.tags;
                          return [
                            <div key="tooltip" className="space-y-1">
                              <p className="font-bold text-accent-teal">{`Score: ${score}/5 (${getMoodLabel(score)})`}</p>
                              {note && <p className="text-[9px] text-gray-300 max-w-[200px] whitespace-normal italic">&quot;{note}&quot;</p>}
                              {tags && tags.length > 0 && (
                                <p className="text-[8px] text-accent-teal/80 mt-1">Tags: {tags.join(", ")}</p>
                              )}
                            </div>,
                            undefined
                          ];
                        }}
                      />
                      <Area 
                        type="monotone" 
                        dataKey="score" 
                        stroke="url(#waveStroke)" 
                        strokeWidth={2}
                        fillOpacity={1} 
                        fill="url(#waveFill)" 
                        dot={<CustomDot />}
                        activeDot={{ r: 7, stroke: "#0A0A14", strokeWidth: 2 }}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                ) : (
                  <div className="w-full h-full flex flex-col items-center justify-center text-muted gap-2 border border-white/[0.02] rounded-2xl bg-[#0A0A14]/30">
                    <BookOpen className="w-8 h-8 opacity-40 text-muted" />
                    <span className="text-[11px] font-semibold tracking-wide text-gray-400">Biological Wave Empty</span>
                    <span className="text-[9px] opacity-60">Log your first state in the sidebar form to populate.</span>
                  </div>
                )}
              </div>
            </div>

            {/* 4. MoodHeatmap (Staggered Animation Component 4) */}
            <div className="p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A] flex flex-col justify-between">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <CalendarDays className="w-5 h-5 text-accent-teal" />
                  <h3 className="text-md font-bold text-white font-display">Clarity Matrix</h3>
                </div>
                <div className="flex items-center gap-1.5 text-[8px] text-muted">
                  <span>Less</span>
                  <div className="w-2 h-2 rounded-sm bg-[#581C1C]" />
                  <div className="w-2 h-2 rounded-sm bg-[#B91C1C]" />
                  <div className="w-2 h-2 rounded-sm bg-[#4B5563]" />
                  <div className="w-2 h-2 rounded-sm bg-[#00A39C]" />
                  <div className="w-2 h-2 rounded-sm bg-[#00D2C8]" />
                  <span>More</span>
                </div>
              </div>

              <div className="flex flex-col md:flex-row items-center gap-6 justify-center py-2">
                {/* 7 rows x 5 columns calendar grid */}
                <div className="flex gap-2">
                  
                  {/* Left Label column */}
                  <div className="grid grid-rows-7 text-[8px] text-muted font-bold h-36 items-center pr-1 select-none">
                    <span>Mon</span>
                    <span className="opacity-0">Tue</span>
                    <span>Wed</span>
                    <span className="opacity-0">Thu</span>
                    <span>Fri</span>
                    <span className="opacity-0">Sat</span>
                    <span>Sun</span>
                  </div>

                  {/* Grid element */}
                  <div className="grid grid-flow-col grid-rows-7 gap-2">
                    {heatmapCells.map((cell) => (
                      <div 
                        key={cell.dateStr}
                        className="relative group cursor-pointer"
                      >
                        <div 
                          className={`w-[18px] h-[18px] rounded-sm transition-all duration-300 hover:scale-110 ${getHeatmapColor(cell.score)}`} 
                        />
                        
                        {/* Hover Tooltip - Pure HTML/CSS for instant zero lag responsive execution */}
                        <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 hidden group-hover:flex flex-col z-50 bg-[#12122A] border border-[#1C1C3A] text-white text-[9px] py-1.5 px-2.5 rounded-xl whitespace-nowrap shadow-xl">
                          <p className="font-bold text-white">{cell.dateLabel}</p>
                          <p className="text-accent-teal mt-0.5 font-semibold">
                            {cell.score ? `Score: ${cell.score}/5 (${getMoodLabel(cell.score)})` : "No Record Logged"}
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>

                </div>

                {/* Additional Heatmap context card */}
                <div className="flex-1 border border-white/[0.03] rounded-2xl p-4 bg-[#0A0A14]/30 space-y-2 max-w-[240px]">
                  <p className="text-[10px] font-bold uppercase tracking-wider text-accent-teal">Matrix Log Range</p>
                  <p className="text-xs text-white font-medium">35-Day Emotional Grid</p>
                  <p className="text-[10px] text-muted leading-relaxed">
                    Visualizes consistency clusters. Deep teal represent peaks in mental clarity, while dark reds denote stress events.
                  </p>
                </div>

              </div>
            </div>

          </motion.div>

        </div>

        {/* 5. Recent Journal logs list (Staggered Animation Component 5) */}
        <motion.div variants={itemVariants} className="p-6 rounded-3xl bg-[#12122A] border border-[#1C1C3A]">
          <div className="flex items-center gap-3 mb-6">
            <CalendarDays className="w-5 h-5 text-accent-teal" />
            <h3 className="text-md font-bold text-white font-display">Recent Mind Logs</h3>
          </div>

          {entries.length > 0 ? (
            <div className="space-y-4 max-h-[300px] overflow-y-auto pr-1">
              {entries.map((entry) => (
                <div 
                  key={entry.id}
                  className="p-4 rounded-2xl bg-[#0A0A14]/40 hover:bg-[#0A0A14]/60 border border-white/[0.03] hover:border-white/[0.08] flex flex-col md:flex-row md:items-center justify-between gap-4 transition-all duration-300"
                >
                  <div className="flex items-start gap-4">
                    <div className="w-11 h-11 rounded-xl bg-[#1C1C3A] border border-white/[0.04] flex flex-col items-center justify-center shrink-0">
                      <span className="text-lg">{getMoodEmoji(entry.moodScore)}</span>
                    </div>
                    
                    <div className="space-y-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="text-[10px] font-bold text-white uppercase tracking-wider">
                          {getMoodLabel(entry.moodScore)}
                        </span>
                        <span className="w-1 h-1 rounded-full bg-white/20" />
                        <span className="text-[9px] text-muted">
                          {new Date(entry.timestamp).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}
                        </span>
                        {entry.tags && entry.tags.map((tag) => (
                          <span 
                            key={tag}
                            className="px-1.5 py-0.5 rounded bg-accent-teal/5 border border-accent-teal/10 text-accent-teal text-[8px] font-semibold uppercase"
                          >
                            {tag}
                          </span>
                        ))}
                      </div>
                      <p className="text-xs text-gray-300 leading-relaxed max-w-2xl">{entry.note}</p>
                    </div>
                  </div>

                  <div className="text-right shrink-0 md:pl-4">
                    <span className="text-[10px] font-bold text-muted bg-[#1C1C3A] border border-white/[0.04] px-3 py-1.5 rounded-xl">
                      {new Date(entry.timestamp).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-10 text-muted text-xs border border-white/[0.02] bg-[#0A0A14]/20 rounded-2xl">
              No entries found in recent biological range. Log a daily snapshot above.
            </div>
          )}
        </motion.div>

      </motion.div>

    </div>
  );
}
