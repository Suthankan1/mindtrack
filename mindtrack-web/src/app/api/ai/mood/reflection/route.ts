import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * POST /api/ai/mood/reflection
 *
 * Proxies the personalized mood reflection request to the Spring Boot backend.
 */
export async function POST(request: Request) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const { moodScore, tags, note, recentAverage } = body;

    if (moodScore === undefined || moodScore < 1 || moodScore > 5) {
      return NextResponse.json(
        { error: "Invalid moodScore. Must be between 1 and 5." },
        { status: 400 }
      );
    }

    try {
      const url = backendUrl();
      const response = await axios.post(
        `${url}/api/ai/mood/reflection`,
        { moodScore, tags, note, recentAverage },
        {
          headers: {
            Authorization: `Bearer ${session.user.accessToken}`,
          },
        }
      );
      return NextResponse.json(response.data);
    } catch (backendError) {
      console.error("Spring Boot backend mood reflection generation failed:", backendError);
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    console.error("Error in POST /api/ai/mood/reflection:", error);
    return NextResponse.json(
      { error: "Failed to generate AI reflection." },
      { status: 500 }
    );
  }
}
