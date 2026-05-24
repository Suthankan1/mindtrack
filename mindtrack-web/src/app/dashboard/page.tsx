"use client";

import React, { useState, useEffect } from "react";
import { useSession } from "next-auth/react";
import { motion } from "framer-motion";
import { 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  Area,
  AreaChart
} from "recharts";
import { 
  Smile, 
  TrendingUp, 
  CalendarDays, 
  Heart, 
  BookOpen,
  Sparkles,
  PlusCircle,
  Activity
} from "lucide-react";
import { useMoodStore } from "@/store/useStore";

export default function DashboardPage() {
  const { data: session } = useSession();
  const { entries, addEntry } = useMoodStore();
  
  // Local states
  const [mounted, setMounted] = useState(false);
  const [newMood, setNewMood] = useState<number>(4);
  const [newNote, setNewNote] = useState("");
  const [logSuccess, setLogSuccess] = useState(false);

  // Prevent SSR hydration issues with Recharts
  useEffect(() => {
    setMounted(true);
  }, []);

  const handleAddMood = (e: React.FormEvent) => {
    e.preventDefault();
    if (newMood < 1 || newMood > 5) return;
    
    addEntry(newMood, newNote || "No notes written.");
    setNewNote("");
    setLogSuccess(true);
    setTimeout(() => setLogSuccess(false), 3000);
  };

  // Compute metrics
  const totalLogs = entries.length;
  const avgMood = totalLogs > 0 
    ? (entries.reduce((acc, curr) => acc + curr.moodValue, 0) / totalLogs).toFixed(1) 
    : "0.0";
  
  // Format chart data (reverse to chronological order)
  const chartData = [...entries]
    .reverse()
    .map((entry) => {
      const date = new Date(entry.createdAt);
      return {
        name: date.toLocaleDateString("en-US", { month: "short", day: "numeric" }),
        score: entry.moodValue,
        note: entry.note.substring(0, 15) + "...",
      };
    });

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

  return (
    <div className="space-y-8 pb-10">
      
      {/* 1. Welcome Back Hero Card */}
      <motion.div 
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.6 }}
        className="glass-elevated glow-card-teal rounded-3xl p-6 lg:p-10 relative overflow-hidden"
      >
        <div className="absolute right-0 top-0 w-64 h-64 bg-accent-teal/5 rounded-full blur-3xl pointer-events-none" />
        
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-accent-teal/10 border border-accent-teal/20 text-accent-teal text-xs font-semibold">
              <Sparkles className="w-3.5 h-3.5" />
              MindTrack Premium Active
            </div>
            
            <h2 className="text-3xl lg:text-4xl font-bold font-display text-white tracking-tight leading-tight">
              Welcome back, <span className="text-accent-teal">{session?.user?.name || "Explorer"}</span>
            </h2>
            <p className="text-sm text-muted max-w-xl leading-relaxed">
              Your mental clarity is your greatest strength. Logging your feelings regularly helps reveal deep emotional cycles. How are you feeling today?
            </p>
          </div>
          
          <div className="flex gap-4">
            <div className="px-5 py-4 rounded-2xl bg-background/50 border border-white/5 flex flex-col items-center justify-center min-w-[100px] shadow-sm">
              <span className="text-2xl">⚡</span>
              <span className="text-[10px] text-muted uppercase font-bold tracking-wider mt-1.5">Streak</span>
              <span className="text-lg font-bold text-white mt-0.5">7 Days</span>
            </div>
            <div className="px-5 py-4 rounded-2xl bg-background/50 border border-white/5 flex flex-col items-center justify-center min-w-[100px] shadow-sm">
              <span className="text-2xl">🌱</span>
              <span className="text-[10px] text-muted uppercase font-bold tracking-wider mt-1.5">Clarity</span>
              <span className="text-lg font-bold text-accent-teal mt-0.5">Level 4</span>
            </div>
          </div>
        </div>
      </motion.div>

      {/* 2. Analytical Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {[
          { title: "Average Mood", value: avgMood, desc: "Scale of 1.0 - 5.0", icon: Smile, color: "text-accent-teal", bg: "from-accent-teal/10 to-transparent" },
          { title: "Total Logs", value: totalLogs, desc: "All-time logged moments", icon: BookOpen, color: "text-accent-coral", bg: "from-accent-coral/10 to-transparent" },
          { title: "Active Streak", value: "7 Days", desc: "Consecutive logging days", icon: CalendarDays, color: "text-amber-400", bg: "from-amber-400/10 to-transparent" },
          { title: "Peace Score", value: "84%", desc: "Mental balance quotient", icon: Heart, color: "text-emerald-400", bg: "from-emerald-400/10 to-transparent" },
        ].map((metric, idx) => (
          <motion.div
            key={metric.title}
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: idx * 0.1 }}
            className="glass-card rounded-2xl p-5 border border-white/5 relative overflow-hidden group hover:border-white/10 transition-all duration-300"
          >
            <div className={`absolute top-0 right-0 w-24 h-24 bg-gradient-to-bl ${metric.bg} blur-2xl rounded-full opacity-60 group-hover:scale-110 transition-transform duration-300 pointer-events-none`} />
            
            <div className="flex items-center justify-between relative z-10">
              <span className="text-xs font-semibold text-muted tracking-wider uppercase">{metric.title}</span>
              <metric.icon className={`w-5 h-5 ${metric.color}`} />
            </div>
            
            <div className="mt-4 relative z-10">
              <span className="text-3xl font-bold text-white tracking-tight font-display">{metric.value}</span>
              <p className="text-[10px] text-muted mt-1.5">{metric.desc}</p>
            </div>
          </motion.div>
        ))}
      </div>

      {/* 3. Interactive Mood Logger + Visual Chart Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Mood Logger Form */}
        <motion.div 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="glass-card rounded-3xl p-6 border border-white/5 flex flex-col justify-between"
        >
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <PlusCircle className="w-5 h-5 text-accent-teal" />
              <h3 className="text-lg font-bold text-white font-display">Log Today&apos;s Energy</h3>
            </div>
            <p className="text-xs text-muted">
              Select your mood score, write a brief reflection note, and save. Updates your analytics instantly.
            </p>
            
            {logSuccess && (
              <div className="p-3 rounded-xl bg-accent-teal/10 border border-accent-teal/20 text-accent-teal text-xs text-center font-medium animate-pulse">
                🌱 Mood entry saved successfully!
              </div>
            )}

            <form onSubmit={handleAddMood} className="space-y-4 pt-2">
              {/* Mood Scale 1-5 Selector */}
              <div className="space-y-2">
                <span className="text-xs font-semibold text-gray-300">Emotional Balance</span>
                <div className="grid grid-cols-5 gap-2">
                  {[1, 2, 3, 4, 5].map((val) => (
                    <button
                      key={val}
                      type="button"
                      onClick={() => setNewMood(val)}
                      className={`py-3.5 rounded-xl border flex flex-col items-center gap-1.5 transition-all duration-300 ${
                        newMood === val
                          ? "bg-accent-teal/10 border-accent-teal text-accent-teal shadow-glow scale-105"
                          : "bg-background/40 border-white/5 text-muted hover:border-white/10 hover:text-white"
                      }`}
                    >
                      <span className="text-lg">{getMoodEmoji(val)}</span>
                      <span className="text-[9px] font-bold uppercase tracking-wide">{val}</span>
                    </button>
                  ))}
                </div>
                <div className="text-center mt-1">
                  <span className="text-[11px] font-semibold text-accent-teal uppercase tracking-wide">
                    {getMoodLabel(newMood)}
                  </span>
                </div>
              </div>

              {/* Reflection Note */}
              <div className="space-y-2">
                <label className="text-xs font-semibold text-gray-300">Journal Reflection</label>
                <textarea
                  value={newNote}
                  onChange={(e) => setNewNote(e.target.value)}
                  placeholder="How was your sleep? Did you practice mindfulness? Note any triggers..."
                  rows={3}
                  className="w-full p-3 bg-background/50 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 resize-none transition-all"
                />
              </div>

              <button
                type="submit"
                className="w-full py-3 rounded-xl bg-accent-teal text-background font-bold text-xs uppercase tracking-wider hover:opacity-90 active:scale-[0.98] transition-all"
              >
                Save Daily Log
              </button>
            </form>
          </div>
        </motion.div>

        {/* Dynamic Analytics Chart (Recharts) */}
        <motion.div 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="glass-card rounded-3xl p-6 border border-white/5 lg:col-span-2 flex flex-col justify-between min-h-[350px]"
        >
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <Activity className="w-5 h-5 text-accent-coral" />
              <h3 className="text-lg font-bold text-white font-display">Mood Progression</h3>
            </div>
            <div className="text-xs text-muted flex items-center gap-1.5 bg-background/40 px-3 py-1.5 rounded-lg border border-white/5">
              <TrendingUp className="w-3.5 h-3.5 text-accent-teal" />
              Reflects last {totalLogs} logs
            </div>
          </div>

          <div className="flex-1 w-full h-[250px]">
            {mounted ? (
              chartData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                    <defs>
                      <linearGradient id="colorScore" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="var(--accent-teal)" stopOpacity={0.25}/>
                        <stop offset="95%" stopColor="var(--accent-teal)" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
                    <XAxis 
                      dataKey="name" 
                      stroke="rgba(255,255,255,0.25)" 
                      fontSize={10}
                      tickLine={false}
                      axisLine={false}
                    />
                    <YAxis 
                      domain={[1, 5]} 
                      ticks={[1, 2, 3, 4, 5]}
                      stroke="rgba(255,255,255,0.25)" 
                      fontSize={10}
                      tickLine={false}
                      axisLine={false}
                    />
                    <Tooltip 
                      contentStyle={{ 
                        background: "#12122A", 
                        border: "1px solid rgba(255,255,255,0.08)", 
                        borderRadius: "12px",
                        color: "#F3F4F6",
                        fontSize: "11px"
                      }} 
                    />
                    <Area 
                      type="monotone" 
                      dataKey="score" 
                      stroke="var(--accent-teal)" 
                      strokeWidth={2}
                      fillOpacity={1} 
                      fill="url(#colorScore)" 
                      dot={{ r: 4, stroke: "var(--background)", strokeWidth: 1.5, fill: "var(--accent-teal)" }}
                      activeDot={{ r: 6 }}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              ) : (
                <div className="w-full h-full flex flex-col items-center justify-center text-muted gap-2">
                  <span>No data available to plot chart</span>
                  <span className="text-[10px]">Add your first daily mood log.</span>
                </div>
              )
            ) : (
              <div className="w-full h-full flex items-center justify-center text-muted">
                Loading visual timeline...
              </div>
            )}
          </div>
        </motion.div>
      </div>

      {/* 4. Recent Journal Logs Section */}
      <motion.div
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.6, delay: 0.4 }}
        className="glass-card rounded-3xl p-6 border border-white/5"
      >
        <div className="flex items-center gap-3 mb-6">
          <CalendarDays className="w-5 h-5 text-accent-teal" />
          <h3 className="text-lg font-bold text-white font-display">Recent Mind logs</h3>
        </div>

        {entries.length > 0 ? (
          <div className="space-y-4">
            {entries.map((entry) => (
              <div 
                key={entry.id}
                className="p-4 rounded-2xl bg-background/40 hover:bg-background/60 border border-white/5 flex flex-col md:flex-row md:items-center justify-between gap-4 transition-all duration-300"
              >
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 rounded-xl bg-elevated border border-white/5 flex flex-col items-center justify-center shrink-0">
                    <span className="text-xl">{getMoodEmoji(entry.moodValue)}</span>
                  </div>
                  
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-bold text-white uppercase tracking-wider">
                        {getMoodLabel(entry.moodValue)}
                      </span>
                      <span className="w-1 h-1 rounded-full bg-white/20" />
                      <span className="text-[10px] text-muted">
                        {new Date(entry.createdAt).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}
                      </span>
                    </div>
                    <p className="text-xs text-gray-300 leading-relaxed max-w-2xl">{entry.note}</p>
                  </div>
                </div>

                <div className="text-right shrink-0 md:pl-4">
                  <span className="text-xs font-semibold text-muted bg-white/[0.02] border border-white/5 px-3 py-1.5 rounded-xl">
                    {new Date(entry.createdAt).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })}
                  </span>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-10 text-muted text-xs">
            No entries found. Log your current state above to populate the timeline list.
          </div>
        )}
      </motion.div>
      
    </div>
  );
}
