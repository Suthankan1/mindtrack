import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import { getMockEntries } from "@/lib/mockStore";
import axios from "axios";
import { isDemoToken, backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * GET /api/mood/history?days=N
 *
 * Server-side proxy that fetches a user's mood history from the Spring Boot
 * backend for the given number of days (defaults to 30). The user's JWT is
 * forwarded as a Bearer token for backend authentication.
 *
 * Serves rich synthetic mock data only if:
 * 1. The user is logged in with the demo account and demo mode is explicitly enabled.
 *
 * @param req - The incoming Next.js request; reads the `days` query parameter
 * @returns 200 with an array of MoodEntry objects on success,
 *          401 if the session is missing or expired,
 *          502 if backend is offline/failed,
 *          or 500 on unexpected errors.
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
    if (isDemoToken(session.user.accessToken)) {
      const mockData = getMockEntries(days);
      return NextResponse.json(mockData);
    }

    try {
      const url = backendUrl();
      const response = await axios.get(`${url}/api/mood/history`, {
        params: { days },
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      return NextResponse.json(response.data);
    } catch (backendError) {
      console.error(
        "Spring Boot backend offline or failed on mood history fetch:",
        backendError
      );
      return NextResponse.json(
        { error: "Bad Gateway: Spring Boot backend is offline or unavailable." },
        { status: 502 }
      );
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

