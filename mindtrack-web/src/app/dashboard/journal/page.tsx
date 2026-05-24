"use client";

import React, { useState, useEffect, useCallback, useMemo } from "react";
import { useSession } from "next-auth/react";
import { motion } from "framer-motion";
import * as Dialog from "@radix-ui/react-dialog";
import axios from "axios";
import { 
  PlusCircle, 
  Search, 
  RefreshCw, 
  AlertCircle, 
  Tag, 
  X, 
  Check, 
  Calendar,
  Sparkles
} from "lucide-react";

// Mood Entry Interface mapping the backend response format
interface MoodEntry {
  id: string;
  userId: string;
  moodScore: number;
  note: string;
  timestamp: string;
  tags: string[];
}

export default function JournalPage() {
  const { data: session, status } = useSession();
  
  // React Hydration Lock
  const [mounted, setMounted] = useState(false);
  
  // Core Data States
  const [entries, setEntries] = useState<MoodEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Interactive Search & Filters
  const [searchQuery, setSearchQuery] = useState("");
  const [activeFilterTag, setActiveFilterTag] = useState<string | null>(null);
  
  // Modal Logging Form States
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [newMood, setNewMood] = useState<number>(4);
  const [newNote, setNewNote] = useState("");
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [successFeedback, setSuccessFeedback] = useState(false);

  // Constants
  const availableTags = ["Sleep", "Work", "Exercise", "Social", "Mindfulness", "Nutrition"];

  useEffect(() => {
    setMounted(true);
  }, []);

  // Fetch all 90 days history for Journal View
  const fetchJournalHistory = useCallback(async () => {
    if (!session?.user?.accessToken) return;
    setIsLoading(true);
    try {
      const res = await axios.get("/api/mood/history?days=90", {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });
      setEntries(res.data);
      setError(null);
    } catch (err: unknown) {
      console.error("Error loading journal history:", err);
      const errorMsg = axios.isAxiosError(err) 
        ? err.response?.data?.error || err.message
        : "Failed to establish a secure database connection. Please ensure backend is running.";
      setError(errorMsg);
    } finally {
      setIsLoading(false);
    }
  }, [session]);

  // Fetch entries when session is established
  useEffect(() => {
    if (status === "authenticated") {
      fetchJournalHistory();
    } else if (status === "unauthenticated") {
      setIsLoading(false);
    }
  }, [status, fetchJournalHistory]);

  // Handle addition of mood
  const handleLogNewEntry = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newMood < 1 || newMood > 5 || !session?.user?.accessToken) return;

    setIsSubmitting(true);
    try {
      await axios.post(
        "/api/mood/log",
        {
          moodScore: newMood,
          note: newNote || "Recorded a moment of mindful reflection.",
          tags: selectedTags,
        },
        {
          headers: {
            Authorization: `Bearer ${session.user.accessToken}`,
          },
        }
      );

      // Success sequence
      setNewNote("");
      setSelectedTags([]);
      setNewMood(4);
      setSuccessFeedback(true);
      
      // Sync log list instantly
      await fetchJournalHistory();
      
      setTimeout(() => {
        setSuccessFeedback(false);
        setIsDialogOpen(false);
      }, 1000);
    } catch (err: unknown) {
      console.error("Error submitting daily journal entry:", err);
      setError("Failed to record mood snapshot. Please verify server connection.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const toggleTagSelection = (tag: string) => {
    if (selectedTags.includes(tag)) {
      setSelectedTags(selectedTags.filter(t => t !== tag));
    } else {
      setSelectedTags([...selectedTags, tag]);
    }
  };

  // Get details (Labels, Emojis, Colors) for each score
  const getMoodDetails = (score: number) => {
    switch (score) {
      case 5:
        return {
          label: "Radiant",
          emoji: "🌟",
          colorClass: "bg-accent-teal/10 border-accent-teal/30 text-accent-teal shadow-[0_0_12px_rgba(0,210,200,0.15)]",
          bulletColor: "bg-accent-teal shadow-[0_0_8px_rgba(0,210,200,0.6)]"
        };
      case 4:
        return {
          label: "Stable",
          emoji: "✨",
          colorClass: "bg-emerald-500/10 border-emerald-500/30 text-emerald-400",
          bulletColor: "bg-emerald-400 shadow-[0_0_6px_rgba(52,211,153,0.5)]"
        };
      case 3:
        return {
          label: "Neutral",
          emoji: "😐",
          colorClass: "bg-indigo-500/10 border-indigo-500/30 text-indigo-400",
          bulletColor: "bg-indigo-400 shadow-[0_0_6px_rgba(129,140,248,0.5)]"
        };
      case 2:
        return {
          label: "Low Energy",
          emoji: "😞",
          colorClass: "bg-amber-500/10 border-amber-500/30 text-amber-400",
          bulletColor: "bg-amber-400 shadow-[0_0_6px_rgba(251,191,36,0.5)]"
        };
      case 1:
        return {
          label: "High Stress",
          emoji: "🔥",
          colorClass: "bg-accent-coral/10 border-accent-coral/30 text-accent-coral shadow-[0_0_12px_rgba(255,107,107,0.15)]",
          bulletColor: "bg-accent-coral shadow-[0_0_8px_rgba(255,107,107,0.6)]"
        };
      default:
        return {
          label: "Neutral",
          emoji: "😐",
          colorClass: "bg-indigo-500/10 border-indigo-500/30 text-indigo-400",
          bulletColor: "bg-indigo-400"
        };
    }
  };

  // Client-Side Search & Tag Filter Logic
  const filteredEntries = useMemo(() => {
    return entries.filter((entry) => {
      const matchesSearch = 
        entry.note.toLowerCase().includes(searchQuery.toLowerCase()) ||
        entry.tags.some(t => t.toLowerCase().includes(searchQuery.toLowerCase()));
      
      const matchesTagFilter = activeFilterTag 
        ? entry.tags.includes(activeFilterTag) 
        : true;

      return matchesSearch && matchesTagFilter;
    });
  }, [entries, searchQuery, activeFilterTag]);

  // Grouping chronological logs by day (Local Calendar Date)
  const groupedEntriesByDay = useMemo(() => {
    const groups: Record<string, MoodEntry[]> = {};

    filteredEntries.forEach((entry) => {
      const date = new Date(entry.timestamp);
      
      // Formatted date string for comparison and grouping
      const dateStr = date.toLocaleDateString("en-US", {
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric"
      });

      // Today / Yesterday comparisons
      const today = new Date();
      const yesterday = new Date();
      yesterday.setDate(today.getDate() - 1);

      const todayStr = today.toLocaleDateString("en-US", {
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric"
      });

      const yesterdayStr = yesterday.toLocaleDateString("en-US", {
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric"
      });

      let displayHeader = dateStr;
      if (dateStr === todayStr) {
        displayHeader = "Today";
      } else if (dateStr === yesterdayStr) {
        displayHeader = "Yesterday";
      }

      if (!groups[displayHeader]) {
        groups[displayHeader] = [];
      }
      groups[displayHeader].push(entry);
    });

    return groups;
  }, [filteredEntries]);

  // Framer Motion staggered settings
  const containerVariants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.08,
      },
    },
  };

  const itemVariants = {
    hidden: { y: 15, opacity: 0 },
    show: { 
      y: 0, 
      opacity: 1, 
      transition: { type: "spring" as const, stiffness: 120, damping: 18 } 
    },
  };

  // Prevent hydration mismatches
  if (!mounted || status === "loading") {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-4">
        <RefreshCw className="w-8 h-8 text-accent-teal animate-spin" />
        <p className="text-xs text-muted tracking-wider uppercase">Calibrating your cosmic logbooks...</p>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-12 subtle-mesh">
      
      {/* 1. Header controls & title */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="space-y-1">
          <h2 className="text-3xl font-bold tracking-tight text-white leading-tight">
            Mood Journal
          </h2>
          <p className="text-xs text-muted">
            Explore 90 days of mental analytics and secure end-to-end reflections.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchJournalHistory}
            disabled={isLoading}
            className="inline-flex items-center gap-2 px-3 py-2 rounded-xl bg-[#12122A] hover:bg-[#1C1C3A] border border-[#1C1C3A] text-xs text-white transition-all disabled:opacity-50"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? "animate-spin" : ""}`} />
            Refresh
          </button>

          {/* Dialog Trigger Wrapper */}
          <Dialog.Root open={isDialogOpen} onOpenChange={setIsDialogOpen}>
            <Dialog.Trigger asChild>
              <button className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-accent-teal hover:bg-accent-teal/90 text-background font-bold text-xs uppercase tracking-wider active:scale-[0.98] transition-all shadow-glow">
                <PlusCircle className="w-4 h-4" />
                Log New Entry
              </button>
            </Dialog.Trigger>

            <Dialog.Portal>
              <Dialog.Overlay className="fixed inset-0 bg-[#0A0A14]/80 backdrop-blur-md z-50 animate-fade-in" />
              <Dialog.Content className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 glass-elevated border border-white/10 rounded-3xl p-6 md:p-8 max-w-md w-[92vw] max-h-[85vh] overflow-y-auto z-50 shadow-2xl space-y-6">
                
                <div className="flex items-center justify-between">
                  <Dialog.Title className="text-xl font-bold font-display text-white flex items-center gap-2">
                    <Sparkles className="w-5 h-5 text-accent-teal" />
                    Log Current Vibe
                  </Dialog.Title>
                  <Dialog.Close asChild>
                    <button className="p-1.5 rounded-lg bg-white/[0.03] hover:bg-white/[0.08] text-muted hover:text-white transition-all">
                      <X className="w-4 h-4" />
                    </button>
                  </Dialog.Close>
                </div>

                <Dialog.Description className="text-xs text-muted leading-relaxed">
                  Log your conscious clarity score, associate activities, and write a secure, personal reflection snippet.
                </Dialog.Description>

                {successFeedback && (
                  <div className="p-3 rounded-xl bg-accent-teal/10 border border-accent-teal/20 text-accent-teal text-xs text-center font-medium animate-pulse">
                    🌱 Mood constellation updated securely in cloud memory!
                  </div>
                )}

                <form onSubmit={handleLogNewEntry} className="space-y-5">
                  
                  {/* Interactive Score Selector */}
                  <div className="space-y-2">
                    <label className="text-xs text-gray-300 font-semibold">Mood Score</label>
                    <div className="grid grid-cols-5 gap-2">
                      {[1, 2, 3, 4, 5].map((val) => {
                        const mood = getMoodDetails(val);
                        const isSelected = newMood === val;
                        return (
                          <button
                            key={val}
                            type="button"
                            onClick={() => setNewMood(val)}
                            className={`py-3.5 rounded-xl border flex flex-col items-center gap-1.5 transition-all duration-300 ${
                              isSelected
                                ? "bg-accent-teal/10 border-accent-teal text-accent-teal scale-105 shadow-[0_0_12px_rgba(0,210,200,0.1)]"
                                : "bg-[#0A0A14]/60 border-white/[0.04] text-muted hover:border-white/10 hover:text-white"
                            }`}
                          >
                            <span className="text-xl">{mood.emoji}</span>
                            <span className="text-[10px] font-bold">{val}</span>
                          </button>
                        );
                      })}
                    </div>
                    <div className="text-center mt-2">
                      <span className="text-[10px] font-bold text-accent-teal uppercase tracking-widest bg-accent-teal/5 px-2.5 py-1 rounded-md border border-accent-teal/10">
                        {getMoodDetails(newMood).label}
                      </span>
                    </div>
                  </div>

                  {/* Associated Tags Checklist */}
                  <div className="space-y-2">
                    <label className="text-xs text-gray-300 font-semibold flex items-center gap-1.5">
                      <Tag className="w-3.5 h-3.5 text-muted" />
                      Associated Tags
                    </label>
                    <div className="flex flex-wrap gap-2">
                      {availableTags.map((tag) => {
                        const isSelected = selectedTags.includes(tag);
                        return (
                          <button
                            key={tag}
                            type="button"
                            onClick={() => toggleTagSelection(tag)}
                            className={`px-3 py-1.5 rounded-xl text-[10px] font-medium border flex items-center gap-1 transition-all ${
                              isSelected
                                ? "bg-accent-teal/10 border-accent-teal text-accent-teal"
                                : "bg-[#0A0A14]/30 border-white/[0.03] text-muted hover:border-white/10 hover:text-white"
                            }`}
                          >
                            {isSelected && <Check className="w-3 h-3" />}
                            {tag}
                          </button>
                        );
                      })}
                    </div>
                  </div>

                  {/* Reflection Text Area */}
                  <div className="space-y-2">
                    <label className="text-xs text-gray-300 font-semibold">Reflection Note</label>
                    <textarea
                      value={newNote}
                      onChange={(e) => setNewNote(e.target.value)}
                      placeholder="Sleep quality, mindfulness check-in, recent triggers, stress levels..."
                      rows={4}
                      className="w-full p-3 bg-[#0A0A14]/70 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 resize-none transition-all"
                    />
                  </div>

                  {/* Modal Action Buttons */}
                  <div className="flex gap-3 pt-2">
                    <Dialog.Close asChild>
                      <button
                        type="button"
                        className="flex-1 py-3 rounded-xl bg-white/[0.02] hover:bg-white/[0.06] border border-white/5 font-semibold text-xs text-gray-300 transition-all active:scale-[0.98]"
                      >
                        Cancel
                      </button>
                    </Dialog.Close>

                    <button
                      type="submit"
                      disabled={isSubmitting}
                      className="flex-1 py-3 rounded-xl bg-accent-teal text-background font-bold text-xs uppercase tracking-wider hover:opacity-95 active:scale-[0.98] transition-all disabled:opacity-50 shadow-glow"
                    >
                      {isSubmitting ? "Encrypting..." : "Commit Log"}
                    </button>
                  </div>

                </form>
              </Dialog.Content>
            </Dialog.Portal>
          </Dialog.Root>
        </div>
      </div>

      {/* 2. Diagnostic error notification */}
      {error && (
        <div className="p-4 rounded-2xl bg-red-950/20 border border-red-500/30 text-red-200 text-xs flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-accent-coral shrink-0" />
          <div className="flex-1">
            <span className="font-semibold">Diagnostic Connection Issue: </span>
            {error}
          </div>
          <button 
            onClick={fetchJournalHistory}
            className="px-3 py-1 bg-accent-coral/20 text-white rounded-lg hover:bg-accent-coral/30 transition-all font-semibold"
          >
            Retry
          </button>
        </div>
      )}

      {/* 3. Search, Filter Chips, and Timeline view */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
        
        {/* Sidebar Filtering Column */}
        <div className="lg:col-span-1 space-y-6">
          <div className="p-6 rounded-3xl bg-[#12122A] border border-white/[0.03] space-y-5">
            <div className="space-y-1.5">
              <h3 className="text-xs font-bold text-white uppercase tracking-wider">Search Timeline</h3>
              <p className="text-[10px] text-muted">Locate journals by notes or tags instantenously.</p>
            </div>

            <div className="relative">
              <input
                type="text"
                placeholder="Search note or #tag..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-9 pr-4 py-2.5 bg-[#0A0A14]/70 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 transition-all"
              />
              <Search className="w-4 h-4 text-muted absolute left-3 top-3.5" />
              {searchQuery && (
                <button 
                  onClick={() => setSearchQuery("")}
                  className="absolute right-3 top-3.5 text-muted hover:text-white"
                >
                  <X className="w-3.5 h-3.5" />
                </button>
              )}
            </div>

            <div className="border-t border-white/[0.04] pt-4 space-y-4">
              <div className="space-y-1">
                <h4 className="text-[10px] font-bold text-white uppercase tracking-widest">Tag Filtering</h4>
                <p className="text-[9px] text-muted">Filter timeline to single conscious category.</p>
              </div>

              <div className="flex flex-wrap lg:flex-col gap-2">
                <button
                  onClick={() => setActiveFilterTag(null)}
                  className={`px-3 py-2 rounded-xl text-left text-xs font-medium border transition-all flex items-center justify-between ${
                    activeFilterTag === null
                      ? "bg-accent-teal/10 border-accent-teal/40 text-accent-teal"
                      : "bg-[#0A0A14]/30 border-white/[0.02] text-muted hover:border-white/10 hover:text-white"
                  }`}
                >
                  <span className="flex items-center gap-2">
                    <span className={`w-1.5 h-1.5 rounded-full ${activeFilterTag === null ? "bg-accent-teal" : "bg-muted"}`} />
                    All Logs
                  </span>
                  <span className="text-[9px] bg-white/[0.04] px-1.5 py-0.5 rounded text-muted">
                    {entries.length}
                  </span>
                </button>

                {availableTags.map((tag) => {
                  const tagCount = entries.filter((e) => e.tags.includes(tag)).length;
                  const isActive = activeFilterTag === tag;
                  return (
                    <button
                      key={tag}
                      onClick={() => setActiveFilterTag(isActive ? null : tag)}
                      className={`px-3 py-2 rounded-xl text-left text-xs font-medium border transition-all flex items-center justify-between ${
                        isActive
                          ? "bg-accent-teal/10 border-accent-teal/40 text-accent-teal"
                          : "bg-[#0A0A14]/30 border-white/[0.02] text-muted hover:border-white/10 hover:text-white"
                      }`}
                    >
                      <span className="flex items-center gap-2">
                        <Tag className={`w-3.5 h-3.5 ${isActive ? "text-accent-teal" : "text-muted"}`} />
                        {tag}
                      </span>
                      <span className="text-[9px] bg-white/[0.04] px-1.5 py-0.5 rounded text-muted">
                        {tagCount}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </div>

        {/* Timeline Stream Column */}
        <div className="lg:col-span-3 space-y-6">
          {isLoading ? (
            <div className="space-y-6">
              {[1, 2, 3].map((skeleton) => (
                <div key={skeleton} className="p-6 rounded-3xl bg-[#12122A]/50 border border-white/[0.02] space-y-4 animate-pulse">
                  <div className="flex items-center justify-between">
                    <div className="h-4 w-28 bg-white/5 rounded" />
                    <div className="h-5 w-20 bg-white/5 rounded-full" />
                  </div>
                  <div className="space-y-2">
                    <div className="h-3 w-full bg-white/5 rounded" />
                    <div className="h-3 w-5/6 bg-white/5 rounded" />
                  </div>
                  <div className="flex gap-2">
                    <div className="h-4 w-12 bg-white/5 rounded" />
                    <div className="h-4 w-16 bg-white/5 rounded" />
                  </div>
                </div>
              ))}
            </div>
          ) : filteredEntries.length === 0 ? (
            <div className="glass-card rounded-3xl p-12 border border-white/5 text-center min-h-[480px] flex flex-col items-center justify-center space-y-6">
              
              {/* Premium Constellation SVG Graphic */}
              <div className="relative">
                <div className="absolute inset-0 bg-accent-teal/10 blur-3xl rounded-full" />
                <svg className="w-40 h-40 mx-auto text-accent-teal/40 opacity-75 relative z-10" viewBox="0 0 100 100" fill="none" stroke="currentColor">
                  {/* Twinkling Constellation Stars */}
                  <circle cx="20" cy="30" r="1.5" className="fill-accent-coral animate-ping" />
                  <circle cx="20" cy="30" r="1" className="fill-accent-coral" />
                  
                  <circle cx="50" cy="15" r="2.5" className="fill-accent-teal animate-pulse" />
                  <circle cx="50" cy="15" r="1.5" className="fill-accent-teal" />
                  
                  <circle cx="80" cy="25" r="1.5" className="fill-purple-400 animate-ping" />
                  <circle cx="80" cy="25" r="1" className="fill-purple-400" />
                  
                  <circle cx="35" cy="65" r="2.5" className="fill-accent-teal animate-pulse" />
                  <circle cx="35" cy="65" r="1" className="fill-accent-teal" />
                  
                  <circle cx="65" cy="75" r="2" className="fill-accent-coral animate-pulse" />
                  <circle cx="65" cy="75" r="1" className="fill-accent-coral" />
                  
                  <circle cx="85" cy="60" r="1.5" className="fill-indigo-400" />
                  
                  {/* Dotted Connections representing Mind Map / Emotional Universe */}
                  <line x1="20" y1="30" x2="50" y2="15" stroke="currentColor" strokeWidth="0.5" strokeDasharray="2 2" className="opacity-40" />
                  <line x1="50" y1="15" x2="80" y2="25" stroke="currentColor" strokeWidth="0.5" strokeDasharray="2 2" className="opacity-40" />
                  <line x1="80" y1="25" x2="85" y2="60" stroke="currentColor" strokeWidth="0.5" strokeDasharray="2 2" className="opacity-40" />
                  <line x1="35" y1="65" x2="65" y2="75" stroke="currentColor" strokeWidth="0.5" strokeDasharray="2 2" className="opacity-40" />
                  <line x1="65" y1="75" x2="85" y2="60" stroke="currentColor" strokeWidth="0.5" strokeDasharray="2 2" className="opacity-40" />
                  <line x1="20" y1="30" x2="35" y2="65" stroke="currentColor" strokeWidth="0.5" strokeDasharray="2 2" className="opacity-40" />
                  <line x1="50" y1="15" x2="65" y2="75" stroke="currentColor" strokeWidth="0.5" strokeDasharray="2 2" className="opacity-40" />
                </svg>
              </div>

              <div className="space-y-2 max-w-sm">
                <h3 className="text-lg font-bold font-display text-white">Your emotional universe awaits</h3>
                <p className="text-xs text-muted leading-relaxed">
                  {searchQuery || activeFilterTag
                    ? "No mental logs align with the current search query or tag filtering."
                    : "No conscious logs are seeded in your 90-day history. Cultivate focus by committing your first state reflection."}
                </p>
              </div>

              {searchQuery || activeFilterTag ? (
                <button
                  onClick={() => {
                    setSearchQuery("");
                    setActiveFilterTag(null);
                  }}
                  className="px-4 py-2 bg-white/[0.04] hover:bg-white/[0.08] border border-white/5 rounded-xl text-xs text-white font-medium transition-all"
                >
                  Clear All Filters
                </button>
              ) : (
                <button
                  onClick={() => setIsDialogOpen(true)}
                  className="px-5 py-2.5 rounded-xl bg-accent-teal hover:bg-accent-teal/90 text-background font-bold text-xs uppercase tracking-wider transition-all shadow-glow active:scale-[0.98]"
                >
                  Log Your First Entry
                </button>
              )}
            </div>
          ) : (
            
            // Staggered Timeline View
            <motion.div 
              variants={containerVariants}
              initial="hidden"
              animate="show"
              className="space-y-8 relative pl-6 before:absolute before:left-[11px] before:top-4 before:bottom-4 before:w-[2px] before:bg-white/[0.05]"
            >
              {Object.keys(groupedEntriesByDay).map((dayHeader) => {
                const dayEntries = groupedEntriesByDay[dayHeader];
                
                return (
                  <div key={dayHeader} className="space-y-4 relative">
                    
                    {/* Day Group Header Label */}
                    <div className="-ml-[17px] flex items-center gap-3">
                      <div className={`w-3.5 h-3.5 rounded-full border bg-[#0A0A14] flex items-center justify-center z-10 ${
                        dayHeader === "Today" 
                          ? "border-accent-teal" 
                          : dayHeader === "Yesterday" 
                            ? "border-accent-coral" 
                            : "border-white/20"
                      }`}>
                        <div className={`w-1.5 h-1.5 rounded-full ${
                          dayHeader === "Today" 
                            ? "bg-accent-teal animate-pulse" 
                            : dayHeader === "Yesterday" 
                              ? "bg-accent-coral" 
                              : "bg-white/40"
                        }`} />
                      </div>

                      <span className={`text-xs font-bold uppercase tracking-wider font-display px-2.5 py-1 rounded-lg border ${
                        dayHeader === "Today"
                          ? "bg-accent-teal/5 border-accent-teal/20 text-accent-teal"
                          : dayHeader === "Yesterday"
                            ? "bg-accent-coral/5 border-accent-coral/20 text-accent-coral"
                            : "bg-[#12122A] border-white/[0.03] text-gray-300"
                      }`}>
                        {dayHeader}
                      </span>
                    </div>

                    {/* Timeline List of Cards */}
                    <div className="space-y-4">
                      {dayEntries.map((entry) => {
                        const mood = getMoodDetails(entry.moodScore);
                        const dateFormatted = new Date(entry.timestamp);
                        const timeStr = dateFormatted.toLocaleTimeString("en-US", {
                          hour: "numeric",
                          minute: "2-digit"
                        });

                        return (
                          <motion.div
                            key={entry.id}
                            variants={itemVariants}
                            className="group relative pl-4"
                          >
                            {/* Inner bullet indicator */}
                            <div className="absolute -left-[20px] top-6 flex items-center justify-center">
                              <div className={`w-2 h-2 rounded-full z-10 transition-all group-hover:scale-125 ${mood.bulletColor}`} />
                            </div>

                            {/* Journal Card */}
                            <div className="p-5 rounded-2xl bg-[#12122A] border border-white/[0.03] hover:border-white/[0.08] transition-all duration-300 space-y-3.5 hover:shadow-[0_4px_24px_rgba(0,0,0,0.2)]">
                              
                              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
                                
                                {/* Badge details */}
                                <div className="flex items-center gap-2.5">
                                  <span className={`px-2.5 py-1 rounded-xl text-[10px] font-bold uppercase tracking-wider border flex items-center gap-1.5 ${mood.colorClass}`}>
                                    <span>{mood.emoji}</span>
                                    <span>{mood.label}</span>
                                  </span>

                                  <span className="text-[10px] text-muted bg-white/[0.02] border border-white/5 px-2.5 py-1 rounded-lg">
                                    Score: <span className="font-bold text-white">{entry.moodScore}</span> / 5
                                  </span>
                                </div>

                                {/* Timestamp */}
                                <div className="text-[10px] text-muted flex items-center gap-1">
                                  <Calendar className="w-3 h-3 opacity-60" />
                                  <span>{timeStr}</span>
                                </div>
                              </div>

                              {/* Reflection note snippet */}
                              <p className="text-xs text-gray-300 leading-relaxed font-sans pr-4">
                                {entry.note}
                              </p>

                              {/* Tags */}
                              {entry.tags && entry.tags.length > 0 && (
                                <div className="flex flex-wrap items-center gap-1.5 border-t border-white/[0.03] pt-3.5">
                                  <Tag className="w-3 h-3 text-muted" />
                                  {entry.tags.map((tag) => {
                                    const isFilterActive = activeFilterTag === tag;
                                    return (
                                      <button
                                        key={tag}
                                        onClick={(e) => {
                                          e.stopPropagation();
                                          setActiveFilterTag(isFilterActive ? null : tag);
                                        }}
                                        className={`px-2 py-0.5 rounded-lg text-[9px] font-semibold uppercase tracking-wider transition-all ${
                                          isFilterActive
                                            ? "bg-accent-teal/20 border border-accent-teal text-accent-teal"
                                            : "bg-[#0A0A14]/60 border border-white/[0.04] text-muted hover:border-accent-teal/30 hover:text-accent-teal"
                                        }`}
                                      >
                                        {tag}
                                      </button>
                                    );
                                  })}
                                </div>
                              )}

                            </div>
                          </motion.div>
                        );
                      })}
                    </div>

                  </div>
                );
              })}
            </motion.div>

          )}
        </div>

      </div>

    </div>
  );
}
