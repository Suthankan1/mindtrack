"use client";

import React from "react";
import { useSession, signOut } from "next-auth/react";
import { Menu, LogOut, Bell, Calendar } from "lucide-react";
import { useUIStore } from "@/store/useStore";

export default function Navbar() {
  const { data: session } = useSession();
  const { toggleSidebar } = useUIStore();

  const getGreeting = () => {
    const hr = new Date().getHours();
    if (hr < 12) return "Good morning";
    if (hr < 17) return "Good afternoon";
    return "Good evening";
  };

  const getFormattedDate = () => {
    return new Date().toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
    });
  };

  return (
    <header className="sticky top-0 z-30 h-20 flex items-center justify-between px-6 lg:px-10 bg-background/50 backdrop-blur-md border-b border-white/5">
      {/* Left side: Hamburger (mobile) + Greeting */}
      <div className="flex items-center gap-4">
        <button
          className="p-2 rounded-xl text-muted hover:bg-elevated hover:text-white lg:hidden transition-colors"
          onClick={toggleSidebar}
        >
          <Menu className="w-5 h-5" />
        </button>

        <div className="hidden sm:flex flex-col">
          <h1 className="text-sm font-medium text-muted">
            {getGreeting()}, <span className="text-white font-semibold">{session?.user?.name || "Explorer"}</span>
          </h1>
          <p className="text-xs text-muted flex items-center gap-1.5 mt-0.5">
            <Calendar className="w-3.5 h-3.5 text-accent-teal" />
            {getFormattedDate()}
          </p>
        </div>
      </div>

      {/* Right side: Notifications, Session Profile, and Sign Out */}
      <div className="flex items-center gap-4 sm:gap-6">
        {/* Notifications Icon */}
        <button className="relative p-2.5 rounded-xl bg-surface hover:bg-elevated text-muted hover:text-white border border-white/5 transition-all">
          <Bell className="w-4 h-4" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-accent-coral animate-pulse" />
        </button>

        {/* Vertical Separator */}
        <div className="w-[1px] h-6 bg-white/10" />

        {/* Profile Card & Logout */}
        <div className="flex items-center gap-3">
          <div className="hidden md:flex flex-col text-right">
            <span className="text-sm font-semibold text-white">
              {session?.user?.name || "MindTracker"}
            </span>
            <span className="text-[10px] font-medium text-accent-teal uppercase tracking-wider">
              {session?.user?.email ? "Authenticated" : "Guest Mode"}
            </span>
          </div>

          {/* Logout Button */}
          <button
            onClick={() => signOut({ callbackUrl: "/login" })}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-surface border border-white/5 hover:border-accent-coral/30 hover:bg-accent-coral/5 text-muted hover:text-accent-coral font-medium text-xs transition-all duration-300"
            title="Sign Out"
          >
            <LogOut className="w-4 h-4" />
            <span className="hidden sm:inline">Sign Out</span>
          </button>
        </div>
      </div>
    </header>
  );
}
