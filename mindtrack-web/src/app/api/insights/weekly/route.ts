import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

interface MoodEntry {
  moodScore: number;
  timestamp: string;
  tags?: string[];
}

const getMoodEmoji = (score: number) => {
  switch (score) {
    case 5: return "🌟";
    case 4: return "✨";
    case 3: return "😐";
    case 2: return "😞";
    case 1: return "🔥";
    default: return "😐";
  }
};

/**
 * GET /api/insights/weekly
 *
 * Proxies the weekly mood insight request to the Spring Boot backend's
 * Gemini-powered AI endpoint, while keeping local calculations for 
 * mood distributions and hour-by-hour circadian telemetry.
 */
export async function GET() {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    let entries: MoodEntry[] = [];
    let insight = "";

    try {
      const url = backendUrl();
      const response = await axios.get(`${url}/api/mood/history`, {
        params: { days: 30 },
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });
      entries = response.data || [];
    } catch (backendError) {
      console.error(
        "Spring Boot backend offline or failed on weekly insights telemetry fetch:",
        backendError
      );
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }

    try {
      const url = backendUrl();
      const response = await axios.get(`${url}/api/ai/insight/weekly`, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });
      insight = response.data.insight;
    } catch (backendError) {
      console.error("Spring Boot backend failed on weekly AI insight fetch:", backendError);
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }

    // 1. Process Mood Distribution this month (last 30 days)
    const moodCounts: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    entries.forEach(entry => {
      const score = Math.round(entry.moodScore);
      if (score >= 1 && score <= 5) {
        moodCounts[score]++;
      }
    });

    const totalLogs = entries.length;
    const moodDistribution = [
      { name: `Radiant ${getMoodEmoji(5)}`, value: totalLogs > 0 ? Math.round((moodCounts[5] / totalLogs) * 100) : 0, score: 5, color: "#00D2C8" },
      { name: `Stable ${getMoodEmoji(4)}`, value: totalLogs > 0 ? Math.round((moodCounts[4] / totalLogs) * 100) : 0, score: 4, color: "#10B981" },
      { name: `Neutral ${getMoodEmoji(3)}`, value: totalLogs > 0 ? Math.round((moodCounts[3] / totalLogs) * 100) : 0, score: 3, color: "#6B7280" },
      { name: `Low Energy ${getMoodEmoji(2)}`, value: totalLogs > 0 ? Math.round((moodCounts[2] / totalLogs) * 100) : 0, score: 2, color: "#F59E0B" },
      { name: `High Stress ${getMoodEmoji(1)}`, value: totalLogs > 0 ? Math.round((moodCounts[1] / totalLogs) * 100) : 0, score: 1, color: "#FF6B6B" },
    ].filter(item => item.value > 0);

    // 2. Process Time of Day (group entries by hour bucket)
    const buckets = [
      { hourLabel: "08:00 AM", minHour: 7, maxHour: 8, sum: 0, count: 0 },
      { hourLabel: "10:00 AM", minHour: 9, maxHour: 10, sum: 0, count: 0 },
      { hourLabel: "12:00 PM", minHour: 11, maxHour: 12, sum: 0, count: 0 },
      { hourLabel: "02:00 PM", minHour: 13, maxHour: 14, sum: 0, count: 0 },
      { hourLabel: "04:00 PM", minHour: 15, maxHour: 16, sum: 0, count: 0 },
      { hourLabel: "06:00 PM", minHour: 17, maxHour: 18, sum: 0, count: 0 },
      { hourLabel: "08:00 PM", minHour: 19, maxHour: 20, sum: 0, count: 0 },
      { hourLabel: "10:00 PM", minHour: 21, maxHour: 23, sum: 0, count: 0 },
    ];

    entries.forEach(entry => {
      const date = new Date(entry.timestamp);
      const hour = date.getHours();
      
      const bucket = buckets.find(b => hour >= b.minHour && hour <= b.maxHour);
      if (bucket) {
        bucket.sum += entry.moodScore;
        bucket.count++;
      }
    });

    const timeOfDay = buckets.map(b => {
      return {
        hourLabel: b.hourLabel,
        hour: b.minHour + 1,
        avgScore: b.count > 0 ? parseFloat((b.sum / b.count).toFixed(1)) : 3.5,
      };
    });

    return NextResponse.json({
      insight,
      moodDistribution,
      timeOfDay,
      totalEntries: entries.length,
    });
  } catch (error: unknown) {
    console.error("Error in GET /api/insights/weekly:", error);
    return NextResponse.json(
      { error: "Failed to assemble cognitive weekly telemetry." },
      { status: 500 }
    );
  }
}
