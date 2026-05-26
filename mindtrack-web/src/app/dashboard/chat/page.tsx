"use client";

import React, { useEffect, useRef, useState } from "react";
import { useSession } from "next-auth/react";
import axios from "axios";
import { Bot, ChevronRight, Send, Sparkles, User2 } from "lucide-react";

type ChatRole = "user" | "assistant";

interface ChatMessage {
  id: string;
  role: ChatRole;
  text: string;
  suggestedFollowUps?: string[];
}

interface ChatResponse {
  reply?: string;
  suggestedFollowUps?: string[];
  aiAvailable?: boolean;
  showCrisisResources?: boolean;
}

interface UserStatsResponse {
  avgMoodScoreThisWeek?: number;
  avgMoodScore?: number;
}

const formatAverage = (value: number) => {
  const rounded = value.toFixed(1);
  return rounded.endsWith(".0") ? rounded.slice(0, -2) : rounded;
};

export default function MindChatPage() {
  const { data: session, status } = useSession();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [isBootstrapping, setIsBootstrapping] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [weeklyAverage, setWeeklyAverage] = useState(3.0);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const initialisedRef = useRef(false);
  const storageKey = "mindchat_web_history";

  const appendAssistantGreeting = (weeklyAverage: number) => {
    setMessages([
      {
        id: "welcome",
        role: "assistant",
        text: `Hi! Your weekly average is ${formatAverage(weeklyAverage)}/5. How are you really doing?`,
        suggestedFollowUps: [],
      },
    ]);
  };

  useEffect(() => {
    if (status === "unauthenticated") {
      setMessages([
        {
          id: "guest",
          role: "assistant",
          text: "Please sign in to use MindChat.",
          suggestedFollowUps: [],
        },
      ]);
      setIsBootstrapping(false);
      return;
    }

    if (status !== "authenticated" || initialisedRef.current) {
      return;
    }

    initialisedRef.current = true;

    const loadStats = async () => {
      try {
        const response = await axios.get<UserStatsResponse>("/api/user/stats", {
          headers: {
            Authorization: `Bearer ${session?.user?.accessToken}`,
          },
        });

        const loadedWeeklyAverage = response.data.avgMoodScoreThisWeek ?? response.data.avgMoodScore ?? 3;
        setWeeklyAverage(loadedWeeklyAverage);
        appendAssistantGreeting(loadedWeeklyAverage);
      } catch (statsError) {
        console.error("Error loading user stats for MindChat:", statsError);
        setWeeklyAverage(3.0);
        appendAssistantGreeting(3);
      } finally {
        setIsBootstrapping(false);
      }
    };

    void loadStats();
  }, [status, session]);

  useEffect(() => {
    if (isBootstrapping || status !== "authenticated") {
      return;
    }

    try {
      const saved = sessionStorage.getItem(storageKey);
      if (saved) {
        setMessages(JSON.parse(saved));
      }
    } catch (storageError) {
      console.error("Error restoring MindChat session:", storageError);
    }
  }, [isBootstrapping, status]);

  useEffect(() => {
    if (isBootstrapping || status !== "authenticated") {
      return;
    }

    try {
      sessionStorage.setItem(storageKey, JSON.stringify(messages));
    } catch (storageError) {
      console.error("Error saving MindChat session:", storageError);
    }
  }, [messages, isBootstrapping, status]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages, isSending]);

  const handleClearChat = () => {
    try {
      sessionStorage.removeItem(storageKey);
    } catch (storageError) {
      console.error("Error clearing MindChat session:", storageError);
    }

    appendAssistantGreeting(weeklyAverage);
  };

  const sendMessage = async (text: string) => {
    const trimmed = text.trim();
    if (!trimmed || isSending) {
      return;
    }

    if (!session?.user?.accessToken) {
      setError("You need to sign in to use MindChat.");
      return;
    }

    const nextMessages: ChatMessage[] = [
      ...messages,
      {
        id: `user-${Date.now()}`,
        role: "user",
        text: trimmed,
      },
    ];

    setMessages(nextMessages);
    setDraft("");
    setError(null);
    setIsSending(true);

    try {
      const conversationHistory = messages.slice(-8).map((message) => ({
        role: message.role,
        text: message.text,
      }));

      const response = await axios.post<ChatResponse>(
        "/api/ai/chat",
        {
          message: trimmed,
          conversationHistory,
          moodContext: {
            currentScore: undefined,
            weeklyAverage: weeklyAverage ?? 3.0,
          },
        },
        {
          headers: {
            Authorization: `Bearer ${session.user.accessToken}`,
          },
        }
      );

      const reply = response.data.reply?.trim() || "I'm here to listen. Tell me more.";
      const suggestedFollowUps = response.data.suggestedFollowUps ?? [];

      setMessages((currentMessages) => [
        ...currentMessages,
        {
          id: `assistant-${Date.now()}`,
          role: "assistant",
          text: reply,
          suggestedFollowUps,
        },
      ]);
    } catch (sendError) {
      console.error("Error sending MindChat message:", sendError);
      setError("MindChat could not reach the AI service right now.");
      setMessages((currentMessages) => [
        ...currentMessages,
        {
          id: `assistant-error-${Date.now()}`,
          role: "assistant",
          text: "I’m having trouble reaching the AI service right now. Please try again in a moment.",
          suggestedFollowUps: [],
        },
      ]);
    } finally {
      setIsSending(false);
    }
  };

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    await sendMessage(draft);
  };

  const handleSuggestionClick = async (suggestion: string) => {
    await sendMessage(suggestion);
  };

  const showTyping = isSending;

  return (
    <section className="relative flex min-h-[calc(100vh-8rem)] flex-col overflow-hidden rounded-[32px] border border-white/5 bg-[#0B1020]/90 shadow-[0_24px_80px_rgba(0,0,0,0.35)] backdrop-blur-xl">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(0,210,200,0.18),transparent_36%),radial-gradient(circle_at_top_right,rgba(66,133,244,0.16),transparent_30%),linear-gradient(180deg,rgba(255,255,255,0.02),transparent)]" />

      <header className="relative z-10 flex flex-wrap items-center justify-between gap-4 border-b border-white/5 px-5 py-5 md:px-7">
        <div className="space-y-2">
          <div className="flex items-center gap-3">
            <h1 className="font-display text-3xl font-bold tracking-tight text-white">MindChat</h1>
            <span className="inline-flex items-center rounded-full bg-gradient-to-r from-[#4285F4] via-[#5A95F5] to-[#1A73E8] px-3 py-1 text-[10px] font-bold uppercase tracking-[0.28em] text-white shadow-[0_10px_24px_rgba(26,115,232,0.24)]">
              Gemini
            </span>
          </div>
          <p className="max-w-2xl text-sm text-muted">
            Private, supportive conversations grounded in your weekly mood rhythm.
          </p>
        </div>

        <div className="flex items-center gap-2 rounded-2xl border border-[#4285F4]/20 bg-[#0E1730]/80 px-4 py-2 text-[10px] font-bold uppercase tracking-[0.24em] text-[#9FC0FF]">
          <Sparkles className="h-3.5 w-3.5 text-[#6EA8FF]" />
          Google Blue
        </div>

        <button
          type="button"
          onClick={handleClearChat}
          className="inline-flex items-center rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-2 text-[10px] font-bold uppercase tracking-[0.24em] text-white/80 transition-all duration-200 hover:border-white/20 hover:bg-white/[0.08]"
        >
          Clear Chat
        </button>
      </header>

      <div className="relative z-10 flex-1 overflow-y-auto px-4 py-5 md:px-7 md:py-7">
        {isBootstrapping ? (
          <div className="flex min-h-[40vh] items-center justify-center">
            <div className="rounded-[28px] border border-white/5 bg-white/[0.03] px-6 py-5 text-center text-sm text-muted shadow-lg">
              Syncing your weekly mood context...
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            {messages.map((message, index) => {
              const isUser = message.role === "user";
              const isLastAssistant = message.role === "assistant" && index === messages.length - 1;

              return (
                <div key={message.id} className={`flex ${isUser ? "justify-end" : "justify-start"}`}>
                  <div className={`max-w-[92%] md:max-w-[78%] ${isUser ? "order-2" : "order-1"}`}>
                    <div
                      className={`flex items-start gap-3 rounded-[24px] px-4 py-4 shadow-lg transition-all duration-300 ${
                        isUser
                          ? "bg-accent-teal/15 border border-accent-teal/20 text-white"
                          : "bg-surface/95 border border-white/5 border-l-4 border-l-[#4285F4] text-white"
                      }`}
                    >
                      <div
                        className={`mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-bold ${
                          isUser
                            ? "bg-accent-teal text-background"
                            : "bg-[#121B35] text-[#8AB4F8]"
                        }`}
                      >
                        {isUser ? <User2 className="h-4.5 w-4.5" /> : <Bot className="h-4.5 w-4.5" />}
                      </div>

                      <div className="min-w-0 flex-1 space-y-2">
                        <div className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-[0.22em] text-muted">
                          <span>{isUser ? "You" : "MindChat"}</span>
                        </div>
                        <p className="whitespace-pre-wrap text-sm leading-6 text-white/90">
                          {message.text}
                        </p>

                        {isLastAssistant && message.suggestedFollowUps && message.suggestedFollowUps.length > 0 && (
                          <div className="flex flex-wrap gap-2 pt-1">
                            {message.suggestedFollowUps.map((suggestion) => (
                              <button
                                key={suggestion}
                                type="button"
                                onClick={() => void handleSuggestionClick(suggestion)}
                                className="inline-flex items-center gap-1 rounded-full border border-[#4285F4]/20 bg-[#0E1730]/80 px-3 py-2 text-[10px] font-semibold text-[#C9D8FF] transition-all duration-200 hover:-translate-y-0.5 hover:border-[#4285F4]/40 hover:bg-[#14234A]"
                              >
                                {suggestion}
                                <ChevronRight className="h-3 w-3" />
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}

            {showTyping && (
              <div className="flex justify-start">
                <div className="max-w-[92%] md:max-w-[78%] rounded-[24px] border border-white/5 border-l-4 border-l-[#4285F4] bg-surface/95 px-4 py-4 shadow-lg">
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[#121B35] text-[#8AB4F8]">
                      <Bot className="h-4.5 w-4.5" />
                    </div>
                    <div className="typing-dots flex items-center gap-1.5">
                      <span className="typing-dot" />
                      <span className="typing-dot" />
                      <span className="typing-dot" />
                    </div>
                  </div>
                </div>
              </div>
            )}

            <div ref={bottomRef} />
          </div>
        )}
      </div>

      <form
        onSubmit={(event) => void handleSubmit(event)}
        className="relative z-10 border-t border-white/5 bg-[#0A0F1E]/95 px-4 py-4 md:px-7"
      >
        {error && (
          <div className="mb-3 rounded-2xl border border-accent-coral/20 bg-accent-coral/10 px-4 py-3 text-xs font-medium text-accent-coral">
            {error}
          </div>
        )}

        <div className="flex items-end gap-3 rounded-[28px] border border-white/5 bg-white/[0.03] p-3 shadow-[0_12px_36px_rgba(0,0,0,0.25)]">
          <textarea
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault();
                void handleSubmit(event as unknown as React.FormEvent<HTMLFormElement>);
              }
            }}
            placeholder="Talk to MindChat..."
            className="min-h-[52px] flex-1 resize-none bg-transparent px-2 py-3 text-sm text-white placeholder:text-muted focus:outline-none"
            rows={1}
            disabled={isSending || isBootstrapping}
          />

          <button
            type="submit"
            disabled={isSending || isBootstrapping || !draft.trim()}
            className="inline-flex h-12 items-center justify-center gap-2 rounded-2xl bg-gradient-to-r from-accent-teal to-accent-coral px-5 text-sm font-bold text-background transition-all duration-300 hover:opacity-95 disabled:cursor-not-allowed disabled:opacity-40"
          >
            <Send className="h-4 w-4" />
            Send
          </button>
        </div>
      </form>

      <style jsx global>{`
        @keyframes mindchat-dot-bounce {
          0%, 80%, 100% {
            transform: translateY(0);
            opacity: 0.45;
          }
          40% {
            transform: translateY(-5px);
            opacity: 1;
          }
        }

        .typing-dots .typing-dot {
          width: 8px;
          height: 8px;
          border-radius: 9999px;
          background: linear-gradient(135deg, #4285f4, #6ea8ff);
          animation: mindchat-dot-bounce 1s infinite ease-in-out;
        }

        .typing-dots .typing-dot:nth-child(2) {
          animation-delay: 0.15s;
        }

        .typing-dots .typing-dot:nth-child(3) {
          animation-delay: 0.3s;
        }
      `}</style>
    </section>
  );
}