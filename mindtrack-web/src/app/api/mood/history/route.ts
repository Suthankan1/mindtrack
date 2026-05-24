import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import { getMockEntries } from "@/lib/mockStore";
import axios from "axios";

export const dynamic = "force-dynamic";

/**
 * GET /api/mood/history?days=N
 *
 * Server-side proxy that fetches a user's mood history from the Spring Boot
 * backend for the given number of days (defaults to 30). The user's JWT is
 * forwarded as a Bearer token for backend authentication.
 *
 * Bypasses the backend and serves rich synthetic mock data if:
 * 1. The user is logged in with the demo account ('demo-mock-jwt-token-data').
 * 2. The Spring Boot backend is offline or returns an authentication/server error.
 *
 * @param req - The incoming Next.js request; reads the `days` query parameter
 * @returns 200 with an array of MoodEntry objects on success,
 *          401 if the session is missing or expired,
 *          or 200 with fallback mock entries if backend is offline.
 */
export async function GET(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const daysStr = searchParams.get("days") || "30";
    const days = parseInt(daysStr, 10) || 30;

    // Handle developer demo session instantly without bothering the backend
    if (session.user.accessToken === "demo-mock-jwt-token-data") {
      const mockData = getMockEntries(days);
      return NextResponse.json(mockData);
    }

    try {
      const response = await axios.get(`${process.env.BACKEND_URL}/api/mood/history`, {
        params: { days },
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      return NextResponse.json(response.data);
    } catch (backendError) {
      console.warn(
        "Spring Boot backend offline or failed on mood history fetch. Serving rich synthetic data instead.",
        backendError
      );
      const mockFallback = getMockEntries(days);
      return NextResponse.json(mockFallback);
    }
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string };
    const errMsg = err.response?.data?.message || err.message || "Failed to fetch mood history";
    
    console.error("Error in GET /api/mood/history proxy:", errMsg);
    return NextResponse.json(
      { error: errMsg },
      { status: 500 }
    );
  }
}

