import React from "react";
import Sidebar from "@/components/Sidebar";
import Navbar from "@/components/Navbar";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-background">
      {/* Sidebar navigation */}
      <Sidebar />

      {/* Main content wrapper shifted on desktop */}
      <div className="lg:pl-72 flex flex-col min-h-screen">
        {/* Navigation & Header */}
        <Navbar />

        {/* Page body */}
        <main className="flex-1 p-6 lg:p-10 relative">
          {children}
        </main>
      </div>
    </div>
  );
}
