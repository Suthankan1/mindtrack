import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    try {
      const url = backendUrl();
      const response = await axios.get(`${url}/api/user/wellness-passport`, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      return NextResponse.json(response.data);
    } catch (backendError) {
      console.error(
        "Spring Boot backend offline or failed on user wellness passport fetch:",
        backendError
      );
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string };
    const errMsg = err.response?.data?.message || err.message || "Failed to fetch user wellness passport";

    console.error("Error in GET /api/user/wellness-passport proxy:", errMsg);
    return NextResponse.json({ error: errMsg }, { status: 500 });
  }
}
