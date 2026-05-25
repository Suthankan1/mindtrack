import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { id } = params;

    try {
      const url = backendUrl();
      const response = await axios.get(`${url}/api/ai/sentiment/${id}`, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      return NextResponse.json(response.data);
    } catch (backendError: unknown) {
      const err = backendError as { message?: string };
      console.error(
        `Spring Boot backend offline or failed on sentiment fetch for ${id}:`,
        err.message
      );
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    const err = error as { message?: string };
    console.error("Error in GET /api/ai/sentiment proxy:", err.message);
    return NextResponse.json(
      { error: "Failed to fetch sentiment analysis." },
      { status: 500 }
    );
  }
}
