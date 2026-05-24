"use client";

import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion } from "framer-motion";
import { 
  LayoutDashboard, 
  BookOpen, 
  Sparkles, 
  Users, 
  Settings, 
  X,
  BrainCircuit
} from "lucide-react";
import { useUIStore } from "@/store/useStore";

interface NavItem {
  name: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

const navItems: NavItem[] = [
  { name: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { name: "Journal", href: "/dashboard/journal", icon: BookOpen },
  { name: "Insights", href: "/dashboard/insights", icon: Sparkles },
  { name: "Therapists", href: "/dashboard/therapists", icon: Users },
  { name: "Settings", href: "/dashboard/settings", icon: Settings },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { isSidebarOpen, setSidebarOpen } = useUIStore();

  return (
    <>
      {/* Mobile Sidebar Backdrop */}
      {isSidebarOpen && (
        <div 
          className="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm lg:hidden transition-opacity duration-300"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar Container */}
      <aside 
        className={`fixed top-0 bottom-0 left-0 z-50 w-72 flex flex-col justify-between border-r border-white/5 bg-surface text-foreground transition-transform duration-300 ease-in-out lg:translate-x-0 ${
          isSidebarOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex flex-col h-full">
          {/* Sidebar Header */}
          <div className="h-20 flex items-center justify-between px-6 border-b border-white/5">
            <Link 
              href="/dashboard" 
              className="flex items-center gap-3 text-accent-teal hover:opacity-90 transition-opacity"
              onClick={() => setSidebarOpen(false)}
            >
              <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-accent-teal to-accent-coral p-[1px]">
                <div className="w-full h-full rounded-[11px] bg-surface flex items-center justify-center">
                  <BrainCircuit className="w-5 h-5 text-accent-teal" />
                </div>
              </div>
              <span className="font-display text-xl font-bold tracking-wide bg-gradient-to-r from-white via-white to-gray-400 bg-clip-text text-transparent">
                Mind<span className="text-accent-coral">Track</span>
              </span>
            </Link>
            
            {/* Mobile Close Button */}
            <button 
              className="p-1 rounded-lg text-muted hover:bg-elevated hover:text-white lg:hidden transition-colors"
              onClick={() => setSidebarOpen(false)}
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* Navigation Links */}
          <nav className="flex-1 px-4 py-6 space-y-2 overflow-y-auto">
            {navItems.map((item) => {
              const isActive = pathname === item.href;
              
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  onClick={() => setSidebarOpen(false)}
                  className={`group relative flex items-center gap-4 px-4 py-3.5 rounded-xl font-medium text-sm transition-all ${
                    isActive 
                      ? "text-accent-teal bg-white/[0.03]" 
                      : "text-muted hover:text-white hover:bg-white/[0.01]"
                  }`}
                >
                  {/* Left Active Line Indicator */}
                  {isActive && (
                    <motion.div 
                      layoutId="activeIndicator"
                      className="absolute left-0 w-[3px] h-3/5 rounded-r-full bg-accent-teal"
                      transition={{ type: "spring", stiffness: 380, damping: 30 }}
                    />
                  )}
                  
                  <item.icon className={`w-5 h-5 transition-transform group-hover:scale-110 duration-200 ${
                    isActive ? "text-accent-teal" : "text-muted group-hover:text-white"
                  }`} />
                  
                  <span className="relative z-10">{item.name}</span>

                  {/* Subtle hover glow card overlay */}
                  <span className="absolute inset-0 rounded-xl opacity-0 group-hover:opacity-100 bg-gradient-to-r from-accent-teal/5 to-transparent transition-opacity duration-300 pointer-events-none" />
                </Link>
              );
            })}
          </nav>
        </div>

        {/* Sidebar Footer */}
        <div className="p-6 border-t border-white/5 bg-background/30 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-full bg-elevated flex items-center justify-center text-sm font-semibold text-accent-coral ring-1 ring-white/10">
              MT
            </div>
            <div className="flex flex-col">
              <span className="text-xs font-semibold text-white">MindTrack Engine</span>
              <span className="text-[10px] text-muted">v1.0.0-Beta</span>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}
