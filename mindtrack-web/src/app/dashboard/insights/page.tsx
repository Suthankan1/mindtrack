import React from "react";
import { Sparkles, Brain } from "lucide-react";

export default function InsightsPage() {
  return (
    <div className="glass-card rounded-3xl p-8 lg:p-12 border border-white/5 text-center min-h-[400px] flex flex-col items-center justify-center space-y-4">
      <div className="w-12 h-12 rounded-xl bg-accent-teal/10 flex items-center justify-center text-accent-teal">
        <Sparkles className="w-6 h-6" />
      </div>
      <h3 className="text-xl font-bold font-display text-white">AI Pattern & Insights Engine</h3>
      <p className="text-xs text-muted max-w-sm leading-relaxed">
        Our proprietary cognitive mapping engine parses your logs to find correlations between activity, weather, sleep quality, and mood fluctuations.
      </p>
      
      <div className="flex items-center gap-2 text-[10px] text-muted bg-white/[0.02] border border-white/5 px-3 py-1.5 rounded-lg mt-4">
        <Brain className="w-3.5 h-3.5 text-accent-coral" />
        Analyze 5 or more days of entries to activate correlation models.
      </div>
    </div>
  );
}
