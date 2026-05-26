"use client";

import React, { useState, useEffect } from "react";
import { useSession } from "next-auth/react";
import { motion, AnimatePresence } from "framer-motion";
import * as Dialog from "@radix-ui/react-dialog";
import axios from "axios";
import {
  User,
  KeyRound,
  Download,
  Bell,
  Clock,
  ListFilter,
  Info,
  Award,
  AlertOctagon,
  X,
  Check,
  RefreshCw,
  ExternalLink,
  ShieldCheck,
  Brain,
  Cpu,
  History,
  EyeOff
} from "lucide-react";

// Robust inline custom SVG GithubIcon to prevent version mismatches in Lucide imports
const GithubIcon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    {...props}
  >
    <path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4" />
    <path d="M9 18c-4.51 2-5-2-7-2" />
  </svg>
);

interface Toast {
  message: string;
  type: "success" | "error" | "info";
}

export default function SettingsPage() {
  const { data: session, status } = useSession();
  const [mounted, setMounted] = useState(false);

  // Toast Notification State
  const [toast, setToast] = useState<Toast | null>(null);

  // Account - Change Password Form States
  const [isPasswordDialogOpen, setIsPasswordDialogOpen] = useState(false);
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isChangingPassword, setIsChangingPassword] = useState(false);
  const [passwordError, setPasswordError] = useState<string | null>(null);

  // Account - Exporting State
  const [isExporting, setIsExporting] = useState(false);

  // Preferences States (backed by Spring Boot API)
  const [themeMode, setThemeMode] = useState("dark");
  const [dailyReminder, setDailyReminder] = useState(false);
  const [reminderTime, setReminderTime] = useState("20:00");
  const [defaultCopingTechnique, setDefaultCopingTechnique] = useState("Breathing");
  const [privacyMode, setPrivacyMode] = useState("standard");
  const [aiJournalAnalysisEnabled, setAiJournalAnalysisEnabled] = useState(false);
  const [aiChatHistoryEnabled, setAiChatHistoryEnabled] = useState(false);
  const [shareNotesWithAi, setShareNotesWithAi] = useState(false);
  const [entriesPerPage, setEntriesPerPage] = useState(10); // Local-only

  // Danger Zone - Clear Data Dialog State
  const [isClearDialogOpen, setIsClearDialogOpen] = useState(false);

  // Mount logic to handle localstorage & fetch settings from server
  useEffect(() => {
    setMounted(true);

    if (typeof window !== "undefined") {
      const storedEntries = localStorage.getItem("mindtrack_entries_per_page");
      if (storedEntries !== null) {
        setEntriesPerPage(parseInt(storedEntries, 10));
      }
    }

    const fetchPreferences = async () => {
      if (!session?.user?.accessToken) return;
      try {
        const response = await axios.get("/api/user/preferences", {
          headers: {
            Authorization: `Bearer ${session.user.accessToken}`,
          },
        });
        const prefs = response.data;
        if (prefs) {
          setThemeMode(prefs.themeMode || "dark");
          setDailyReminder(prefs.reminderEnabled ?? true);
          setReminderTime(prefs.reminderTime || "20:00");
          setDefaultCopingTechnique(prefs.defaultCopingTechnique || "Breathing");
          setPrivacyMode(prefs.privacyMode || "standard");
          setAiJournalAnalysisEnabled(prefs.aiJournalAnalysisEnabled ?? false);
          setAiChatHistoryEnabled(prefs.aiChatHistoryEnabled ?? false);
          setShareNotesWithAi(prefs.shareNotesWithAi ?? false);
        }
      } catch (err: unknown) {
        console.error("Failed to load preferences:", err);
        showToast("Unable to synchronize settings with server.", "error");
      }
    };

    if (status === "authenticated") {
      fetchPreferences();
    }
  }, [session, status]);

  // Show a toast message helper
  const showToast = (message: string, type: "success" | "error" | "info" = "success") => {
    setToast({ message, type });
    setTimeout(() => {
      setToast(null);
    }, 4000);
  };

  const updatePreferenceOnBackend = async (updatedFields: {
    themeMode?: string;
    reminderEnabled?: boolean;
    reminderTime?: string;
    defaultCopingTechnique?: string;
    privacyMode?: string;
    aiJournalAnalysisEnabled?: boolean;
    aiChatHistoryEnabled?: boolean;
    shareNotesWithAi?: boolean;
  }) => {
    // Save previous state for reverting on error
    const prevTheme = themeMode;
    const prevReminder = dailyReminder;
    const prevTime = reminderTime;
    const prevCoping = defaultCopingTechnique;
    const prevPrivacy = privacyMode;
    const prevAiJournal = aiJournalAnalysisEnabled;
    const prevAiChat = aiChatHistoryEnabled;
    const prevShareNotes = shareNotesWithAi;

    // Optimistically apply state
    if (updatedFields.themeMode !== undefined) setThemeMode(updatedFields.themeMode);
    if (updatedFields.reminderEnabled !== undefined) setDailyReminder(updatedFields.reminderEnabled);
    if (updatedFields.reminderTime !== undefined) setReminderTime(updatedFields.reminderTime);
    if (updatedFields.defaultCopingTechnique !== undefined) setDefaultCopingTechnique(updatedFields.defaultCopingTechnique);
    if (updatedFields.privacyMode !== undefined) setPrivacyMode(updatedFields.privacyMode);
    if (updatedFields.aiJournalAnalysisEnabled !== undefined) setAiJournalAnalysisEnabled(updatedFields.aiJournalAnalysisEnabled);
    if (updatedFields.aiChatHistoryEnabled !== undefined) setAiChatHistoryEnabled(updatedFields.aiChatHistoryEnabled);
    if (updatedFields.shareNotesWithAi !== undefined) setShareNotesWithAi(updatedFields.shareNotesWithAi);

    try {
      const payload = {
        themeMode: updatedFields.themeMode !== undefined ? updatedFields.themeMode : prevTheme,
        reminderEnabled: updatedFields.reminderEnabled !== undefined ? updatedFields.reminderEnabled : prevReminder,
        reminderTime: updatedFields.reminderTime !== undefined ? updatedFields.reminderTime : prevTime,
        defaultCopingTechnique: updatedFields.defaultCopingTechnique !== undefined ? updatedFields.defaultCopingTechnique : prevCoping,
        privacyMode: updatedFields.privacyMode !== undefined ? updatedFields.privacyMode : prevPrivacy,
        aiJournalAnalysisEnabled: updatedFields.aiJournalAnalysisEnabled !== undefined ? updatedFields.aiJournalAnalysisEnabled : prevAiJournal,
        aiChatHistoryEnabled: updatedFields.aiChatHistoryEnabled !== undefined ? updatedFields.aiChatHistoryEnabled : prevAiChat,
        shareNotesWithAi: updatedFields.shareNotesWithAi !== undefined ? updatedFields.shareNotesWithAi : prevShareNotes,
      };

      await axios.put("/api/user/preferences", payload, {
        headers: {
          Authorization: `Bearer ${session?.user?.accessToken || ""}`,
        },
      });
    } catch (err: unknown) {
      console.error("Failed to update preferences on backend:", err);
      // Revert state
      setThemeMode(prevTheme);
      setDailyReminder(prevReminder);
      setReminderTime(prevTime);
      setDefaultCopingTechnique(prevCoping);
      setPrivacyMode(prevPrivacy);
      setAiJournalAnalysisEnabled(prevAiJournal);
      setAiChatHistoryEnabled(prevAiChat);
      setShareNotesWithAi(prevShareNotes);

      showToast("Failed to save preference. Reverting change.", "error");
    }
  };

  // Preference Handlers
  const handleToggleReminder = (enabled: boolean) => {
    updatePreferenceOnBackend({ reminderEnabled: enabled });
    showToast(
      enabled
        ? `Daily notification reminder scheduled for ${reminderTime}!`
        : "Daily notification reminder deactivated.",
      "info"
    );
  };

  const handleChangeReminderTime = (time: string) => {
    setReminderTime(time);
  };

  const handleTimeBlur = () => {
    updatePreferenceOnBackend({ reminderTime });
    showToast(`Reminder alert time rescheduled to ${reminderTime}.`, "success");
  };

  const handleChangeThemeMode = (mode: string) => {
    updatePreferenceOnBackend({ themeMode: mode });
    showToast(`Theme mode updated to ${mode}.`, "success");
  };

  const handleChangeCopingTechnique = (tech: string) => {
    updatePreferenceOnBackend({ defaultCopingTechnique: tech });
    showToast(`Default coping technique set to ${tech}.`, "success");
  };

  const handleChangePrivacyMode = (mode: string) => {
    updatePreferenceOnBackend({ privacyMode: mode });
    showToast(`Privacy mode updated to ${mode}.`, "success");
  };

  const handleChangeEntriesPerPage = (entries: number) => {
    setEntriesPerPage(entries);
    localStorage.setItem("mindtrack_entries_per_page", String(entries));
    showToast(`Journal configured to show ${entries} entries per page.`, "success");
  };

  // Action - Change Password Form Submission
  const handleChangePasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError(null);

    if (!currentPassword || !newPassword || !confirmPassword) {
      setPasswordError("All fields are required.");
      return;
    }

    if (newPassword.length < 8) {
      setPasswordError("New password must be at least 8 characters.");
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError("Passwords do not match.");
      return;
    }

    if (currentPassword === newPassword) {
      setPasswordError("New password cannot be identical to the current one.");
      return;
    }

    setIsChangingPassword(true);
    try {
      const response = await axios.post(
        "/api/user/change-password",
        { currentPassword, newPassword },
        {
          headers: {
            Authorization: `Bearer ${session?.user?.accessToken || ""}`,
          },
        }
      );

      showToast(response.data.message || "Credentials updated successfully!", "success");
      
      // Reset form states
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setIsPasswordDialogOpen(false);
    } catch (err: unknown) {
      console.error("Change password error:", err);
      let errMsg = "Failed to establish database connection. Please try again.";
      if (axios.isAxiosError(err) && err.response) {
        const data = err.response.data;
        if (data.errors && typeof data.errors === "object") {
          errMsg = Object.values(data.errors).join(". ");
        } else {
          errMsg = data.message || data.error || err.message;
        }
      }
      setPasswordError(errMsg);
    } finally {
      setIsChangingPassword(false);
    }
  };

  // Action - Export Mood History Data
  const handleExportData = async () => {
    if (!session?.user?.accessToken) {
      showToast("Authentication required to export your personal data.", "error");
      return;
    }

    setIsExporting(true);
    try {
      // Fetch 365 days history to cover the full year
      const response = await axios.get("/api/mood/history?days=365", {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      const historyData = response.data;

      // Wrap in standard backup schema
      const exportPayload = {
        app: "MindTrack",
        version: "1.0.0",
        exportedAt: new Date().toISOString(),
        userEmail: session.user.email,
        totalEntries: Array.isArray(historyData) ? historyData.length : 0,
        entries: historyData,
      };

      // Trigger standard file download using Blob URLs
      const blob = new Blob([JSON.stringify(exportPayload, null, 2)], {
        type: "application/json;charset=utf-8;",
      });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.setAttribute("download", `mindtrack-export-${new Date().toISOString().split("T")[0]}.json`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      showToast("Personal mood history successfully downloaded!", "success");
    } catch (err: unknown) {
      console.error("Export data failure:", err);
      showToast("Failed to compile and download your history. Please try again.", "error");
    } finally {
      setIsExporting(false);
    }
  };

  // Action - Danger Zone clear data placeholder
  const handleConfirmClearData = () => {
    setIsClearDialogOpen(false);
    showToast("Feature coming soon", "info");
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
    hidden: { opacity: 0, y: 20 },
    show: {
      opacity: 1,
      y: 0,
      transition: { type: "spring" as const, stiffness: 100, damping: 15 },
    },
  };

  // Render Loader prior to hydration
  if (!mounted || status === "loading") {
    return (
      <div className="space-y-8 pb-12 subtle-mesh animate-pulse">
        {/* Header skeleton */}
        <div className="flex flex-col gap-2">
          <div className="h-9 w-40 bg-white/5 rounded-xl shimmer-pulse" />
          <div className="h-4 w-72 bg-white/5 rounded-lg shimmer-pulse" />
        </div>

        {/* Grid skeleton */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Card 1: Account */}
          <div className="p-6 md:p-8 rounded-3xl bg-[#12122A] border border-white/[0.04] space-y-6">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-white/5 shimmer-pulse" />
              <div className="space-y-2">
                <div className="h-5 w-36 bg-white/5 rounded shimmer-pulse" />
                <div className="h-3 w-48 bg-white/5 rounded shimmer-pulse" />
              </div>
            </div>
            <div className="border-t border-white/[0.04] pt-4">
              <div className="h-16 w-full bg-[#0A0A14]/40 rounded-2xl border border-white/[0.02] shimmer-pulse" />
            </div>
            <div className="flex gap-3 pt-2">
              <div className="h-10 flex-1 bg-white/5 rounded-xl shimmer-pulse" />
              <div className="h-10 flex-1 bg-white/5 rounded-xl shimmer-pulse" />
            </div>
          </div>

          {/* Card 2: Preferences */}
          <div className="p-6 md:p-8 rounded-3xl bg-[#12122A] border border-white/[0.04] space-y-6">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-white/5 shimmer-pulse" />
              <div className="space-y-2">
                <div className="h-5 w-36 bg-white/5 rounded shimmer-pulse" />
                <div className="h-3 w-48 bg-white/5 rounded shimmer-pulse" />
              </div>
            </div>
            <div className="border-t border-white/[0.04] pt-4 space-y-6">
              <div className="flex justify-between items-center">
                <div className="space-y-2">
                  <div className="h-4 w-32 bg-white/5 rounded shimmer-pulse" />
                  <div className="h-3 w-48 bg-white/5 rounded shimmer-pulse" />
                </div>
                <div className="w-12 h-6 bg-white/5 rounded-full shimmer-pulse" />
              </div>
              <div className="space-y-2">
                <div className="h-4 w-40 bg-white/5 rounded shimmer-pulse" />
                <div className="h-3 w-56 bg-white/5 rounded shimmer-pulse" />
                <div className="h-10 w-full bg-[#0A0A14]/60 rounded-xl border border-white/[0.02] shimmer-pulse" />
              </div>
            </div>
          </div>

          {/* Card 3: About */}
          <div className="p-6 md:p-8 rounded-3xl bg-[#12122A] border border-white/[0.04] space-y-6">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-white/5 shimmer-pulse" />
              <div className="space-y-2">
                <div className="h-5 w-32 bg-white/5 rounded shimmer-pulse" />
                <div className="h-3 w-52 bg-white/5 rounded shimmer-pulse" />
              </div>
            </div>
            <div className="border-t border-white/[0.04] pt-4 space-y-4">
              <div className="h-16 w-full bg-[#0A0A14]/40 rounded-2xl border border-white/[0.02] shimmer-pulse" />
              <div className="h-16 w-full bg-white/5 rounded-2xl shimmer-pulse" />
            </div>
          </div>

          {/* Card 4: Danger Zone */}
          <div className="p-6 md:p-8 rounded-3xl bg-[#12122A] border border-accent-coral/10 space-y-6">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-white/5 shimmer-pulse" />
              <div className="space-y-2">
                <div className="h-5 w-24 bg-white/5 rounded shimmer-pulse" />
                <div className="h-3 w-40 bg-white/5 rounded shimmer-pulse" />
              </div>
            </div>
            <div className="border-t border-white/[0.04] pt-4">
              <div className="h-16 w-full bg-white/5 rounded-2xl shimmer-pulse" />
            </div>
            <div className="h-10 w-full bg-white/5 rounded-xl shimmer-pulse" />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-12 subtle-mesh relative min-h-screen">
      {/* Absolute floating toast alert system */}
      <AnimatePresence>
        {toast && (
          <motion.div
            initial={{ opacity: 0, y: -20, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -20, scale: 0.95 }}
            className={`fixed top-6 right-6 z-50 flex items-center gap-3 px-5 py-4 rounded-2xl border backdrop-blur-xl shadow-2xl max-w-sm ${
              toast.type === "success"
                ? "bg-[#0A2A22]/80 border-accent-teal/30 text-accent-teal shadow-[0_0_24px_rgba(0,210,200,0.15)]"
                : toast.type === "error"
                ? "bg-[#3A0F0F]/80 border-accent-coral/30 text-accent-coral shadow-[0_0_24px_rgba(255,107,107,0.15)]"
                : "bg-[#12122A]/90 border-white/10 text-gray-300"
            }`}
          >
            {toast.type === "success" ? (
              <Check className="w-5 h-5 shrink-0" />
            ) : toast.type === "error" ? (
              <AlertOctagon className="w-5 h-5 shrink-0" />
            ) : (
              <Info className="w-5 h-5 shrink-0" />
            )}
            <p className="text-xs font-semibold leading-relaxed">{toast.message}</p>
            <button
              onClick={() => setToast(null)}
              className="ml-2 p-1 rounded-lg bg-white/5 hover:bg-white/15 text-white/40 hover:text-white transition-all"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Header controls & title */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="space-y-1">
          <h2 className="text-3xl font-bold tracking-tight text-white leading-tight">Settings</h2>
          <p className="text-xs text-muted">
            Configure system states, credentials, notifications, and telemetry policies.
          </p>
        </div>
      </div>

      {/* Staggered Sections Container */}
      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="show"
        className="grid grid-cols-1 lg:grid-cols-2 gap-8"
      >
        {/* 1. Account Section Card */}
        <motion.div
          variants={itemVariants}
          className="p-6 md:p-8 rounded-3xl bg-[#12122A] border border-white/[0.04] flex flex-col justify-between space-y-6 hover:border-white/[0.08] transition-all"
        >
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-accent-teal/10 flex items-center justify-center text-accent-teal">
                <User className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-lg font-bold font-display text-white">Account Information</h3>
                <p className="text-[10px] text-muted">Manage credentials and export telemetry history.</p>
              </div>
            </div>

            <div className="border-t border-white/[0.04] pt-4 space-y-4">
              {/* Session Email Display */}
              <div className="space-y-1 bg-[#0A0A14]/40 p-4 rounded-2xl border border-white/[0.02]">
                <span className="text-[10px] font-bold text-muted uppercase tracking-wider block">Registered Email</span>
                <span className="text-sm font-semibold text-gray-200">
                  {session?.user?.email || "anonymous.user@mindtrack.io"}
                </span>
              </div>
            </div>
          </div>

          <div className="flex flex-wrap gap-3 pt-2">
            {/* Change Password Dialog Trigger */}
            <Dialog.Root open={isPasswordDialogOpen} onOpenChange={setIsPasswordDialogOpen}>
              <Dialog.Trigger asChild>
                <button className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-white/[0.02] hover:bg-white/[0.06] border border-white/5 font-semibold text-xs text-gray-200 active:scale-[0.98] transition-all">
                  <KeyRound className="w-4 h-4 text-accent-teal" />
                  Change Password
                </button>
              </Dialog.Trigger>

              <Dialog.Portal>
                <Dialog.Overlay className="fixed inset-0 bg-[#0A0A14]/80 backdrop-blur-md z-50 animate-fade-in" />
                <Dialog.Content className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 glass-elevated border border-white/10 rounded-3xl p-6 md:p-8 max-w-md w-[92vw] z-50 shadow-2xl space-y-6">
                  <div className="flex items-center justify-between">
                    <Dialog.Title className="text-xl font-bold font-display text-white flex items-center gap-2">
                      <KeyRound className="w-5 h-5 text-accent-teal" />
                      Modify Password
                    </Dialog.Title>
                    <Dialog.Close asChild>
                      <button className="p-1.5 rounded-lg bg-white/[0.03] hover:bg-white/[0.08] text-muted hover:text-white transition-all">
                        <X className="w-4 h-4" />
                      </button>
                    </Dialog.Close>
                  </div>

                  <Dialog.Description className="text-xs text-muted leading-relaxed">
                    Enter your existing credentials along with a highly secure new password passphrase.
                  </Dialog.Description>

                  {passwordError && (
                    <div className="p-3 rounded-xl bg-accent-coral/10 border border-accent-coral/20 text-accent-coral text-xs font-semibold animate-pulse">
                      ⚠️ {passwordError}
                    </div>
                  )}

                  <form onSubmit={handleChangePasswordSubmit} className="space-y-4">
                    <div className="space-y-1">
                      <label className="text-[10px] font-bold text-gray-300 uppercase tracking-widest">Current Password</label>
                      <input
                        type="password"
                        value={currentPassword}
                        onChange={(e) => setCurrentPassword(e.target.value)}
                        placeholder="••••••••"
                        className="w-full p-3 bg-[#0A0A14]/70 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 transition-all"
                      />
                    </div>

                    <div className="space-y-1">
                      <label className="text-[10px] font-bold text-gray-300 uppercase tracking-widest">New Password</label>
                      <input
                        type="password"
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
                        placeholder="••••••••"
                        className="w-full p-3 bg-[#0A0A14]/70 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 transition-all"
                      />
                    </div>

                    <div className="space-y-1">
                      <label className="text-[10px] font-bold text-gray-300 uppercase tracking-widest">Confirm New Password</label>
                      <input
                        type="password"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        placeholder="••••••••"
                        className="w-full p-3 bg-[#0A0A14]/70 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 transition-all"
                      />
                    </div>

                    <div className="flex gap-3 pt-3">
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
                        disabled={isChangingPassword}
                        className="flex-1 py-3 rounded-xl bg-accent-teal text-background font-bold text-xs uppercase tracking-wider hover:opacity-95 active:scale-[0.98] transition-all disabled:opacity-50 shadow-glow"
                      >
                        {isChangingPassword ? "Saving..." : "Commit Update"}
                      </button>
                    </div>
                  </form>
                </Dialog.Content>
              </Dialog.Portal>
            </Dialog.Root>

            {/* Export History Trigger */}
            <button
              onClick={handleExportData}
              disabled={isExporting}
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-accent-teal hover:bg-accent-teal/90 text-background font-bold text-xs uppercase tracking-wider active:scale-[0.98] transition-all disabled:opacity-50 shadow-glow"
            >
              {isExporting ? (
                <RefreshCw className="w-4 h-4 animate-spin" />
              ) : (
                <Download className="w-4 h-4" />
              )}
              {isExporting ? "Compiling..." : "Export Data"}
            </button>
          </div>
        </motion.div>

        {/* 2. Preferences Section Card */}
        <motion.div
          variants={itemVariants}
          className="p-6 md:p-8 rounded-3xl bg-[#12122A] border border-white/[0.04] space-y-6 hover:border-white/[0.08] transition-all"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-accent-teal/10 flex items-center justify-center text-accent-teal">
              <Bell className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-bold font-display text-white">Daily Preferences</h3>
              <p className="text-[10px] text-muted">Customize notification schedules and rendering sizes.</p>
            </div>
          </div>

          <div className="border-t border-white/[0.04] pt-4 space-y-6">
            {/* Daily Reminder Toggle */}
            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <span className="text-xs font-semibold text-gray-200">Daily Reminder Alert</span>
                <span className="text-[10px] text-muted block leading-tight">
                  Receive a prompt to record daily emotional vibrations.
                </span>
              </div>
              <button
                onClick={() => handleToggleReminder(!dailyReminder)}
                className={`w-12 h-6.5 rounded-full p-1 transition-all duration-300 ${
                  dailyReminder ? "bg-accent-teal shadow-[0_0_12px_rgba(0,210,200,0.3)]" : "bg-[#0A0A14] border border-white/5"
                }`}
              >
                <div
                  className={`w-4.5 h-4.5 rounded-full transition-all duration-300 ${
                    dailyReminder ? "bg-background translate-x-5.5" : "bg-muted translate-x-0"
                  }`}
                />
              </button>
            </div>

            {/* Reminder Time Picker - Conditionally Shown */}
            <AnimatePresence initial={false}>
              {dailyReminder && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={{ type: "spring", stiffness: 120, damping: 18 }}
                  className="overflow-hidden space-y-2"
                >
                  <label className="text-[10px] font-bold text-gray-300 uppercase tracking-widest flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5 text-accent-teal" />
                    Reminder Dispatch Time
                  </label>
                  <input
                    type="time"
                    value={reminderTime}
                    onChange={(e) => handleChangeReminderTime(e.target.value)}
                    onBlur={handleTimeBlur}
                    className="w-full p-3 bg-[#0A0A14]/70 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white focus:outline-none focus:ring-1 focus:ring-accent-teal/20 transition-all"
                  />
                </motion.div>
              )}
            </AnimatePresence>

            {/* Theme Mode Segmented Selector */}
            <div className="space-y-3">
              <div className="space-y-1">
                <span className="text-xs font-semibold text-gray-200 flex items-center gap-1.5">
                  <User className="w-3.5 h-3.5 text-accent-teal" />
                  Synced App Theme Mode
                </span>
                <span className="text-[10px] text-muted block leading-tight">
                  Synchronize active theme (dark/light) across all your devices.
                </span>
              </div>
              <div className="grid grid-cols-2 gap-2 bg-[#0A0A14]/60 p-1.5 rounded-xl border border-white/[0.02]">
                {["dark", "light"].map((mode) => {
                  const isSelected = themeMode === mode;
                  return (
                    <button
                      key={mode}
                      onClick={() => handleChangeThemeMode(mode)}
                      className={`py-2 rounded-lg text-xs font-bold transition-all capitalize ${
                        isSelected
                          ? "bg-accent-teal/10 border border-accent-teal/30 text-accent-teal shadow-[0_0_8px_rgba(0,210,200,0.1)]"
                          : "bg-transparent text-muted hover:text-white border border-transparent"
                      }`}
                    >
                      {mode}
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Default Coping Technique Dropdown */}
            <div className="space-y-2">
              <div className="space-y-1">
                <span className="text-xs font-semibold text-gray-200 flex items-center gap-1.5">
                  <Award className="w-3.5 h-3.5 text-accent-teal" />
                  Default Coping Technique
                </span>
                <span className="text-[10px] text-muted block leading-tight">
                  Choose the starting focus for your guided relief sessions.
                </span>
              </div>
              <select
                value={defaultCopingTechnique}
                onChange={(e) => handleChangeCopingTechnique(e.target.value)}
                className="w-full p-3 bg-[#0A0A14]/70 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white focus:outline-none focus:ring-1 focus:ring-accent-teal/20 transition-all cursor-pointer"
              >
                <option value="Breathing" className="bg-[#12122A]">Breathing</option>
                <option value="Meditation" className="bg-[#12122A]">Meditation</option>
                <option value="Grounding" className="bg-[#12122A]">Grounding</option>
              </select>
            </div>

            {/* Privacy Mode Dropdown */}
            <div className="space-y-2">
              <div className="space-y-1">
                <span className="text-xs font-semibold text-gray-200 flex items-center gap-1.5">
                  <ShieldCheck className="w-3.5 h-3.5 text-accent-teal" />
                  Privacy Isolation Mode
                </span>
                <span className="text-[10px] text-muted block leading-tight">
                  Configure cryptography parameters and data sharing boundaries.
                </span>
              </div>
              <select
                value={privacyMode}
                onChange={(e) => handleChangePrivacyMode(e.target.value)}
                className="w-full p-3 bg-[#0A0A14]/70 border border-white/5 focus:border-accent-teal/50 rounded-xl text-xs text-white focus:outline-none focus:ring-1 focus:ring-accent-teal/20 transition-all cursor-pointer"
              >
                <option value="standard" className="bg-[#12122A]">Standard (HIPAA Compliant)</option>
                <option value="strict" className="bg-[#12122A]">Strict Isolation</option>
                <option value="anonymous" className="bg-[#12122A]">Complete Anonymity</option>
              </select>
            </div>

            {/* AI Privacy Controls */}
            <div className="space-y-4 pt-4 border-t border-white/[0.04]">
              <div className="space-y-1">
                <span className="text-xs font-semibold text-gray-200 flex items-center gap-1.5">
                  <Brain className="w-3.5 h-3.5 text-accent-teal" />
                  AI Privacy & Telemetry Policies
                </span>
                <span className="text-[10px] text-muted block leading-tight">
                  Opt-in to automated features. All text transmission to Gemini uses TLS encryption.
                </span>
              </div>

              <div className="space-y-4 mt-3">
                {/* Journal Tone & Sentiment Analysis */}
                <div className="flex items-center justify-between">
                  <div className="space-y-1 pr-4">
                    <span className="text-xs font-semibold text-gray-200 flex items-center gap-1.5">
                      <Cpu className="w-3.5 h-3.5 text-accent-teal" />
                      AI Journal Analysis
                    </span>
                    <span className="text-[10px] text-muted block leading-tight">
                      Analyze entries locally to detect emotional tone and mental health themes.
                    </span>
                  </div>
                  <button
                    onClick={() => updatePreferenceOnBackend({ aiJournalAnalysisEnabled: !aiJournalAnalysisEnabled })}
                    className={`w-12 h-6.5 rounded-full p-1 transition-all duration-300 shrink-0 ${
                      aiJournalAnalysisEnabled ? "bg-accent-teal shadow-[0_0_12px_rgba(0,210,200,0.3)]" : "bg-[#0A0A14] border border-white/5"
                    }`}
                  >
                    <div
                      className={`w-4.5 h-4.5 rounded-full transition-all duration-300 ${
                        aiJournalAnalysisEnabled ? "bg-background translate-x-5.5" : "bg-muted translate-x-0"
                      }`}
                    />
                  </button>
                </div>

                {/* AI Chat History */}
                <div className="flex items-center justify-between">
                  <div className="space-y-1 pr-4">
                    <span className="text-xs font-semibold text-gray-200 flex items-center gap-1.5">
                      <History className="w-3.5 h-3.5 text-accent-teal" />
                      Empathetic AI Chat History
                    </span>
                    <span className="text-[10px] text-muted block leading-tight">
                      Allow MindChat to save active context history to ensure multi-turn conversation flows.
                    </span>
                  </div>
                  <button
                    onClick={() => updatePreferenceOnBackend({ aiChatHistoryEnabled: !aiChatHistoryEnabled })}
                    className={`w-12 h-6.5 rounded-full p-1 transition-all duration-300 shrink-0 ${
                      aiChatHistoryEnabled ? "bg-accent-teal shadow-[0_0_12px_rgba(0,210,200,0.3)]" : "bg-[#0A0A14] border border-white/5"
                    }`}
                  >
                    <div
                      className={`w-4.5 h-4.5 rounded-full transition-all duration-300 ${
                        aiChatHistoryEnabled ? "bg-background translate-x-5.5" : "bg-muted translate-x-0"
                      }`}
                    />
                  </button>
                </div>

                {/* Share Notes with AI */}
                <div className="flex items-center justify-between">
                  <div className="space-y-1 pr-4">
                    <span className="text-xs font-semibold text-gray-200 flex items-center gap-1.5">
                      <EyeOff className="w-3.5 h-3.5 text-accent-teal" />
                      Transmit Note Contents to AI
                    </span>
                    <span className="text-[10px] text-muted block leading-tight">
                      Share journal note bodies to generate customized, high-precision mood reflections.
                    </span>
                  </div>
                  <button
                    onClick={() => updatePreferenceOnBackend({ shareNotesWithAi: !shareNotesWithAi })}
                    className={`w-12 h-6.5 rounded-full p-1 transition-all duration-300 shrink-0 ${
                      shareNotesWithAi ? "bg-accent-teal shadow-[0_0_12px_rgba(0,210,200,0.3)]" : "bg-[#0A0A14] border border-white/5"
                    }`}
                  >
                    <div
                      className={`w-4.5 h-4.5 rounded-full transition-all duration-300 ${
                        shareNotesWithAi ? "bg-background translate-x-5.5" : "bg-muted translate-x-0"
                      }`}
                    />
                  </button>
                </div>
              </div>
            </div>

            {/* Entries Per Page Segmented Selector */}
            <div className="space-y-3">
              <div className="space-y-1">
                <span className="text-xs font-semibold text-gray-200 flex items-center gap-1.5">
                  <ListFilter className="w-3.5 h-3.5 text-accent-teal" />
                  Journal Entries Per Page
                </span>
                <span className="text-[10px] text-muted block leading-tight">
                  Choose the standard timeline length loaded during scroll sessions.
                </span>
              </div>
              <div className="grid grid-cols-3 gap-2 bg-[#0A0A14]/60 p-1.5 rounded-xl border border-white/[0.02]">
                {[10, 20, 50].map((num) => {
                  const isSelected = entriesPerPage === num;
                  return (
                    <button
                      key={num}
                      onClick={() => handleChangeEntriesPerPage(num)}
                      className={`py-2 rounded-lg text-xs font-bold transition-all ${
                        isSelected
                          ? "bg-accent-teal/10 border border-accent-teal/30 text-accent-teal shadow-[0_0_8px_rgba(0,210,200,0.1)]"
                          : "bg-transparent text-muted hover:text-white border border-transparent"
                      }`}
                    >
                      {num}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </motion.div>

        {/* 3. About Section Card */}
        <motion.div
          variants={itemVariants}
          className="p-6 md:p-8 rounded-3xl bg-[#12122A] border border-white/[0.04] space-y-6 hover:border-white/[0.08] transition-all flex flex-col justify-between"
        >
          <div className="space-y-5">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-accent-teal/10 flex items-center justify-center text-accent-teal">
                <Info className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-lg font-bold font-display text-white">About MindTrack</h3>
                <p className="text-[10px] text-muted">Project objectives, taxonomy parameters, and open-source links.</p>
              </div>
            </div>

            <div className="border-t border-white/[0.04] pt-4 space-y-4">
              {/* SDG 3 Badge */}
              <div className="flex items-center justify-between bg-[#0A0A14]/40 p-4 rounded-2xl border border-white/[0.02]">
                <div className="space-y-0.5">
                  <span className="text-[10px] font-bold text-muted uppercase tracking-wider block">Global Objectives</span>
                  <span className="text-[11px] text-gray-300">United Nations Sustainability Focus</span>
                </div>
                <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 font-bold text-[10px] tracking-wider uppercase animate-pulse shadow-[0_0_12px_rgba(16,185,129,0.15)]">
                  <Award className="w-3.5 h-3.5" />
                  SDG 3 Badge
                </div>
              </div>

              {/* Version & present-me badge */}
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-4 bg-[#0A0A14]/20 border border-white/5 rounded-2xl">
                <div>
                  <span className="text-[10px] font-bold text-muted uppercase tracking-wider block">Application Build</span>
                  <span className="text-xs font-semibold text-gray-200">MindTrack v1.0.0</span>
                </div>
                <div>
                  <span className="text-[10px] font-bold text-muted uppercase tracking-wider block">Genesis Template</span>
                  <a
                    href="https://github.com/suthankan/mindtrack"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-[11px] font-semibold text-accent-teal hover:underline inline-flex items-center gap-1 hover:text-accent-teal/80 transition-all"
                  >
                    Generated with PresentMe
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </div>
              </div>
            </div>
          </div>

          <a
            href="https://github.com/suthankan/mindtrack"
            target="_blank"
            rel="noopener noreferrer"
            className="w-full inline-flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-white/[0.02] hover:bg-white/[0.06] border border-white/5 font-semibold text-xs text-gray-200 transition-all active:scale-[0.98] mt-4"
          >
            <GithubIcon className="w-4 h-4 text-accent-teal" />
            View on GitHub
          </a>
        </motion.div>

        {/* 4. Danger Zone Section Card */}
        <motion.div
          variants={itemVariants}
          className="p-6 md:p-8 rounded-3xl bg-[#12122A] border border-accent-coral/20 space-y-6 hover:border-accent-coral/30 hover:shadow-[0_0_24px_rgba(255,107,107,0.05)] transition-all flex flex-col justify-between"
        >
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-accent-coral/10 flex items-center justify-center text-accent-coral">
                <AlertOctagon className="w-5 h-5 animate-pulse" />
              </div>
              <div>
                <h3 className="text-lg font-bold font-display text-accent-coral">Danger Zone</h3>
                <p className="text-[10px] text-accent-coral/60">Destructive policies and immediate database wipes.</p>
              </div>
            </div>

            <div className="border-t border-accent-coral/10 pt-4 space-y-4">
              <p className="text-xs text-gray-400 leading-relaxed">
                Clearing your database records deletes all logs, notes, streak parameters, and custom reminders permanently. 
                This action is cryptographic, destructive, and cannot be undone under HIPAA privacy guidelines.
              </p>
            </div>
          </div>

          {/* Clear All Data Dialog Confirmation */}
          <Dialog.Root open={isClearDialogOpen} onOpenChange={setIsClearDialogOpen}>
            <Dialog.Trigger asChild>
              <button className="w-full inline-flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-accent-coral/10 hover:bg-accent-coral/20 border border-accent-coral/30 font-semibold text-xs text-accent-coral transition-all active:scale-[0.98] mt-4 shadow-[0_0_12px_rgba(255,107,107,0.05)]">
                <AlertOctagon className="w-4 h-4" />
                Clear All Data
              </button>
            </Dialog.Trigger>

            <Dialog.Portal>
              <Dialog.Overlay className="fixed inset-0 bg-[#0A0A14]/80 backdrop-blur-md z-50 animate-fade-in" />
              <Dialog.Content className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 glass-elevated border border-accent-coral/30 rounded-3xl p-6 md:p-8 max-w-md w-[92vw] z-50 shadow-2xl space-y-6">
                <div className="flex items-center justify-between">
                  <Dialog.Title className="text-xl font-bold font-display text-accent-coral flex items-center gap-2">
                    <AlertOctagon className="w-5 h-5 animate-pulse text-accent-coral" />
                    Destructive Action Request
                  </Dialog.Title>
                  <Dialog.Close asChild>
                    <button className="p-1.5 rounded-lg bg-white/[0.03] hover:bg-white/[0.08] text-muted hover:text-white transition-all">
                      <X className="w-4 h-4" />
                    </button>
                  </Dialog.Close>
                </div>

                <Dialog.Description className="text-xs text-gray-300 leading-relaxed space-y-3">
                  <p>
                    Are you absolutely sure you wish to wipe the emotional universe profile? This will immediately sever data indexes.
                  </p>
                  <div className="p-3 bg-accent-coral/10 border border-accent-coral/20 rounded-xl text-[11px] text-accent-coral font-semibold">
                    ⚠️ Wiped configurations cannot be recovered.
                  </div>
                </Dialog.Description>

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
                    onClick={handleConfirmClearData}
                    className="flex-1 py-3 rounded-xl bg-accent-coral text-white font-bold text-xs uppercase tracking-wider hover:opacity-90 active:scale-[0.98] transition-all shadow-[0_0_12px_rgba(255,107,107,0.2)]"
                  >
                    Confirm Destructive Wipe
                  </button>
                </div>
              </Dialog.Content>
            </Dialog.Portal>
          </Dialog.Root>
        </motion.div>
      </motion.div>

      <div className="flex items-center gap-2 text-[10px] text-muted bg-white/[0.02] border border-white/5 px-4 py-2.5 rounded-2xl max-w-max mx-auto mt-8">
        <ShieldCheck className="w-3.5 h-3.5 text-accent-teal" />
        Data is processed locally and backed up under compliant security guidelines.
      </div>
    </div>
  );
}
