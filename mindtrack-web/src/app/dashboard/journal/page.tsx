import React from "react";
import { BookOpen, AlertCircle } from "lucide-react";

export default function JournalPage() {
  return (
    <div className="glass-card rounded-3xl p-8 lg:p-12 border border-white/5 text-center min-h-[400px] flex flex-col items-center justify-center space-y-4">
      <div className="w-12 h-12 rounded-xl bg-accent-coral/10 flex items-center justify-center text-accent-coral">
        <BookOpen className="w-6 h-6" />
      </div>
      <h3 className="text-xl font-bold font-display text-white">Digital Mood Journal</h3>
      <p className="text-xs text-muted max-w-sm leading-relaxed">
        This section lists your full personal logs, sentiment analytics, and reflection drafts. Write daily to cultivate mindfulness.
      </p>
      
      <div className="flex items-center gap-2 text-[10px] text-muted bg-white/[0.02] border border-white/5 px-3 py-1.5 rounded-lg mt-4">
        <AlertCircle className="w-3.5 h-3.5 text-accent-teal" />
        Logs are encrypted using end-to-end security protocols.
      </div>
    </div>
  );
}
