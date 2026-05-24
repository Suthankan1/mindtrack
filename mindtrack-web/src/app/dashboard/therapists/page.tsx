import React from "react";
import { Users, HeartHandshake } from "lucide-react";

export default function TherapistsPage() {
  return (
    <div className="glass-card rounded-3xl p-8 lg:p-12 border border-white/5 text-center min-h-[400px] flex flex-col items-center justify-center space-y-4">
      <div className="w-12 h-12 rounded-xl bg-indigo-500/10 flex items-center justify-center text-indigo-400">
        <Users className="w-6 h-6" />
      </div>
      <h3 className="text-xl font-bold font-display text-white">Clinical Guidance & Therapists</h3>
      <p className="text-xs text-muted max-w-sm leading-relaxed">
        Connect your logged insights seamlessly with certified psychiatrists, behavioral counselors, and emotional guides. Send them encrypted PDF summaries of your monthly trends.
      </p>
      
      <div className="flex items-center gap-2 text-[10px] text-muted bg-white/[0.02] border border-white/5 px-3 py-1.5 rounded-lg mt-4">
        <HeartHandshake className="w-3.5 h-3.5 text-accent-coral animate-pulse" />
        Clinical sharing is disabled by default. You are in full control.
      </div>
    </div>
  );
}
