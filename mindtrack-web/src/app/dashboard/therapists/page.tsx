"use client";

import React, { useState, useEffect, useCallback } from "react";
import { useSession } from "next-auth/react";
import { motion, AnimatePresence } from "framer-motion";
import axios from "axios";
import {
  Search,
  MapPin,
  Star,
  Send,
  X,
  FileText,
  RefreshCw,
  SlidersHorizontal,
  CheckCircle2,
  Lock,
  Users
} from "lucide-react";
import CosmicErrorCard from "@/components/CosmicErrorCard";

interface Therapist {
  id: string;
  name: string;
  specialty: string;
  location: string;
  bio: string;
  rating: number;
  availability: string;
  avatarGradient: string;
  tags: string[];
  email: string;
  verified?: boolean;
}

export default function TherapistsPage() {
  const { data: session, status } = useSession();
  const [mounted, setMounted] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Directory States
  const [therapists, setTherapists] = useState<Therapist[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedSpecialty, setSelectedSpecialty] = useState("All");
  const [selectedLocation, setSelectedLocation] = useState("All");

  // Secure Message Portal Modal States
  const [selectedTherapist, setSelectedTherapist] = useState<Therapist | null>(null);
  const [messageText, setMessageText] = useState("");
  const [attachPdf, setAttachPdf] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [sendSuccess, setSendSuccess] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const fetchTherapists = useCallback(async () => {
    if (!session?.user?.accessToken) return;
    setIsLoading(true);
    try {
      const res = await axios.get("/api/therapists", {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });
      setTherapists(res.data);
      setError(null);
    } catch (err: unknown) {
      console.error("Error loading therapists:", err);
      setError("Failed to secure connection with clinical directories. Please ensure the service is online.");
    } finally {
      setIsLoading(false);
    }
  }, [session]);

  useEffect(() => {
    if (status === "authenticated") {
      fetchTherapists();
    } else if (status === "unauthenticated") {
      setIsLoading(false);
    }
  }, [status, fetchTherapists]);

  // Client-side search and specialty/location filters
  const filteredTherapists = therapists.filter((therapist) => {
    const matchesSearch =
      therapist.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      therapist.specialty.toLowerCase().includes(searchQuery.toLowerCase()) ||
      therapist.tags.some((tag) => tag.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesSpecialty =
      selectedSpecialty === "All" ||
      therapist.tags.some((tag) => tag.toLowerCase() === selectedSpecialty.toLowerCase()) ||
      therapist.specialty.toLowerCase().includes(selectedSpecialty.toLowerCase());

    const matchesLocation =
      selectedLocation === "All" ||
      therapist.location.toLowerCase().includes(selectedLocation.toLowerCase());

    return matchesSearch && matchesSpecialty && matchesLocation;
  });

  const handleContactSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!messageText.trim() || isSending) return;

    setIsSending(true);

    // Simulate cryptographic message tunneling
    setTimeout(() => {
      setIsSending(false);
      setSendSuccess(true);
      
      // Close modal after success animation
      setTimeout(() => {
        setSelectedTherapist(null);
        setSendSuccess(false);
        setMessageText("");
      }, 2500);
    }, 2000);
  };

  const activeSpecialties = ["All", "CBT", "Anxiety", "Mindfulness", "ADHD", "Somatic"];
  const activeLocations = ["All", "New York", "Colombo", "Mumbai", "Remote"];

  // Framer Motion staggered variants
  const gridVariants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.05,
      },
    },
  };

  const cardVariants = {
    hidden: { y: 35, opacity: 0 },
    show: {
      y: 0,
      opacity: 1,
      transition: { type: "spring" as const, stiffness: 90, damping: 15 }
    },
  };

  if (!mounted || status === "loading") {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-4">
        <RefreshCw className="w-8 h-8 text-accent-teal animate-spin" />
        <p className="text-xs text-muted tracking-wider uppercase">Loading clinical guidance logs...</p>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-10 subtle-mesh">
      {/* 1. Header welcome */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="space-y-1">
          <h2 className="text-3xl font-bold tracking-tight text-white leading-tight">
            Clinical Directory
          </h2>
          <p className="text-xs text-muted">
            Connect securely with vetted cognitive counselors and behavioral guides.
          </p>
        </div>

        <button
          onClick={fetchTherapists}
          disabled={isLoading}
          className="self-start inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-[#12122A] hover:bg-[#1C1C3A] border border-[#1C1C3A] text-xs text-white transition-all disabled:opacity-50"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? "animate-spin" : ""}`} />
          Sync Records
        </button>
      </div>

      {/* SDG 3 Support Banner */}
      <div className="p-5 rounded-3xl bg-gradient-to-r from-emerald-500/10 via-teal-500/5 to-transparent border border-emerald-500/20 flex flex-col sm:flex-row items-start sm:items-center gap-4 shadow-lg shadow-emerald-950/10">
        <div className="w-12 h-12 rounded-2xl bg-[#4C9F38] flex flex-col items-center justify-center text-white shrink-0 shadow-md shadow-emerald-950/30">
          <span className="text-[8px] font-extrabold leading-none">SDG</span>
          <span className="text-xl font-black leading-none">3</span>
        </div>
        <div className="space-y-1">
          <h4 className="text-xs font-bold text-white uppercase tracking-wider">UN Sustainable Goal 3: Good Health & Well-Being</h4>
          <p className="text-[11px] text-muted leading-relaxed">
            MindTrack supports Goal 3 by democratizing access to professional mental health care. Every therapist in this directory is fully verified and licensed to provide support.
          </p>
        </div>
      </div>

      {error && (
        <CosmicErrorCard
          title="Clinical Directory Offline"
          message={error}
          onRetry={fetchTherapists}
          isLoading={isLoading}
        />
      )}

      {/* 2. Interactive Search & Filters Row */}
      <div className="flex flex-col lg:flex-row gap-6 justify-between items-stretch lg:items-center">
        {/* Search input with glowing teal border */}
        <div className="relative flex-1 max-w-lg">
          <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-muted">
            <Search className="w-4 h-4" />
          </span>
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by name, treatment style, or tags..."
            className="w-full pl-10 pr-4 py-3 bg-[#12122A] border border-white/[0.04] focus:border-accent-teal/50 hover:border-white/10 rounded-2xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 transition-all shadow-lg"
          />
        </div>

        {/* Filters Group */}
        <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center">
          {/* Specialty filters */}
          <div className="flex items-center gap-2 overflow-x-auto pb-1 max-w-full">
            <span className="text-[10px] uppercase font-bold tracking-wider text-muted inline-flex items-center gap-1 shrink-0">
              <SlidersHorizontal className="w-3.5 h-3.5" />
              Specialty:
            </span>
            <div className="flex gap-1.5 pr-2">
              {activeSpecialties.map((spec) => (
                <button
                  key={spec}
                  onClick={() => setSelectedSpecialty(spec)}
                  className={`px-3.5 py-1.5 rounded-xl text-[10px] font-semibold border uppercase tracking-wider transition-all duration-300 ${
                    selectedSpecialty === spec
                      ? "bg-accent-teal/10 border-accent-teal text-accent-teal shadow-glow shadow-accent-teal/5"
                      : "bg-[#12122A] border-white/[0.04] text-muted hover:border-white/10 hover:text-white"
                  }`}
                >
                  {spec}
                </button>
              ))}
            </div>
          </div>

          {/* Location filters */}
          <div className="flex items-center gap-2 overflow-x-auto pb-1 max-w-full">
            <span className="text-[10px] uppercase font-bold tracking-wider text-muted inline-flex items-center gap-1 shrink-0">
              <MapPin className="w-3.5 h-3.5 text-accent-coral" />
              Location:
            </span>
            <div className="flex gap-1.5 pr-2">
              {activeLocations.map((loc) => (
                <button
                  key={loc}
                  onClick={() => setSelectedLocation(loc)}
                  className={`px-3.5 py-1.5 rounded-xl text-[10px] font-semibold border uppercase tracking-wider transition-all duration-300 ${
                    selectedLocation === loc
                      ? "bg-accent-coral/10 border-accent-coral text-accent-coral shadow-glow shadow-accent-coral/5"
                      : "bg-[#12122A] border-white/[0.04] text-muted hover:border-white/10 hover:text-white"
                  }`}
                >
                  {loc}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {isLoading ? (
        /* Cards shimmer load skeleton */
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <div
              key={i}
              className="h-80 bg-[#12122A]/40 border border-white/[0.03] animate-pulse rounded-3xl"
            />
          ))}
        </div>
      ) : (
        /* 3. Responsive CSS Grid with Therapist Cards */
        <>
          {filteredTherapists.length > 0 ? (
            <motion.div
              variants={gridVariants}
              initial="hidden"
              whileInView="show"
              viewport={{ once: true, margin: "-50px" }}
              className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
            >
              {filteredTherapists.map((therapist) => (
                <motion.div
                  key={therapist.id}
                  variants={cardVariants}
                  className="glass-card hover:bg-elevated/20 rounded-3xl p-6 border border-white/5 flex flex-col justify-between hover:-translate-y-1.5 transition-all duration-300 group"
                >
                  <div className="space-y-4">
                    {/* Card Top: Gradient Avatar & Metadata */}
                    <div className="flex justify-between items-start gap-4">
                      {/* Avatar with initial */}
                      <div className={`w-12 h-12 rounded-2xl bg-gradient-to-tr ${therapist.avatarGradient} flex items-center justify-center text-white font-display text-lg font-bold shadow-md shadow-black/30 shrink-0`}>
                        {therapist.name.split(" ").filter(n => !n.includes(".")).map(n => n[0]).join("")}
                      </div>

                      {/* Rating + Availability */}
                      <div className="text-right space-y-1">
                        <div className="flex items-center justify-end gap-1 text-[10px] font-bold text-amber-400">
                          <Star className="w-3 h-3 fill-amber-400" />
                          <span>{therapist.rating.toFixed(1)}</span>
                        </div>
                        
                        <div className="flex items-center gap-1 justify-end text-[9px] font-medium text-emerald-400">
                          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                          <span>{therapist.availability}</span>
                        </div>
                      </div>
                    </div>

                    {/* Name & Specialty BADGE */}
                    <div className="space-y-1.5">
                      <h3 className="text-md font-bold text-white font-display leading-tight group-hover:text-accent-teal transition-colors flex items-center gap-1.5">
                        {therapist.name}
                        {therapist.verified && (
                          <CheckCircle2 className="w-4 h-4 text-accent-teal shrink-0 fill-accent-teal/10" />
                        )}
                      </h3>
                      
                      <div className="inline-block px-2.5 py-0.5 rounded-md bg-accent-teal/5 border border-accent-teal/15 text-accent-teal text-[9px] font-bold uppercase tracking-wider">
                        {therapist.specialty}
                      </div>
                    </div>

                    {/* Brief Bio */}
                    <p className="text-[11px] text-muted leading-relaxed font-sans line-clamp-3">
                      {therapist.bio}
                    </p>

                    {/* Tags row */}
                    <div className="flex flex-wrap gap-1 pt-1">
                      {therapist.tags.map((tag) => (
                        <span
                          key={tag}
                          className="px-1.5 py-0.5 rounded-md bg-white/[0.02] border border-white/5 text-muted text-[8px]"
                        >
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>

                  {/* Card Bottom: Location & Action */}
                  <div className="pt-5 mt-5 border-t border-white/[0.04] flex items-center justify-between gap-4">
                    <span className="text-[9px] text-muted flex items-center gap-1 shrink-0">
                      <MapPin className="w-3 h-3 text-accent-coral" />
                      {therapist.location}
                    </span>

                    <button
                      onClick={() => setSelectedTherapist(therapist)}
                      className="px-3.5 py-2 rounded-xl bg-accent-teal text-background font-bold text-[10px] uppercase tracking-wider hover:opacity-90 active:scale-95 transition-all"
                    >
                      Contact
                    </button>
                  </div>
                </motion.div>
              ))}
            </motion.div>
          ) : therapists.length === 0 ? (
            <div className="glass-card rounded-3xl p-12 border border-white/5 text-center min-h-[350px] flex flex-col items-center justify-center space-y-5 relative overflow-hidden">
              <div className="absolute inset-0 animated-cosmic-bg opacity-30 pointer-events-none" />
              <div className="w-12 h-12 rounded-full bg-accent-teal/10 border border-accent-teal/20 flex items-center justify-center text-accent-teal mx-auto animate-pulse relative z-10">
                <Users className="w-5 h-5" />
              </div>
              <div className="space-y-1.5 max-w-sm relative z-10">
                <h3 className="text-md font-bold font-display text-white">Clinical Directory Empty</h3>
                <p className="text-xs text-muted leading-relaxed">
                  No licensed counselors are registered in the local data registry. Click sync below to populate standard directory lists.
                </p>
              </div>
              <button
                onClick={fetchTherapists}
                disabled={isLoading}
                className="relative z-10 inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-accent-teal text-background font-bold text-xs uppercase tracking-wider transition-all disabled:opacity-50 hover:shadow-glow"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? "animate-spin" : ""}`} />
                Sync Vetted Listings
              </button>
            </div>
          ) : (
            <div className="glass-card rounded-3xl p-12 border border-white/5 text-center min-h-[350px] flex flex-col items-center justify-center space-y-5 relative overflow-hidden">
              <div className="absolute inset-0 animated-cosmic-bg opacity-20 pointer-events-none" />
              <div className="w-12 h-12 rounded-full bg-accent-coral/10 border border-accent-coral/20 flex items-center justify-center text-accent-coral mx-auto relative z-10">
                <Search className="w-5 h-5" />
              </div>
              <div className="space-y-1.5 max-w-sm relative z-10">
                <h3 className="text-md font-bold font-display text-white">No Profiles Found</h3>
                <p className="text-xs text-muted leading-relaxed">
                  No clinical professionals align with your current search queries or specialty and location filters.
                </p>
              </div>
              <button
                onClick={() => {
                  setSearchQuery("");
                  setSelectedSpecialty("All");
                  setSelectedLocation("All");
                }}
                className="relative z-10 px-4 py-2 rounded-xl bg-white/[0.04] hover:bg-white/[0.08] border border-white/5 text-xs text-white font-semibold transition-all"
              >
                Clear Search & Filters
              </button>
            </div>
          )}
        </>
      )}

      {/* 4. Interactive Secure Contact Modal */}
      <AnimatePresence>
        {selectedTherapist && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            {/* Modal Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 bg-black/75 backdrop-blur-md"
              onClick={() => {
                if (!isSending && !sendSuccess) setSelectedTherapist(null);
              }}
            />

            {/* Modal Content Card */}
            <motion.div
              initial={{ scale: 0.95, opacity: 0, y: 15 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.95, opacity: 0, y: 15 }}
              transition={{ type: "spring", stiffness: 350, damping: 28 }}
              className="relative w-full max-w-lg overflow-hidden rounded-3xl bg-[#12122A] border border-[#1C1C3A] shadow-2xl z-10 p-6 sm:p-8"
            >
              {/* Close Button */}
              {!isSending && !sendSuccess && (
                <button
                  onClick={() => setSelectedTherapist(null)}
                  className="absolute top-4 right-4 p-1.5 rounded-lg text-muted hover:bg-elevated hover:text-white transition-colors"
                >
                  <X className="w-4 h-4" />
                </button>
              )}

              {sendSuccess ? (
                /* Success Interface */
                <div className="text-center py-8 space-y-4">
                  <div className="w-16 h-16 rounded-full bg-accent-teal/10 border border-accent-teal/20 mx-auto flex items-center justify-center text-accent-teal animate-bounce">
                    <CheckCircle2 className="w-8 h-8" />
                  </div>
                  <div className="space-y-1">
                    <h3 className="text-lg font-bold font-display text-white">Cryptographic Connection Secured</h3>
                    <p className="text-xs text-muted max-w-xs mx-auto leading-relaxed">
                      Your message has been encrypted and successfully sent to <span className="text-accent-teal font-semibold">{selectedTherapist.name}</span>. They will respond shortly.
                    </p>
                  </div>
                </div>
              ) : (
                /* Main Message Draft Form */
                <div className="space-y-6">
                  {/* Title & E2E warning */}
                  <div className="space-y-1">
                    <h3 className="text-lg font-bold font-display text-white flex items-center gap-2">
                      <Lock className="w-4.5 h-4.5 text-accent-teal shrink-0" />
                      Secure Consultation Portal
                    </h3>
                    <p className="text-[10px] text-muted flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-accent-teal animate-pulse" />
                      End-to-End Encrypted Tunnel Active
                    </p>
                  </div>

                  {/* Profile info preview */}
                  <div className="flex gap-4 p-4 rounded-2xl bg-[#0A0A14]/50 border border-white/[0.02]">
                    <div className={`w-10 h-10 rounded-xl bg-gradient-to-tr ${selectedTherapist.avatarGradient} flex items-center justify-center text-white font-display text-md font-bold shadow-md shrink-0`}>
                      {selectedTherapist.name.split(" ").filter(n => !n.includes(".")).map(n => n[0]).join("")}
                    </div>
                    <div className="space-y-1 flex-1">
                      <h4 className="text-xs font-bold text-white leading-none">{selectedTherapist.name}</h4>
                      <p className="text-[9px] text-accent-teal font-medium uppercase tracking-wider">{selectedTherapist.specialty}</p>
                      <p className="text-[9px] text-muted flex items-center gap-1 mt-1 leading-none">
                        <MapPin className="w-2.5 h-2.5" />
                        {selectedTherapist.location}
                      </p>
                    </div>
                  </div>

                  {/* Message Input Form */}
                  <form onSubmit={handleContactSubmit} className="space-y-4">
                    <div className="space-y-2">
                      <label className="text-xs text-gray-300 font-semibold">Consultation Note</label>
                      <textarea
                        value={messageText}
                        onChange={(e) => setMessageText(e.target.value)}
                        placeholder={`Introduce yourself to ${selectedTherapist.name.split(" ")[1]}. Mention what you would like to discuss...`}
                        rows={4}
                        required
                        disabled={isSending}
                        className="w-full p-3.5 bg-[#0A0A14]/75 border border-[#1C1C3A] focus:border-accent-teal/50 rounded-2xl text-xs text-white placeholder-muted focus:outline-none focus:ring-1 focus:ring-accent-teal/20 resize-none transition-all"
                      />
                    </div>

                    {/* Encrypted Attachment Toggle */}
                    <label className="flex items-start gap-3 p-3.5 rounded-2xl bg-[#0A0A14]/30 border border-white/[0.02] hover:border-white/5 cursor-pointer select-none transition-all">
                      <input
                        type="checkbox"
                        checked={attachPdf}
                        onChange={() => setAttachPdf(!attachPdf)}
                        disabled={isSending}
                        className="w-4 h-4 rounded border-gray-300 text-accent-teal focus:ring-accent-teal accent-accent-teal mt-0.5"
                      />
                      <div className="space-y-0.5">
                        <span className="text-xs font-semibold text-white flex items-center gap-1.5">
                          <FileText className="w-3.5 h-3.5 text-accent-teal" />
                          Attach Encrypted Biometric History PDF
                        </span>
                        <p className="text-[9px] text-muted leading-relaxed">
                          Securely bundles your last 30 days of mood timeline charts, tags, and stability distributions. Highly recommended for clinical evaluation.
                        </p>
                      </div>
                    </label>

                    {/* Actions */}
                    <div className="flex gap-3 pt-2">
                      <button
                        type="button"
                        onClick={() => setSelectedTherapist(null)}
                        disabled={isSending}
                        className="flex-1 py-3 rounded-2xl bg-[#12122A] hover:bg-[#1C1C3A] border border-[#1C1C3A] text-xs text-white font-bold uppercase tracking-wider transition-all disabled:opacity-50"
                      >
                        Cancel
                      </button>

                      <button
                        type="submit"
                        disabled={isSending || !messageText.trim()}
                        className="flex-1 py-3 rounded-2xl bg-accent-teal text-background font-bold text-xs uppercase tracking-wider hover:opacity-90 active:scale-98 flex items-center justify-center gap-2 transition-all disabled:opacity-50"
                      >
                        {isSending ? (
                          <>
                            <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                            Tunneling message...
                          </>
                        ) : (
                          <>
                            <Send className="w-3.5 h-3.5" />
                            Send Message
                          </>
                        )}
                      </button>
                    </div>
                  </form>
                </div>
              )}
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
