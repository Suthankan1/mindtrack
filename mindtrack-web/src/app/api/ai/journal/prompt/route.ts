import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * POST /api/ai/journal/prompt
 *
 * Proxies the personalized journal prompt request to the Spring Boot backend.
 */
export async function POST(request: Request) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const { moodScore, tags, recentNoteSummaries } = body;

    if (moodScore === undefined || moodScore < 1 || moodScore > 5) {
      return NextResponse.json(
        { error: "Invalid moodScore. Must be between 1 and 5." },
        { status: 400 }
      );
    }

    try {
      const url = backendUrl();
      const response = await axios.post(
        `${url}/api/ai/journal/prompt`,
        { moodScore, tags, recentNoteSummaries },
        {
          headers: {
            Authorization: `Bearer ${session.user.accessToken}`,
          },
        }
      );
      return NextResponse.json(response.data);
    } catch (backendError) {
      console.error("Spring Boot backend journal prompt generation failed:", backendError);
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    console.error("Error in POST /api/ai/journal/prompt:", error);
    return NextResponse.json(
      { error: "Failed to generate AI reflection prompt." },
      { status: 500 }
    );
  }
}
