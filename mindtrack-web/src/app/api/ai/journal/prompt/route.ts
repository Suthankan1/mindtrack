import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { isDemoToken, backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * POST /api/ai/journal/prompt
 *
 * Proxies the personalized journal prompt request to the Spring Boot backend,
 * supporting high-fidelity Demo Mode prompt generations based on mood/tags.
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

    if (isDemoToken(session.user.accessToken)) {
      // Return beautiful, high-fidelity mock prompt responses mapped to the mood in Demo Mode
      let demoResponse = {
        promptTitle: "Checking In",
        promptQuestion: "How would you describe the transition of your energy today from morning until this very moment?",
        followUpQuestions: [
          "What felt stable or balanced today?",
          "Is there any subtle emotion waiting to be noticed?",
          "What is one word that sums up your current state?"
        ],
        estimatedMinutes: 5,
        tone: "Observant",
        aiAvailable: true
      };

      const selectedTagsText = tags && tags.length > 0 ? ` (${tags.join(", ")})` : "";

      switch (moodScore) {
        case 1:
          demoResponse = {
            promptTitle: "Calming the Storm",
            promptQuestion: `High stress detected${selectedTagsText}. What is currently demanding the most energy from you, and how can you take one step back to breathe?`,
            followUpQuestions: [
              "Where do you feel this tension in your body?",
              "What is one thing you can say 'no' to today to protect your peace?",
              "Who is someone you can lean on for a moment of support?"
            ],
            estimatedMinutes: 3,
            tone: "Grounding",
            aiAvailable: true
          };
          break;
        case 2:
          demoResponse = {
            promptTitle: "Gentle Refueling",
            promptQuestion: `Energy feels low${selectedTagsText}. What is the smallest, most comforting thing you can do to replenish yourself right now?`,
            followUpQuestions: [
              "How has your sleep or rest been over the last few days?",
              "What is a soft, comforting activity that usually restores you?",
              "How can you show yourself gentle kindness today?"
            ],
            estimatedMinutes: 3,
            tone: "Nurturing",
            aiAvailable: true
          };
          break;
        case 4:
          demoResponse = {
            promptTitle: "Anchoring the Good",
            promptQuestion: `Stable day logged${selectedTagsText}. What brought a sense of peace, accomplishment, or quiet joy to your day?`,
            followUpQuestions: [
              "How can you carry this pleasant baseline into tomorrow?",
              "What activity contributed most to this stable mood?",
              "What are you feeling appreciative of in this moment?"
            ],
            estimatedMinutes: 5,
            tone: "Warm",
            aiAvailable: true
          };
          break;
        case 5:
          demoResponse = {
            promptTitle: "Celebrating Clarity",
            promptQuestion: `Radiant energy felt${selectedTagsText}! What is flowing beautifully in your life right now that you want to celebrate?`,
            followUpQuestions: [
              "How can you anchor and remember this feeling of expansion?",
              "How can you share this vibrant energy with someone you care about?",
              "What aspirations or hopes feel closest to you today?"
            ],
            estimatedMinutes: 5,
            tone: "Vibrant",
            aiAvailable: true
          };
          break;
      }

      return NextResponse.json(demoResponse);
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
        { error: "Bad Gateway: Spring Boot backend is offline or unavailable." },
        { status: 502 }
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
