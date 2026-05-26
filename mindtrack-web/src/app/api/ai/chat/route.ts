import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import axios from "axios";
import { authOptions } from "@/lib/auth";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();

    try {
      const url = backendUrl();
      const response = await axios.post(`${url}/api/ai/chat`, body, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      return NextResponse.json(response.data);
    } catch (backendError) {
      console.error("Spring Boot backend offline or failed on chat fetch:", backendError);
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string };
    const errMsg = err.response?.data?.message || err.message || "Failed to send chat message";

    console.error("Error in POST /api/ai/chat proxy:", errMsg);
    return NextResponse.json({ error: errMsg }, { status: 500 });
  }
}