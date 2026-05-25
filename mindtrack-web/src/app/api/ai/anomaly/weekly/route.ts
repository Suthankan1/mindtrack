import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * GET /api/ai/anomaly/weekly
 *
 * Proxies the weekly mood anomaly request to the Spring Boot backend's
 * AI-powered anomaly engine.
 */
export async function GET() {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
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
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
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
