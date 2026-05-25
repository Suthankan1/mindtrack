import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import { addMockEntry } from "@/lib/mockStore";
import axios from "axios";
import { isDemoToken, backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * POST /api/mood/log
 *
 * Server-side proxy that forwards a mood-logging request from the Next.js
 * client to the Spring Boot backend. Attaches the user's JWT (from the
 * NextAuth session) as a Bearer token so the backend can authenticate the call.
 *
 * Intercepts and logs in the local in-memory fallback database only if:
 * 1. The user is logged in with the demo account and demo mode is explicitly enabled.
 *
 * @param req - The incoming Next.js request containing the mood payload
 *              (moodScore: number, note?: string, tags?: string[])
 * @returns 201 with the saved mood entry on success,
 *          401 if the session is missing or expired,
 *          502 if backend is offline/failed,
 *          or 500 on unexpected errors.
 */
export async function POST(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json();

    // Handle developer demo session instantly without bothering the backend
    if (isDemoToken(session.user.accessToken)) {
      const mockSaved = addMockEntry(body.moodScore, body.note, body.tags);
      return NextResponse.json(mockSaved, { status: 201 });
    }

    try {
      const url = backendUrl();
      const response = await axios.post(`${url}/api/mood/log`, body, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
          "Content-Type": "application/json",
        },
      });

      return NextResponse.json(response.data, { status: 201 });
    } catch (backendError) {
      console.error(
        "Spring Boot backend offline or failed on mood commit:",
        backendError
      );
      return NextResponse.json(
        { error: "Bad Gateway: Spring Boot backend is offline or unavailable." },
        { status: 502 }
      );
    }
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string };
    const errMsg = err.response?.data?.message || err.message || "Failed to log mood";

    console.error("Error in POST /api/mood/log proxy:", errMsg);
    return NextResponse.json(
      { error: errMsg },
      { status: 500 }
    );
  }
}

