import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { isDemoToken, backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * GET /api/ai/anomaly/weekly
 *
 * Proxies the weekly mood anomaly request to the Spring Boot backend's
 * AI-powered anomaly engine, while supporting Demo Mode fallback.
 */
export async function GET() {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    if (isDemoToken(session.user.accessToken)) {
      // Elegant, high-fidelity mock anomaly data for demo presentation
      return NextResponse.json({
        riskLevel: "MEDIUM",
        detectedPatterns: [
          "Sudden mood drop from personal baseline",
          "3-day continuous downward trend",
          "Repeated low mood on Mondays"
        ],
        suggestedAction: "Demo Suggestion: Consider setting gentler calendar boundaries today and practicing box breathing.",
        supportiveInsight: "Demo Insight: We noticed a recent downward trend in your logs, possibly linked to high-stress levels or lack of restorative sleep. Taking brief mindful breaks can help restore your energetic baseline.",
        confidence: 0.85,
        insufficientData: false
      });
    }

    try {
      const url = backendUrl();
      const response = await axios.get(`${url}/api/ai/anomaly/weekly`, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });
      return NextResponse.json(response.data);
    } catch (backendError) {
      console.error("Spring Boot backend anomaly telemetry fetch failed:", backendError);
      return NextResponse.json(
        { error: "Bad Gateway: Spring Boot backend is offline or unavailable." },
        { status: 502 }
      );
    }
  } catch (error: unknown) {
    console.error("Error in GET /api/ai/anomaly/weekly:", error);
    return NextResponse.json(
      { error: "Failed to assemble cognitive weekly telemetry." },
      { status: 500 }
    );
  }
}
