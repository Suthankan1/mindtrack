import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";

/**
 * GET /api/mood/history?days=N
 *
 * Server-side proxy that fetches a user's mood history from the Spring Boot
 * backend for the given number of days (defaults to 30). The user's JWT is
 * forwarded as a Bearer token for backend authentication.
 *
 * @param req - The incoming Next.js request; reads the `days` query parameter
 * @returns 200 with an array of MoodEntryResponse objects on success,
 *          401 if the session is missing or expired,
 *          or the upstream error status if the backend call fails
 */
export async function GET(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const days = searchParams.get("days") || "30";

    const response = await axios.get(`${process.env.BACKEND_URL}/api/mood/history`, {
      params: { days },
      headers: {
        Authorization: `Bearer ${session.user.accessToken}`,
      },
    });

    return NextResponse.json(response.data);
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string; responseStatus?: number };
    const errMsg = err.response?.data?.message || err.message || "Failed to fetch mood history";
    const errStatus = (err.response as { status?: number })?.status || 500;
    
    console.error("Error in GET /api/mood/history proxy:", errMsg);
    return NextResponse.json(
      { error: errMsg },
      { status: errStatus }
    );
  }
}
