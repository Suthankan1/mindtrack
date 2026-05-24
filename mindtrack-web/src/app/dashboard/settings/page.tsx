import React from "react";
import { Settings, ShieldCheck } from "lucide-react";

export default function SettingsPage() {
  return (
    <div className="glass-card rounded-3xl p-8 lg:p-12 border border-white/5 text-center min-h-[400px] flex flex-col items-center justify-center space-y-4">
      <div className="w-12 h-12 rounded-xl bg-amber-500/10 flex items-center justify-center text-amber-400">
        <Settings className="w-6 h-6" />
      </div>
      <h3 className="text-xl font-bold font-display text-white">System Settings</h3>
      <p className="text-xs text-muted max-w-sm leading-relaxed">
        Customize daily notification reminders, backup database profiles, modify credentials, and fine-tune behavioral model thresholds.
      </p>
      
      <div className="flex items-center gap-2 text-[10px] text-muted bg-white/[0.02] border border-white/5 px-3 py-1.5 rounded-lg mt-4">
        <ShieldCheck className="w-3.5 h-3.5 text-accent-teal" />
        Data is stored locally under compliant privacy guidelines.
      </div>
    </div>
  );
}
