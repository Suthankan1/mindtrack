import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import { getMockStats } from "@/lib/mockStore";
import axios from "axios";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    if (session.user.accessToken === "demo-mock-jwt-token-data") {
      return NextResponse.json(getMockStats());
    }

    try {
      const response = await axios.get(`${process.env.BACKEND_URL}/api/user/stats`, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      return NextResponse.json(response.data);
    } catch (backendError) {
      console.warn(
        "Spring Boot backend offline or failed on user stats fetch. Serving synthetic stats instead.",
        backendError
      );
      return NextResponse.json(getMockStats());
    }
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string };
    const errMsg = err.response?.data?.message || err.message || "Failed to fetch user stats";

    console.error("Error in GET /api/user/stats proxy:", errMsg);
    return NextResponse.json({ error: errMsg }, { status: 500 });
  }
}
